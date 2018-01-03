
select
    'oracle_sessions,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance where inst_id = s.inst_id) || ',' ||
    'metric_name=' ||
    decode(metric_name,
                'Average Active Sessions', 'active_sessions',
                'Session Count', 'sessions'
          ) || ' ' ||
    'metric_value='|| round(value,1) || ',' ||
    'cpu_count=' || (select value from v$parameter  where name='cpu_count') ||
    (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
    ',rac_metric_value='|| sum(round(value,1)) over(partition by metric_name) ||',' ||
    'rac_cpu_count=' || (select sum(value) from gv$parameter  where name='cpu_count')
     END)
from  gv$sysmetric s
where metric_name in (
                    'Average Active Sessions',
                    'Session Count')
and group_id=2;
