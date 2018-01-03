
REM
REM This script moves a schemas objects from a specified tablesapce 
REM into another tablespace(s)
REM It uses MOVE command for tables and REBUILD for indexes
REM
REM Specify the schema and table/index tablespace in the variables below
REM 
REM Known does not support - Nested tables
REM ALTER TABLE ,,, MOVE PARTITION "partition" NESTED TABLE name|COLUMN_VALUE STORE AS ( TABLESPACE "new-tablespace") .;
REM 


spool reorg_tablespace.log

set serveroutput on size 100000
set verify off
set linesize 120

DEFINE TS_FROM = USERS
DEFINE TS_TABS_TO = USERS
DEFINE TS_INDS_TO = USERS

PROMPT Invalid Objects
SELECT status, COUNT(*) as invalid_objects
FROM dba_objects
WHERE status <> 'VALID'
GROUP BY STATUS;

PROMPT Invalid Indexes
SELECT status, COUNT(*) as invalid_indexes
FROM dba_indexes
WHERE status NOT IN ('N/A','VALID')
GROUP BY STATUS;

DECLARE

  v_sql                              VARCHAR2(2000);
  
  CURSOR c_tab (cv_ts IN VARCHAR2) IS
	 SELECT owner, 
	        DECODE(iot_type, 'IOT_OVERFLOW', iot_name, table_name) table_name, 
	        DECODE(iot_type, 'IOT_OVERFLOW', 'OVERFLOW', NULL) iot_ovf
	 FROM dba_tables t
	 WHERE tablespace_name = UPPER(cv_ts)
	   AND partitioned = 'NO'
	   AND temporary = 'N'
	   AND secondary = 'N'
	   AND nested = 'NO'
	   AND NOT EXISTS (SELECT 1 
	                   FROM dba_tab_columns tc 
	                   WHERE t.owner = tc.owner
                         AND t.table_name = tc.table_name
                         AND tc.data_type = 'LONG');
	 
  CURSOR c_tab_part (cv_ts IN VARCHAR2) IS
	 SELECT table_owner owner, 
	        table_name,
	        partition_name
	 FROM dba_tab_partitions t
	 WHERE tablespace_name = UPPER(cv_ts)
	   AND subpartition_count = 0;

  CURSOR c_tab_subpart (cv_ts IN VARCHAR2) IS
	 SELECT table_owner owner, 
	        table_name,
	        subpartition_name partition_name
	 FROM dba_tab_subpartitions
	 WHERE tablespace_name = UPPER(cv_ts);

  CURSOR c_lob (cv_ts IN VARCHAR2) IS
	 SELECT owner, table_name, column_name
	 FROM dba_lobs l
	 WHERE tablespace_name = UPPER(cv_ts)
	   AND NOT EXISTS (SELECT 1 
	                   FROM dba_tab_columns tc 
	                   WHERE l.owner = tc.owner
                         AND l.table_name = tc.table_name
						 AND l.column_name = tc.column_name
                         AND tc.data_type = 'ANYDATA')
	   AND NOT EXISTS (SELECT 1 
	                   FROM dba_tab_columns tc 
	                   WHERE l.owner = tc.owner
                         AND l.table_name = tc.table_name
                         AND tc.data_type = 'LONG');


  CURSOR c_lob_part (cv_ts IN VARCHAR2) IS
	 SELECT l.owner, l.table_name, l.column_name, tp.partition_name
	 FROM dba_lobs l, dba_tab_partitions tp
	 WHERE l.owner = tp.table_owner
       AND l.table_name = tp.table_name
	   AND tp.tablespace_name = UPPER(cv_ts)
	   AND NOT EXISTS (SELECT 1 
	                   FROM dba_tab_columns tc 
	                   WHERE l.owner = tc.owner
                         AND l.table_name = tc.table_name
						 AND l.column_name = tc.column_name
                         AND tc.data_type = 'ANYDATA');
	 
  CURSOR c_lob_subpart (cv_ts IN VARCHAR2) IS
	 SELECT l.owner, l.table_name, l.column_name, tp.partition_name
	 FROM dba_lobs l, dba_tab_subpartitions tp
	 WHERE l.owner = tp.table_owner
       AND l.table_name = tp.table_name
	   AND tp.tablespace_name = UPPER(cv_ts)
	   AND NOT EXISTS (SELECT 1 
	                   FROM dba_tab_columns tc 
	                   WHERE l.owner = tc.owner
                         AND l.table_name = tc.table_name
						 AND l.column_name = tc.column_name
                         AND tc.data_type = 'ANYDATA');
	 
  CURSOR c_ind (cv_ts IN VARCHAR2) IS
	 SELECT owner, index_name
	 FROM dba_indexes
	 WHERE tablespace_name = UPPER(cv_ts)
	   AND index_type IN ('NORMAL', 'NORMAL/REV', 'BITMAP', 'FUNCTION-BASED NORMAL', 'FUNCTION-BASED BITMAP')
	   AND partitioned = 'NO';
	 
  -- Skip partitioned LOB index segments
  CURSOR c_ind_part (cv_ts IN VARCHAR2) IS
   SELECT index_owner owner,
          index_name,
          partition_name
   FROM dba_ind_partitions ip
   WHERE tablespace_name = UPPER(cv_ts)
     AND subpartition_count = 0
     AND NOT EXISTS (SELECT 1
                     FROM dba_lob_partitions lp
                     WHERE ip.partition_name = lp.lob_indpart_name
                       AND ip.index_owner = lp.table_owner);
	 
  CURSOR c_ind_subpart (cv_ts IN VARCHAR2) IS
   SELECT index_owner owner,
          index_name,
          subpartition_name partition_name
   FROM dba_ind_subpartitions ip
   WHERE tablespace_name = UPPER(cv_ts)
     AND NOT EXISTS (SELECT /*+ ALL_ROWS */ 1
                     FROM dba_lob_subpartitions lp
                     WHERE ip.subpartition_name = lp.lob_indsubpart_name
                       AND ip.index_owner = lp.table_owner);

