
select
    'rods_sql_duration,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from v$instance) || ',' ||
    'sql='||
      decode(sql_id,
               '8scsjwshd7muz','INSERT',
               'c8sspybst0zwz', 'DELETE',
               'fuutvgbtd6a2p', 'UPDATE',
               'chcujfygs71wd', 'SELECT',
               'f60thu1ay0zac', 'LOB_SPACE'
               ) || ',' ||
    'sql_plan_hash_value='|| sql_plan_hash_value || ',' ||
    'sql_child_number='|| sql_child_number || ',' ||
    'sql_exec_id='|| sql_exec_id || ' ' ||
    'duration='|| duration_seconds || ' ' ||
    ((start_time)- to_date('1-1-1970 00:00:00','MM-DD-YYYY HH24:Mi:SS'))*86400*1000000000 as epoch
from (
   select
        min(start_time) start_time
        ,max(end_time) end_time,
        max(delta) duration_seconds,
        instance_number,
        sql_id,
  sql_plan_hash_value,
  sql_child_number,
        sql_exec_id
   from ( select
                instance_number,
                sql_id,
    sql_plan_hash_value,
    sql_child_number,
    sql_exec_id,
              cast(sample_time at time zone 'UTC' as date)     end_time,
             cast(cast(sql_exec_start as TIMESTAMP WITH LOCAL TIME ZONE)at time zone 'UTC' as date) start_time, 
              ((cast(sample_time    as date)) -
               (cast(sql_exec_start as date))) * (3600*24) delta
           from
              dba_hist_active_sess_history
           where 1=1
       and sql_exec_id is not null
       and instance_number = (select instance_number from v$instance)
       and SQL_ID IN ('8scsjwshd7muz','c8sspybst0zwz','fuutvgbtd6a2p','chcujfygs71wd','f60thu1ay0zac')
      and sample_time >= trunc(sysdate-2/24, 'HH24')
      and sample_time < trunc(sysdate-1/24,  'HH24')
        )
   group by instance_number, sql_id,sql_exec_id,sql_plan_hash_value,sql_child_number,start_time
)
where duration_seconds > 1;


