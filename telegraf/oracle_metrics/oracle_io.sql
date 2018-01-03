
select
    'oracle_io,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance  where inst_id = s.inst_id) || ',' ||
    'metric_name=' ||
    decode(metric_name, 
                'Network Traffic Volume Per Sec', 'network_mb_per_sec',
                'Physical Read Bytes Per Sec', 'app_read_io_mb_per_sec',
                'Physical Read Total Bytes Per Sec', 'total_read_io_mb_per_sec',
                'Physical Write Bytes Per Sec', 'app_write_io_mb_per_sec',
                'Physical Write Total Bytes Per Sec', 'total_write_io_mb_per_sec',              
                'Redo Generated Per Sec', 'redo_mb_per_sec'            
          ) || ' ' ||
    'metric_value='|| round(value/1024/1024,1) ||
    (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
    ',rac_metric_value='|| sum(round(value/1024/1024,1)) over(partition by metric_name) END)
from  gv$sysmetric s
where metric_name in (
                    'Network Traffic Volume Per Sec',
                    'Physical Read Bytes Per Sec' , 
                    'Physical Read Total Bytes Per Sec' ,
                    'Physical Write Bytes Per Sec' ,
                    'Physical Write Total Bytes Per Sec' ,
                    'Redo Generated Per Sec')
and group_id=2;
