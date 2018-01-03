
-- Executions of a SQL
select 
  to_char(min(s.end_interval_time),'DD-MON-YYYY DY HH24:MI') sample_end
,  s.instance_number 
, q.sql_id
, q.plan_hash_value
, sum(q.EXECUTIONS_DELTA) executions
, round(sum(DISK_READS_delta)/greatest(sum(executions_delta),1),1) pio_per_exec
, round(sum(BUFFER_GETS_delta)/greatest(sum(executions_delta),1),1) lio_per_exec
, round(sum(rows_processed_delta)/greatest(sum(executions_delta),1),1) rows_per_exec
, round((sum(ELAPSED_TIME_delta)/greatest(sum(executions_delta),1)/1000),1) msec_per_exec
, round((sum(ELAPSED_TIME_delta)/greatest(sum(executions_delta),1)/1000000),1) sec_per_exec
from dba_hist_sqlstat q, dba_hist_snapshot s
where q.sql_id='sql_id'
and s.snap_id = q.snap_id
and s.dbid = q.dbid
and s.instance_number = q.instance_number
--and s.end_interval_time >= to_date(trim('start_time.'),'dd-mon-yyyy hh24:mi')
--and s.begin_interval_time <= to_date(trim('end_time.'),'dd-mon-yyyy hh24:mi')
group by s.snap_id
, s.instance_number 
, q.sql_id
, q.plan_hash_value
order by s.snap_id desc, q.sql_id, q.plan_hash_value
