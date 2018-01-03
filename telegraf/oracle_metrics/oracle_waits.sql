
select
    'oracle_waits,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance where inst_id = m.inst_id) || ',' ||
    'wait_class='|| replace(n.wait_class,' ','_') || ',' ||
    'wait_event='|| replace(n.name,' ','_') || ' ' ||
    'count='|| m.wait_count || ',' ||
    'latency='|| round(10*m.time_waited/nullif(m.wait_count,0),3) ||  
    (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
     ',rac_count='|| sum(m.wait_count) over(partition by n.name) || ',' ||
     'rac_latency='|| sum(round(10*m.time_waited/nullif(m.wait_count,0),3)) over(partition by n.name)  
     END)
from gv$eventmetric m,
     v$event_name n
where m.event_id=n.event_id
  and n.wait_class <> 'Idle' 
  and m.wait_count > 0;
