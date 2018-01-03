

-- Look for service times 
select 
        event
        , sample_time   
        ,user_id
   ,      session_state
   ,      to_char(tm_delta_time/1000000) tm_delta_time_seconds
   ,      to_char(tm_delta_cpu_time/1000000) tm_delta_cpu_time_seconds
,to_char(tm_delta_db_time/1000000) tm_delta_db_time
from GV$active_session_history 
where 1=1
and to_number(to_char(tm_delta_db_time/1000000)) > 1
and user_ID in ( select user_id from dba_users where username like 'EFX%')
--and event = 'log file sync'
 --and machine like 'gbl050%'
 and event is not null
order by sample_time desc, tm_delta_db_time desc

-- Top Session by % of DB Time
select session_id, round((count(*) /
sum(count(*)) over ())*100,2) ActPct
from v$active_session_history
where sample_time > sysdate-5/1440
group by session_id
order by ActPct desc


-- How many active sessions
select sample_time, count(*)
from gv$active_session_history
where sample_time between to_timestamp('2016-11-21 12:55:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2016-11-21 13:05:00', 'YYYY-MM-DD HH24:MI:SS')
group by sample_time
having count(*) > 4
order by sample_time desc  


-- Who was active
select u.username, s.* 
from gv$active_session_history s, dba_users u
where sample_time between to_timestamp('2016-11-29 14:02:00', 'YYYY-MM-DD HH24:MI:SS') and to_timestamp('2016-11-29 14:05:00', 'YYYY-MM-DD HH24:MI:SS')
and s.user_id = u.user_id 
order by sample_time

-- Blocking Sessions
select
*--session_id, event, blocking_session
from v$active_session_history
where
blocking_session is not null
and user_ID in ( select user_id from dba_users where username like 'USER%')
and sample_time > sysdate - 1--120/1440
order by sample_time desc