BEGIN
	
	-- Do Normal Tables
	FOR i IN c_tab ('&TS_FROM')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE ' || i.iot_ovf || ' TABLESPACE &TS_TABS_TO';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

	-- Do Partitioned Tables
	FOR i IN c_tab_part ('&TS_FROM')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE PARTITION ' || i.partition_name || ' TABLESPACE &TS_TABS_TO';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	-- Do SubPartitioned Tables
	FOR i IN c_tab_subpart ('&TS_FROM')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE SUBPARTITION ' || i.partition_name || ' TABLESPACE &TS_TABS_TO';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

    -- Do LOBS
    FOR j IN c_lob ('&TS_FROM')
     LOOP
	
	 v_sql := 'ALTER TABLE ' || j.owner || '.' ||  j.table_name || ' MOVE LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_TABS_TO )';
   
	 BEGIN
	 	--dbms_output.put_line(v_sql);
		EXECUTE IMMEDIATE v_sql;

	 EXCEPTION
	  WHEN others THEN
	   dbms_output.put_line(j.table_name || ' ' || j.column_name);
	   dbms_output.put_line(SQLERRM);
	 END;

	END LOOP;

	-- Do LOB Partitions
	FOR j IN c_lob_part ('&TS_FROM')
	 LOOP
        
      v_sql := 'ALTER TABLE ' || j.owner || '.' ||  j.table_name || ' MOVE PARTITION ' ||  j.partition_name || ' LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_TABS_TO )';
	   
      BEGIN
	     
	   --dbms_output.put_line(v_sql);
	   EXECUTE IMMEDIATE v_sql;

	   EXCEPTION
	    WHEN others THEN
	      dbms_output.put_line(j.table_name || ' ' || j.column_name);
	      dbms_output.put_line(SQLERRM);
	   END;

	  END LOOP;
	   
	END LOOP;

	--Do LOB Subpartitions
    FOR j IN c_lob_subpart ('&TS_FROM')
	 LOOP
        
      v_sql := 'ALTER TABLE ' || j.owner || '.' ||  j.table_name || ' MOVE SUBPARTITION ' ||  j.partition_name || ' LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_TABS_TO )';
	   
      BEGIN
	     
       --dbms_output.put_line(v_sql);
       EXECUTE IMMEDIATE v_sql;

     EXCEPTION
      WHEN others THEN
        dbms_output.put_line(j.table_name || ' ' || j.column_name);
        dbms_output.put_line(SQLERRM);
     END;

    END LOOP;

	-- Do Indexes
	FOR i IN c_ind ('&TS_FROM')
	 LOOP
	   
	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD TABLESPACE &TS_INDS_TO NOLOGGING';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.index_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

	-- Do Index Partitions
	FOR i IN c_ind_part ('&TS_FROM')
	 LOOP
	   
	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD PARTITION ' || i.partition_name || ' TABLESPACE &TS_INDS_TO NOLOGGING';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.index_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

	-- Do Index SubPartitions
	FOR i IN c_ind_subpart ('&TS_FROM')
	 LOOP
	   
	   -- NOLOGGING does not work for Index subpartitions
	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD SUBPARTITION ' || i.partition_name || ' TABLESPACE &TS_INDS_TO';
	   
	   BEGIN
	     
	    -- dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.index_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

END;
/

SELECT owner, segment_type, tablespace_name, COUNT(*)
FROM dba_segments
WHERE tablespace_name = UPPER('&TS_FROM')
GROUP BY owner, segment_type, tablespace_name
ORDER BY owner, segment_type, tablespace_name;


PROMPT Invalid Objects
SELECT status, COUNT(*) as invalid_objects
FROM dba_objects
WHERE status <> 'VALID'
GROUP BY STATUS;

PROMPT Invalid Indexes
SELECT status, COUNT(*) as invalid_indexes
FROM dba_indexes
WHERE status NOT IN ('N/A','VALID')
GROUP BY STATUS;

spool off
