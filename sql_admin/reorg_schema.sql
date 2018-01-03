
REM
REM This script moves a schemas objects into another tablespace(s)
REM It uses MOVE command for tables and REBUILD for indexes
REM
REM Will move all tables and indexes regardless of whether they exist
REM in the target tablespace(s) already
REM
REM Specify the schema and table/lob/index tablespace in the variables below
REM 
REM Known does not support - Nested tables, tables with LONG datatype
REM 


spool reorg_schema.log

set serveroutput on size 100000
set verify off
set linesize 120

DEFINE SCHEMA = SCHEMA_NAME
DEFINE TS_TABS = SCHEMA_NAME_DATA 
DEFINE TS_LOBS = SCHEMA_NAME_DATA 
DEFINE TS_INDS = SCHEMA_NAME_DATA 

DECLARE

  v_sql                              VARCHAR2(2000);
  
  CURSOR c_tab (cv_schema IN VARCHAR2) IS
	 SELECT owner, 
	        DECODE(iot_type, 'IOT_OVERFLOW', iot_name, table_name) table_name, 
	        DECODE(iot_type, 'IOT_OVERFLOW', 'OVERFLOW', NULL) iot_ovf
	 FROM dba_tables
	 WHERE owner = UPPER(cv_schema)
	   AND partitioned = 'NO'
	   AND temporary = 'N'
	   AND secondary = 'N'
	   AND nested = 'NO';

  CURSOR c_lob (cv_schema IN VARCHAR2, cv_tab IN VARCHAR2) IS
	 SELECT owner, column_name
	 FROM dba_lobs
	 WHERE owner = UPPER(cv_schema)
	   AND table_name = UPPER(cv_tab);

  CURSOR c_tab_part (cv_schema IN VARCHAR2) IS
	 SELECT table_owner owner, 
	        table_name,
	        partition_name
	 FROM dba_tab_partitions
	 WHERE table_owner = UPPER(cv_schema)
	   AND subpartition_count = 0;

  CURSOR c_tab_subpart (cv_schema IN VARCHAR2) IS
	 SELECT table_owner owner, 
	        table_name,
	        subpartition_name partition_name
	 FROM dba_tab_subpartitions
	 WHERE table_owner = UPPER(cv_schema);

  CURSOR c_ind (cv_schema IN VARCHAR2) IS
	 SELECT owner, index_name
	 FROM dba_indexes
	 WHERE owner = UPPER(cv_schema)
	   AND index_type IN ('NORMAL', 'NORMAL/REV', 'BITMAP', 'FUNCTION-BASED NORMAL', 'FUNCTION-BASED BITMAP')
	   AND partitioned = 'NO';
	 
  -- Skip partitioned LOB index segments
  CURSOR c_ind_part (cv_schema IN VARCHAR2) IS
   SELECT index_owner owner,
          index_name,
          partition_name
   FROM dba_ind_partitions ip
   WHERE index_owner = UPPER(cv_schema)
     AND subpartition_count = 0
     AND NOT EXISTS (SELECT 1
                     FROM dba_lob_partitions lp
                     WHERE ip.partition_name = lp.lob_indpart_name
                       AND ip.index_owner = lp.table_owner);
	 
  CURSOR c_ind_subpart (cv_schema IN VARCHAR2) IS
   SELECT index_owner owner,
          index_name,
          subpartition_name partition_name
   FROM dba_ind_subpartitions ip
   WHERE index_owner = UPPER(cv_schema)
     AND NOT EXISTS (SELECT /*+ ALL_ROWS */ 1
                     FROM dba_lob_subpartitions lp
                     WHERE ip.subpartition_name = lp.lob_indsubpart_name
                       AND ip.index_owner = lp.table_owner);

