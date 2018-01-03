

/********************************************************
  Tracing 
 ********************************************************/
select trace_type, primary_id, QUALIFIER_ID1, waits, binds from DBA_ENABLED_TRACES;
 
10046 EVENT levels:         
1  - Enable standard SQL_TRACE functionality (Default)
4  - As Level 1 PLUS trace bind values
8  - As Level 1 PLUS trace waits This is especially useful for spotting latch wait etc. but can also be used to spot full table scans and index scans.
12 - As Level 1 PLUS both trace bind values and waits

-- Whole DB - only does new sessions
-- Default
alter system set events '10046 trace name context forever';   
-- Set to a higher level
alter system set events '10046 trace name context forever, level 4';  
-- Stop tracing
alter system set events '10046 trace name context off'; 

-- SQL ID
ALTER SYSTEM SET EVENTS 'sql_trace [sql:&&sql_id] bind=true, wait=true';
ALTER SYSTEM SET EVENTS 'sql_trace [sql:&&sql_id] off';

-- Session Only
The first argument is SID 
Second argument is SERIAL# 
Third argument is EVENT 
Fourth argument is LEVEL, level 
Fifth leave null

SELECT sid, serial#
from gv$session
where sid IN (404,260)

-- Start
begin 
  dbms_system.set_ev(99, 99999, 10046, 12, ''); 
end; 
/ 

-- Stop
begin 
  dbms_system.set_ev(99, 99999, 10046, 0, ''); 
end; 
/ 

/************************************************************
  DBMS_MONITOR
 ************************************************************/
begin

for i in (select sid, serial#
          from gv$session
          where 1=1  
          --sql_id = 'sql_id'
          and username = 'USER'
          and inst_id = 1)
loop
 
 DBMS_MONITOR.SESSION_TRACE_ENABLE(i.sid,i.serial#,waits=>true,binds=>true);
 --DBMS_MONITOR.SESSION_TRACE_DISABLE(i.sid,i.serial#);
end loop;

end;
/ 

/********************************************************
  Trace your own session 
 ********************************************************/
ALTER SESSION SET TRACEFILE_IDENTIFIER = "trace_dbms_space";
ALTER SESSION SET EVENTS '10046 trace name context forever, level 12';

ALTER SESSION SET EVENTS '10046 trace name context off';

/********************************************************
  TKPROF/TRCSESS
 ********************************************************/

tkprof p003.trc output=tk.prof waits=yes sort=exeela
 	
trcsess output=agg.trc service='RODS1.systems.uk.hsbc' *.trc

/************************************************************
  System State Dump
 ************************************************************/
 
ALTER SESSION SET MAX_DUMP_FILE_SIZE=UNLIMITED;

ALTER SESSION SET EVENTS 'IMMEDIATE TRACE NAME SYSTEMSTATE LEVEL 10';
wait 2 mins
ALTER SESSION SET EVENTS 'IMMEDIATE TRACE NAME SYSTEMSTATE LEVEL 10';
wait 2 mins
ALTER SESSION SET EVENTS 'IMMEDIATE TRACE NAME SYSTEMSTATE LEVEL 10';
exit


/********************************************************
  Underlying View Objects
 ********************************************************/
alter session set "_dump_qbc_tree"=1;


/********************************************************
  Access to trace files
 ********************************************************/

CREATE DIRECTORY user_dump_dest AS
  '/app/oracle/admin/DB01/udump';

CREATE OR REPLACE FUNCTION get_tracefile (file_name VARCHAR2)
   RETURN VARCHAR2
IS
   dest_loc   CLOB;
   src_loc    BFILE;
   ret        VARCHAR2 (4000);
BEGIN
   src_loc := BFILENAME ('USER_DUMP_DEST', file_name);
   DBMS_LOB.OPEN (src_loc, DBMS_LOB.lob_readonly);
   DBMS_LOB.createtemporary (dest_loc, TRUE);
   DBMS_LOB.loadfromfile (dest_loc, src_loc, 4000);
   ret := DBMS_LOB.SUBSTR (dest_loc, 4000);
   DBMS_LOB.CLOSE (src_loc);
   RETURN ret;
END;
/
