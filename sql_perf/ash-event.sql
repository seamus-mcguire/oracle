

-- Get long wait events from ASH
-- gv$active_session_history
with ash_hist as
     (select sample_time, u.username, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3,
      inst_id,
      COUNT(1) over (partition by inst_id, u.username, session_id, session_serial#,event,seq#,p1,p2,p3 
                     ORDER BY sample_time, inst_id 
                     RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as samples
      from
      gv$active_session_history s,
      dba_users u
      where 1=1
        and sample_time between to_timestamp('2017-01-16 12:30:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2017-01-21 13:00:00', 'YYYY-MM-DD HH24:MI:SS')
        and s.user_id = u.user_id
        and event is not null
        --and event like 'log file sync'
        --and wait_class like 'Commit'
        )
select min(sample_time) first_sample, max(sample_time) last_sample, max(sample_time)-min(sample_time) time_,
       samples, username, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3, 
       inst_id
from ash_hist
where samples > 1
group by username, samples, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3,
         inst_id
order by last_sample desc, inst_id 

-- dba_hist_active_sess_history
with ash_hist as
     (select sample_time, u.username, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3,
      instance_number,
      --inst_id,
      COUNT(1) over (partition by instance_number, u.username, session_id, session_serial#,event,seq#,p1,p2,p3 
                     ORDER BY sample_time, instance_number 
                     RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as samples
      from
      --gv$active_session_history s,
      dba_hist_active_sess_history s,
      dba_users u
      where 1=1
        and sample_time between to_timestamp('2017-01-16 12:30:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2017-01-21 13:00:00', 'YYYY-MM-DD HH24:MI:SS')
        and s.user_id = u.user_id
        and event is not null
        --and event like 'log file sync'
        --and wait_class like 'Commit'
        )
select min(sample_time) first_sample, max(sample_time) last_sample, max(sample_time)-min(sample_time) time_,
       samples, username, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3, 
       instance_number
from ash_hist
where samples > 1
group by username, samples, session_id, session_serial#, blocking_session, event,seq#,p1,p2,p3,
         instance_number
order by last_sample desc, instance_number 
