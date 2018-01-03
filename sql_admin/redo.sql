

-- Amount of Archiving per day
select trunc(completion_time) day_, 
        round(sum(blocks*block_size)/1024/1024/1024,2) arch_in_gb, 
		count(*) num#_logs, 
		round(sum(blocks*block_size)/1024/1024/count(*)) avg_log_size_mb
		--min(first_time), max(first_time)
from v$archived_log
--and completion_time >= to_date('2006-04-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
--and completion_time < to_date('2006-05-26 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
group by trunc(completion_time)
order by 1 DESC

-- Top Object block changes
select dhsso.obj#,
 dhsso.owner,
 dhsso.object_type,
 dhsso.object_name,
 sum(dhss.db_block_changes_delta) db_block_changes,
 round(ratio_to_report(sum(dhss.db_block_changes_delta)) over (),2) * 100 pct
 from dba_hist_seg_stat dhss,
 dba_hist_seg_stat_obj dhsso,
 dba_hist_snapshot dhs
 where dhs.snap_id = dhss.snap_id
 and dhs.instance_number = dhss.instance_number
 and dhss.obj# = dhsso.obj#
 and dhss.dataobj# = dhsso.dataobj#
 and begin_interval_time >= sysdate - 1/2
 group by dhsso.obj#,dhsso.owner,
 dhsso.object_type, dhsso.object_name
 order by db_block_changes desc
 
SELECT to_char(begin_interval_time,'YYYY_MM_DD HH24:MI') snap_time,
        dhsso.object_name,
        sum(db_block_changes_delta)
  FROM dba_hist_seg_stat dhss,
         dba_hist_seg_stat_obj dhsso,
         dba_hist_snapshot dhs
  WHERE dhs.snap_id = dhss.snap_id
    AND dhs.instance_number = dhss.instance_number
    AND dhss.obj# = dhsso.obj#
    AND dhss.dataobj# = dhsso.dataobj#
    AND begin_interval_time > sysdate - 4
    --BETWEEN to_date('2013_10_22 12','YYYY_MM_DD HH24')                                           AND to_date('2013_10_23 12','YYYY_MM_DD HH24')
  GROUP BY to_char(begin_interval_time,'YYYY_MM_DD HH24:MI'),
           dhsso.object_name 
           having  sum(db_block_changes_delta) > 10000
           order by 1 desc
		   
		   
-- Amount of redo log switches
SELECT
SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH:MI:SS'),1,5) DAY
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'00',1,0)) H00
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'01',1,0)) H01
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'02',1,0)) H02
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'03',1,0)) H03
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'04',1,0)) H04
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'05',1,0)) H05
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'06',1,0)) H06
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'07',1,0)) H07
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'08',1,0)) H08
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'09',1,0)) H09
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'10',1,0)) H10
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'11',1,0)) H11
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'12',1,0)) H12
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'13',1,0)) H13
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'14',1,0)) H14
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'15',1,0)) H15
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'16',1,0)) H16
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'17',1,0)) H17
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'18',1,0)) H18
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'19',1,0)) H19
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'20',1,0)) H20
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'21',1,0)) H21
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'22',1,0)) H22
, SUM(DECODE(SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH24:MI:SS'),10,2),'23',1,0)) H23
, COUNT(*) TOTAL
FROM
v$log_history a
GROUP BY SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH:MI:SS'),1,5)
ORDER BY SUBSTR(TO_CHAR(first_time, 'MM/DD/RR HH:MI:SS'),1,5)

-- Redo Log details
select l.thread#, l.group#, l.status, l.bytes, lf.member
from v$log l, v$logfile lf
where l.group# = lf.group#
order by 1,2
 

-- Resize logfiles in Data Guard env
-- Primary first for shrink, Standby first for increase
ALTER DATABASE ADD STANDBY LOGFILE thread 1 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 2 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 3 size 100M;

alter system switch logfile;
alter system archive log all;
alter system checkpoint;

select thread#,group#,bytes,status from v$standby_log;

alter database drop logfile group 1-10;
..
alter database drop logfile group 15-19;

ALTER DATABASE ADD STANDBY LOGFILE thread 1 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 1 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 1 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 1 size 100M;

ALTER DATABASE ADD STANDBY LOGFILE thread 2 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 2 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 2 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 2 size 100M;

ALTER DATABASE ADD STANDBY LOGFILE thread 3 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 3 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 3 size 100M;
ALTER DATABASE ADD STANDBY LOGFILE thread 3 size 100M;

-- Normal logs
ALTER DATABASE ADD LOGFILE thread 1 size 100M;
ALTER DATABASE ADD LOGFILE thread 2 size 100M;
ALTER DATABASE ADD LOGFILE thread 3 size 100M;
ALTER DATABASE ADD LOGFILE thread 1 size 100M;
ALTER DATABASE ADD LOGFILE thread 2 size 100M;
ALTER DATABASE ADD LOGFILE thread 3 size 100M;

alter system switch logfile;
alter system archive log all;
alter system checkpoint;

select thread#,group#,bytes,status from v$log order by 2;
alter database drop logfile group 11-14;
alter database drop logfile group 21-24;
alter database drop logfile group 31-34;

ALTER DATABASE ADD LOGFILE thread 1 size 100M;
ALTER DATABASE ADD LOGFILE thread 2 size 100M;
ALTER DATABASE ADD LOGFILE thread 3 size 100M;
ALTER DATABASE ADD LOGFILE thread 1 size 100M;
ALTER DATABASE ADD LOGFILE thread 2 size 100M;
ALTER DATABASE ADD LOGFILE thread 3 size 100M;

-- DR
edit database 'DB' set state=apply-off;
--check group names and redo above standby logs
alter system set standby_file_management=manual;
--check group names and redo above normal logs
alter system set standby_file_management=auto;
edit database 'DB' set state=apply-on;
