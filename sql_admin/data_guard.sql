
-- DGMGRL
show configuration verbose;
show database verbose 'primary_db_sid';
show database verbose 'standby_db_sid';
show database 'db_name' statusreport

EDIT DATABASE 'DB_NAME' SET STATE=TRANSPORT-OFF;
EDIT DATABASE 'DB_NAME' SET STATE=APPLY-OFF;

EDIT DATABASE 'DB_NAME' SET STATE=APPLY-ON with apply instance='DB_NAME1';

EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

show instance 'INSTANCE' StaticConnectIdentifier;
edit instance 'INSTANCE' set property StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=hostname)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=DB_NAME_DGMGRL)(INSTANCE_NAME=INSTANCE)(SERVER=DEDICATED)))';


ALTER SYSTEM SET DG_BROKER_START=False scope=both;

ALTER DATABASE RECOVER MANAGED STANDBY DATABASE disconnect;
RECOVER MANAGED STANDBY DATABASE CANCEL; 


-- DataGuard messages - different results on Primary/Standby
select * from v$dataguard_status order by timestamp desc;

select message, timestamp
 from v$dataguard_status
 where severity in ('Error','Fatal')
 and timestamp>trunc(sysdate-1)
 order by timestamp desc;

-- Have archive logs applied 
select  thread#, sequence#, standby_dest, registrar, applied, deleted, first_time, next_time
from v$archived_log
where standby_dest = 'YES'
and applied = 'NO'
order by next_time desc

-- Primary
SELECT inst_id, sequence#, group#, thread#, status 
from gv$log
order by 3,4,1,2
-- Compare to Standby
SELECT group#, sequence#, status from v$standby_log;

-- Check DataGuard Latency; 
with rs as (SELECT MAX(RESETLOGS_CHANGE#) rscn FROM V$ARCHIVED_LOG)
select arch_thread as thread, arch_seq, shipped_seq, applied_seq, 
       (arch_seq-applied_seq) applied_gap, 
       round((arch_time-applied_time)*24,2) applied_latency_hours, 
       (arch_seq-shipped_seq) ship_gap,
       (arch_time-shipped_time)*86400 ship_latency_seconds,
       (arch_time-applied_time)*86400 applied_latency_seconds, 
       round((arch_time-shipped_time)*24,2) ship_latency_hours,
       arch_time, shipped_time, applied_time
from (SELECT thread# arch_thread, max(next_time) arch_time, MAX(sequence#) arch_seq 
      FROM v$archived_log l, rs
         WHERE 1=1
         and RESETLOGS_CHANGE# = rs.rscn
             group by thread#) arch,
 (SELECT thread# shipped_thread, max(next_time) shipped_time, MAX(sequence#) shipped_seq 
      FROM v$archived_log l, rs
         WHERE 1=1
          and RESETLOGS_CHANGE# = rs.rscn
             and standby_dest = 'YES'
             group by thread#) shipped,
 (SELECT thread# applied_thread, max(next_time) applied_time, MAX(sequence#) applied_seq 
      FROM v$archived_log l, rs
         WHERE 1=1
          and RESETLOGS_CHANGE# = rs.rscn
            and standby_dest = 'YES'
            AND applied = 'YES'
             group by thread#) app
where arch.arch_thread = app.applied_thread 
  and arch.arch_thread = shipped.shipped_thread 
order by arch_thread 

-- Check Latency 2
-- 0 means none, no records returned means Data Guard never configured
-- latency based on last log switch time for oldest thread so not real time
WITH 
dgu AS (
        SELECT COUNT(*) AS cnt
        FROM v$dataguard_config
	   ),
al as (
select (arch.nt-app.nt) *86400 as latency
     from 
        (select max(next_time) nt from v$archived_log) arch,
        (SELECT 
               min(first_time) as nt
        FROM v$archived_log l1
        WHERE applied = 'NO' 
          AND next_time > (SELECT min(startup_time) FROM gv$instance) 
          AND sequence# NOT IN (SELECT sequence# FROM v$archived_log l2 WHERE l1.thread#=l2.thread# and l2.applied = 'YES' )
          and RESETLOGS_CHANGE# = (SELECT MAX(RESETLOGS_CHANGE#)FROM V$ARCHIVED_LOG)
		  and standby_dest = 'YES') app
	  ) 
SELECT    
       (CASE 
	         WHEN dgu.cnt > 0 THEN al.latency  
			 ELSE NULL 
		END) AS latency_seconds
FROM al,dgu

-- does not consider threads so can be out but is indicative
select ((select max(next_time) from v$archived_log) - 
             (select max(next_time) from v$archived_log where applied='YES' and standby_dest = 'YES')
         ) *86400 as approx_latency
from dual
     
-- Ok if 'TO STANDBY'
select switchover_status from v$database
 
--
---  ON the Standby
--

-- Find any gap in applied logs
select distinct thread#, low_sequence#, high_sequence#
from v$archive_gap  -- RAC GV$ not needed
order by thread#, low_sequence#, high_sequence#;

-- Check log names from above results on Primary
SELECT name
FROM gv$archived_log
WHERE thread# = 1
  --AND dest_id = 1
  AND sequence# BETWEEN 1697 and 1999;


-- Standby latest applied logs
select 'Thread '||thread#||': Last Applied='||max(sequence#)||' (resetlogs_change#='||resetlogs_change#||')' 
from v$archived_log
where applied = (select decode(database_role, 'PRIMARY', 'NO', 'YES') 
                 from v$database) 
  and thread# in (select thread# from gv$instance) 
  and resetlogs_change# = (select resetlogs_change# from v$database) 
group by thread#, resetlogs_change# 
order by thread#;

-- Standby only - slow but shows logs not applied yet
 SELECT ARCH.THREAD# "Thread", ARCH.SEQUENCE# "Last Sequence Received", APPL.SEQUENCE# "Last Sequence Applied", (ARCH.SEQUENCE# - APPL.SEQUENCE#) "Difference"
  FROM (SELECT THREAD# ,SEQUENCE#
  FROM V$ARCHIVED_LOG
  WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME)
  FROM V$ARCHIVED_LOG
  GROUP BY THREAD#)) ARCH,
  (SELECT THREAD# ,SEQUENCE#
  FROM V$LOG_HISTORY
  WHERE (THREAD#,FIRST_TIME ) IN (SELECT THREAD#,MAX(FIRST_TIME)
  FROM V$LOG_HISTORY
  GROUP BY THREAD#)) APPL
  WHERE ARCH.THREAD# = APPL.THREAD#
  ORDER BY 1;

SELECT PROCESS, STATUS, thread#, SEQUENCE#, block#, blocks, DELAY_MINS FROM gV$MANAGED_STANDBY;

col name format a30
col value format a30
select name, value from gv$dataguard_stats order by name;


