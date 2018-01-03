
select
    'oracle_calls,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance where inst_id = s.inst_id) || ',' ||
    'metric_name=' ||
    decode(metric_name, 
                'DB Block Changes Per Sec', 'block_changes_per_sec',
                'Recursive Calls Per Sec', 'recursive_calls_per_sec',
                'User Calls Per Sec', 'user_calls_per_sec',
                'User Commits Per Sec', 'user_commits_per_sec'  
          ) || ' ' ||
    'metric_value='|| round(value,1) ||
    (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
    ',rac_metric_value='|| sum(round(value,1)) over(partition by metric_name) END)
from  gv$sysmetric s
where metric_name in (
                    'DB Block Changes Per Sec',
                    'Recursive Calls Per Sec',
                    'User Calls Per Sec',
                    'User Commits Per Sec')
and group_id=2;
