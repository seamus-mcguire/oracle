
select
    'rods_sql_avg,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from v$instance) || ',' ||
    'sql='||
      decode(q.sql_id,
               '8scsjwshd7muz','INSERT',
               'c8sspybst0zwz', 'DELETE',
               'fuutvgbtd6a2p', 'UPDATE',
               'chcujfygs71wd', 'SELECT',
               'f60thu1ay0zac', 'LOB_SPACE'
               ) || ' ' ||
    'executions='|| sum(q.EXECUTIONS_DELTA) || ',' ||
    'msec_per_exec='|| round((sum(ELAPSED_TIME_delta)/greatest(sum(executions_delta),1)/1000),1)
    || ' ' || (MIN(cast(s.end_interval_time at time zone 'UTC' as date))- to_date('1-1-1970 00:00:00','MM-DD-YYYY HH24:Mi:SS'))*86400*1000000000
from dba_hist_sqlstat q, dba_hist_snapshot s
where q.instance_number = (select instance_number from v$instance)
and q.SQL_ID IN ('8scsjwshd7muz','c8sspybst0zwz','fuutvgbtd6a2p','chcujfygs71wd','f60thu1ay0zac')
and s.snap_id = q.snap_id
and s.dbid = q.dbid
and s.instance_number = q.instance_number
and s.end_interval_time > sysdate-1/24
group by s.snap_id, q.sql_id, q.plan_hash_value;

