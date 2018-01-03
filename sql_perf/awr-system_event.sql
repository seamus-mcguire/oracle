
-- Avg Wait Times
select time,
       snap_id,
       round(time_delta/1e3/nullif(waits_delta,0), 1) avg_wait_ms,
       waits_delta num_of_waits,
       round(time_delta/1e6) total_seconds
from
(       
  select sn.snap_id,
         sn.begin_interval_time time,
         e.total_waits - lag(e.total_waits) over (partition by e.event_name order by e.snap_id) waits_delta,
         e.time_waited_micro - lag(e.time_waited_micro) OVER (PARTITION BY e.event_name ORDER BY e.snap_id) time_delta
  from dba_hist_system_event e,
       dba_hist_snapshot sn
  where e.snap_id = sn.snap_id
  AND e.event_name = 'log file parallel write'
) ev
WHERE ev.time_delta > 0 
order by time desc


-- time spent on system events
select 
                sort_hr,
                instance_number,
                day,
                hr,
		        event_name,
                sum(total_waits) total_waits,
                sum(time_waited)/1000000 time_waited_sec,
                decode(sum(total_waits),0,0,(sum(time_waited)/sum(total_waits))/1000000) avg_wait_sec,
                decode(sum(total_waits),0,0,(sum(time_waited)/sum(total_waits))/1000) avg_wait_milli
         from   (select to_char(ss.begin_interval_time, 'YYYYMMDDHH24') sort_hr,
                        to_char(ss.begin_interval_time, 'DD-MON') day,
                        to_char(ss.begin_interval_time, 'HH24')||':00' hr,
			s.event_name,
			s.instance_number,
                        s.snap_id,
                        nvl(decode(greatest(s.time_waited_micro,
                                   lag(s.time_waited_micro,1,0)
                                           over (partition by   s.dbid,
                                                                s.instance_number
                                                 order by s.snap_id)),
                                   s.time_waited_micro,
                                   s.time_waited_micro - lag(s.time_waited_micro)
                                                             over (partition by s.dbid,
                                                                                s.instance_number
                                                                   order by s.snap_id),
                                          s.time_waited_micro), 0) time_waited,
                        nvl(decode(greatest(s.total_waits,
                                   lag(s.total_waits,1,0)
                                           over (partition by   s.dbid,
                                                                s.instance_number
                                                 order by s.snap_id)),
                                   s.total_waits,
                                   s.total_waits - lag(s.total_waits)
                                                             over (partition by s.dbid,
                                                                                s.instance_number
                                                                   order by s.snap_id),
                                          s.total_waits), 0) total_waits
                 from   dba_hist_system_event                   s,
                        dba_hist_snapshot                       ss
                 where  1=1
--				 and s.event_name like '%log file sync%'
				 and s.event_name like '%commit%'
                 and    ss.snap_id = s.snap_id
                 and    ss.dbid = s.dbid
                 and    ss.instance_number = s.instance_number
--		 and	ss.begin_interval_time >= trunc(sysdate) - 1
               )
         group by 
                  sort_hr,
                  instance_number,
                  day,
                  hr,
		  event_name
order by sort_hr desc, instance_number
		  
-- Query to get  average log write write times
select
       dbid,
       btime,
       round((time_ms_end-time_ms_beg)/nullif(count_end-count_beg,0),1) avg_ms
from (
select
       s.dbid,
       to_char(s.BEGIN_INTERVAL_TIME,'DD-MON-YY HH24:MI')  btime,
       total_waits count_end,
       time_waited_micro/1000 time_ms_end,
       Lag (e.time_waited_micro/1000)
              OVER( PARTITION BY e.event_name ORDER BY s.snap_id) time_ms_beg,
       Lag (e.total_waits)
              OVER( PARTITION BY e.event_name ORDER BY s.snap_id) count_beg
from
       DBA_HIST_SYSTEM_EVENT e,
       DBA_HIST_SNAPSHOT s
where
       s.snap_id=e.snap_id
   and e.event_name in (
                  'log file sync',
                  'log file parallel write'
                )
   and  s.dbid=e.dbid
)
order by btime


-- More avg
select sn.END_INTERVAL_TIME,
before.instance_number,
 (after.total_waits-before.total_waits) "number of waits",
(after.time_waited_micro-before.time_waited_micro)/
 (after.total_waits-before.total_waits)/1000000 "ave microseconds",
      before.event_name "wait name"
from DBA_HIST_SYSTEM_EVENT before, 
     DBA_HIST_SYSTEM_EVENT after,
     DBA_HIST_SNAPSHOT sn
where 1=1 
and before.event_name='log file sync' 
and after.event_name=before.event_name 
and after.snap_id=before.snap_id+1 
and before.instance_number=after.instance_number 
and after.snap_id=sn.snap_id 
and after.instance_number = sn.instance_number
and after.instance_number=sn.instance_number 
--and (after.total_waits-before.total_waits) > &&MINIMUMWAITS
and before.snap_id IN (44406, 44407, 44408)
order by after.snap_id



