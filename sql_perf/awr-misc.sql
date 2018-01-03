
-- Some Metrics
select metric_name , instance_number, end_time, value 
from DBA_HIST_SYSMETRIC_HISTORY
where metric_name like 'Average Active Sessions'
and end_time > sysdate -1
order by 3 desc, 2


-- Event Histogram 1
select 
   eh.instance_number
   , CAST(begin_interval_time AS DATE) snap_begin
  , TO_CHAR(CAST(end_interval_time AS DATE), 'HH24:MI') snap_end
  , event_name
  , wait_time_milli 
  , CASE WHEN wait_count >= LAG(wait_count) OVER (PARTITION BY event_name,wait_time_milli ORDER BY CAST(begin_interval_time AS DATE)) THEN
        wait_count - LAG(wait_count) OVER (PARTITION BY event_name,wait_time_milli ORDER BY CAST(begin_interval_time AS DATE)) 
    ELSE
        wait_count
    END wait_count
from dba_hist_event_histogram eh,
     dba_hist_snapshot s
where eh.snap_id = s.snap_id
and eh.instance_number = s.instance_number 
and event_name = 'log file sync'
and s.begin_interval_time > sysdate-1
and wait_time_milli = 32768
order by event_name
  , snap_begin
  , wait_time_milli
  
-- Event Histogram 2
select * 
from (
SELECT
    CAST(begin_interval_time AS DATE) snap_begin
  , TO_CHAR(CAST(end_interval_time AS DATE), 'HH24:MI') snap_end
  , instance_number
  , event_name
  , wait_time_milli 
  , CASE WHEN wait_count >= LAG(wait_count) OVER (PARTITION BY instance_number, event_name,wait_time_milli ORDER BY CAST(begin_interval_time AS DATE)) 
         THEN wait_count - LAG(wait_count) OVER (PARTITION BY instance_number, event_name,wait_time_milli ORDER BY CAST(begin_interval_time AS DATE)) 
    ELSE
        wait_count
    END wait_count
FROM
    dba_hist_snapshot
  NATURAL JOIN
    dba_hist_event_histogram
WHERE 1=1
    -- and begin_interval_time > SYSDATE - 3
	--and s.begin_interval_time between to_timestamp('2017-01-19 00:00:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2017-01-19 01:00:00', 'YYYY-MM-DD HH24:MI:SS')
    --and wait_time_milli > 4096
 AND event_name LIKE 'log file sync'
)
where wait_count > 0 
ORDER BY
  snap_begin desc,
  instance_number,
  wait_time_milli desc
  

-- Active SQL History
select sn.instance_number, sn.BEGIN_INTERVAL_TIME, sq.VERSION_COUNT, sq.plan_hash_value, END_OF_FETCH_COUNT_TOTAL, sq.executions_total, END_OF_FETCH_COUNT_delta, sq.executions_delta, sq.ELAPSED_TIME_TOTAL , sq.ELAPSED_TIME_DELTA, sq.APWAIT_TOTAL, sq.apwait_delta
from DBA_HIST_SQLSTAT sq, DBA_HIST_SNAPSHOT sn
where sq.snap_id = sn.snap_id 
and sq.instance_number = sn.instance_number  
and sql_id = 'sql_id'
order by sn.BEGIN_INTERVAL_TIME desc

-- CPU
Select *
From SYS.WRH$_SYSSTAT s, sys.WRH$_STAT_NAME sn
where s.STAT_ID = sn.STAT_ID
and stat_name =  'CPU used by this session'
and instance_number = 2

-- OS Stats
Select s.snap_id, to_char(ss.END_INTERVAL_TIME, 'yyyy-mm-dd hh24:mi:ss'), stat_name, value
From SYS.WRH$_OSSTAT s, SYS.WRH$_OSSTAT_NAME n, SYS.WRM$_SNAPSHOT ss
where s.STAT_ID = n.STAT_ID
and s.SNAP_ID = ss.SNAP_ID
order by ss.END_INTERVAL_TIME

