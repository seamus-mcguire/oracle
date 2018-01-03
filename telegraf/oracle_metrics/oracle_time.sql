
select
    'oracle_time,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance where inst_id = s.inst_id) || ',' ||
    'metric_name=' ||
    decode(metric_name, 
                'Database Time Per Sec', 'db_time_per_sec',
                'SQL Service Response Time', 'sql_response_time'
          ) || ' ' ||
    'metric_value='|| round(10*value,1) || 
    (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
    ',rac_metric_value='|| sum(round(10*value,1)) over(partition by metric_name) END)
from  gv$sysmetric s
where metric_name in (
                    'Database Time Per Sec',
                    'SQL Service Response Time')
and group_id=2;