BEGIN
	
	-- Do Normal Tables
	FOR i IN c_tab ('&SCHEMA')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE ' || i.iot_ovf || ' TABLESPACE &TS_TABS';
	   
	   BEGIN
	     
	     dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	   -- Move any LOBS
	   FOR j IN c_lob (i.owner, i.table_name)
	    LOOP
        
        v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_LOBS )';
	   
        BEGIN
	     
	        dbms_output.put_line(v_sql);
	        EXECUTE IMMEDIATE v_sql;

	      EXCEPTION
	       WHEN others THEN
	         dbms_output.put_line(i.table_name || ' ' || j.column_name);
	         dbms_output.put_line(SQLERRM);
	      END;

	    END LOOP;
	   
	 END LOOP;

	-- Do Partitioned Tables
	FOR i IN c_tab_part ('&SCHEMA')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE PARTITION ' || i.partition_name || ' TABLESPACE &TS_TABS';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	   -- Move any LOBS
	   FOR j IN c_lob (i.owner, i.table_name)
	    LOOP
        
        v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE PARTITION ' ||  i.partition_name || ' LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_LOBS )';
	   
        BEGIN
	     
	        --dbms_output.put_line(v_sql);
	        EXECUTE IMMEDIATE v_sql;

	      EXCEPTION
	       WHEN others THEN
	         dbms_output.put_line(i.table_name || ' ' || j.column_name);
	         dbms_output.put_line(SQLERRM);
	      END;

	    END LOOP;
	   
	 END LOOP;

	-- Do SubPartitioned Tables
	FOR i IN c_tab_subpart ('&SCHEMA')
	 LOOP
	   
	   v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE SUBPARTITION ' || i.partition_name || ' TABLESPACE &TS_TABS';
	   
	   BEGIN
	     
	     --dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.table_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	   -- Move any LOBS
	   FOR j IN c_lob (i.owner, i.table_name)
	    LOOP
        
        v_sql := 'ALTER TABLE ' || i.owner || '.' ||  i.table_name || ' MOVE SUBPARTITION ' ||  i.partition_name || ' LOB (' || j.column_name || ') STORE AS (TABLESPACE &TS_LOBS )';
	   
        BEGIN
	     
	        --dbms_output.put_line(v_sql);
	        EXECUTE IMMEDIATE v_sql;

	      EXCEPTION
	       WHEN others THEN
	         dbms_output.put_line(i.table_name || ' ' || j.column_name);
	         dbms_output.put_line(SQLERRM);
	      END;

	    END LOOP;
	   
	 END LOOP;

	-- Do Indexes
	FOR i IN c_ind ('&SCHEMA')
	 LOOP
	   
	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD TABLESPACE &TS_INDS ONLINE';
	   
	   BEGIN
	     
	     dbms_output.put_line(v_sql);
	     EXECUTE IMMEDIATE v_sql;
	   
	   EXCEPTION
	     WHEN others THEN
	       dbms_output.put_line(i.index_name);
	       dbms_output.put_line(SQLERRM);
	   END;
	   
	 END LOOP;

	-- Do Index Partitions
	FOR i IN c_ind_part ('&SCHEMA')
	 LOOP
	   
	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD PARTITION ' || i.partition_name || ' TABLESPACE &TS_INDS ONLINE';
	   
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
	FOR i IN c_ind_subpart ('&SCHEMA')
	 LOOP
	   
	   	   v_sql := 'ALTER INDEX ' || i.owner || '.' ||  i.index_name || ' REBUILD SUBPARTITION ' || i.partition_name || ' TABLESPACE &TS_INDS ONLINE';
	   
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
WHERE owner = UPPER('&SCHEMA')
GROUP BY owner, segment_type, tablespace_name
ORDER BY owner, segment_type, tablespace_name;

PROMPT Recompiling Schema
EXEC dbms_utility.compile_schema('&SCHEMA');

PROMPT Invalid Objects
SELECT status, COUNT(*) as invalid_objects
FROM dba_objects
WHERE owner = UPPER('&SCHEMA')
  AND status <> 'VALID'
GROUP BY STATUS;

PROMPT Invalid Indexes
SELECT status, COUNT(*) as invalid_indexes
FROM dba_indexes
WHERE owner = UPPER('&SCHEMA')
  AND status NOT IN ('N/A','VALID')
GROUP BY STATUS;
  

spool off
