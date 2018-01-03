
-- SQL Monitor Long running
select DBMS_SQLTUNE.REPORT_SQL_MONITOR('gbggwcznvbrd4',sql_exec_id => 33554433, type=>'TEXT') from dual

-- OEM Style HTML report
set pagesize 0 echo off timing off linesize 1000 trimspool on trim on long 2000000 longchunksize 2000000 feedback off
spool longo.html
select dbms_sqltune.report_sql_monitor('gbggwcznvbrd4',sql_exec_id => 33554433, type=>'EM') monitor_report from dual;
spool off

-- what's running
select sp.*
from gv$SQL_MONITOR s, gv$SQL_PLAN_MONITOR sp 
where s.inst_id = sp.inst_id 
and s.key = sp.key 
and s.sql_id = 'gbggwcznvbrd4'
and s.status = 'EXECUTING'
order by sp.sql_exec_start desc



