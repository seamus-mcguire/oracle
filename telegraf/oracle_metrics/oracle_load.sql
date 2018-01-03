with cpu_ora AS (   
   select 
           inst_id,    
           'CPU_ORA_CONSUMED'                                     CLASS,
           round(value/100,3)                             AAS
   from gv$sysmetric
    where metric_name='CPU Usage Per Sec'
   and group_id=2
),
cpu_os as(
             select 
                     prcnt.inst_id,
                    'CPU_OS'                                         CLASS ,
                    round((prcnt.busy*parameter.cpu_count)/100,3)   AAS
            from
              ( select value busy , inst_id
                from gv$sysmetric
                where metric_name='Host CPU Utilization (%)'
                   and group_id=2 ) prcnt,
              ( select value cpu_count , inst_id
                from gv$parameter
                 where name='cpu_count' )  parameter
            where prcnt.inst_id = parameter.inst_id
),
cpu_ash AS(
             select
                inst_id,
               'CPU_ORA_DEMAND'                                            CLASS,
               nvl(round( sum(decode(session_state,'ON CPU',1,0))/60,2),0) AAS
             from gv$active_session_history ash
              where SAMPLE_TIME >= (select BEGIN_TIME from v$sysmetric where metric_name='CPU Usage Per Sec' and group_id=2 )
               and SAMPLE_TIME < (select END_TIME from v$sysmetric where metric_name='CPU Usage Per Sec' and group_id=2 )
               group by inst_id
),
waits as (
           select m.inst_id, 
                 n.wait_class wait_class,
                 round((m.time_waited/m.INTSIZE_CSEC),3)                AAS
           from  gv$waitclassmetric  m,
                 v$system_wait_class n
           where m.wait_class_id=n.wait_class_id
             and n.wait_class != 'Idle'
)
select 
    'oracle_load,'||
    (select 'db='|| name || ',db_unique_name=' || db_unique_name || ',open_mode=' || 
      decode(open_mode, 'READ WRITE','primary', 'standby') from v$database) || ',' ||
    (select 'host='|| host_name || ',instance=' || instance_name from gv$instance where inst_id = q.inst_id) || ',' ||
    'wait_class='|| replace(wait_class,' ','_') || ' ' ||
    'wait_value='|| aas || ',' ||
    'cpu_count=' || (select value from v$parameter  where name='cpu_count') ||
     (case when (select count(*) cnt from gv$instance) = 1 THEN NULL ELSE 
        ',rac_wait_value='|| sum(aas) over(partition by wait_class) ||',' || 
        'rac_cpu_count=' || (select sum(value) from gv$parameter  where name='cpu_count') 
     END)
 from (
       select inst_id, wait_class, aas
       from (
       (select  
             cpu_ora.inst_id,
             decode(sign(cpu_os.aas-cpu_ora.aas), -1, 0, (cpu_os.aas - cpu_ora.aas )) cpu_os,
             cpu_ora.aas as cpu_ora,
             decode(sign(cpu_ash.aas-cpu_ora.aas), -1, 0, (cpu_ash.aas - cpu_ora.aas)) cpu_ora_wait
        from cpu_ora, cpu_os, cpu_ash
        where cpu_ora.inst_id = cpu_os.inst_id
          and cpu_ora.inst_id = cpu_ash.inst_id)
        UNPIVOT (aas FOR wait_class IN (CPU_OS as 'CPU_OS', CPU_ORA as 'CPU_ORA' , CPU_ORA_WAIT as 'CPU_ORA_WAIT' ))
        )
       union all
       select inst_id, wait_class, aas
       from waits
) q;
