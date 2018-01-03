

-- Historic resource limits such as processes/RBS/parallel_max_servers
select 
       s.end_interval_time,
       i.instance_name,
       rl.resource_name,
       current_utilization,
       limit_value max_limit
from DBA_HIST_RESOURCE_LIMIT rl, 
    dba_hist_snapshot s,
    DBA_HIST_DATABASE_INSTANCE i
where rl.snap_id = s.snap_id 
and rl.instance_number = s.instance_number
and rl.instance_number = i.instance_number
and s.startup_time = i.startup_time
and rl.resource_name = 'processes'
order by s.end_interval_time desc 

