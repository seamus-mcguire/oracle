
/*******************
  1. ASH 
********************/
select
    q.*, s.sql_text
from (
   select
        to_char(min(start_time),'YYYY-MM-DD HH24:MI:SS') start_time
        ,to_char(max(end_time),'YYYY-MM-DD HH24:MI:SS') end_time,
        max(delta) duration_seconds,
        inst_id,
        username,
        sql_id,
  sql_plan_hash_value,
  sql_child_number,
        sql_exec_id
   from ( select
               inst_id,
               session_id,
               u.username, 
               sql_id,
               sql_exec_id,
               sql_plan_hash_value,
      sql_child_number,
              cast(sample_time as date)     end_time,
              cast(sql_exec_start as date)  start_time,
              ((cast(sample_time    as date)) -
               (cast(sql_exec_start as date))) * (3600*24) delta
           from
              gv$active_session_history ash, dba_users u
           where 1=1
              and ash.user_id = u.user_id (+)
             and sql_exec_id is not null
             --and sql_id = '149sra3grycgx'
             -- and (sql_id = 'adkjsx85463kn' or top_level_sql_id = 'adkjsx85463kn')
             --and u.user_id = 73
        )
   group by inst_id, session_id, username, sql_id,sql_exec_id,sql_plan_hash_value,sql_child_number,start_time
) q,
gv$sql s 
where 1=1
and q.inst_id = s.inst_id (+)
and q.sql_id = s.sql_id (+)
and q.sql_plan_hash_value = s.plan_hash_value (+)
and q.sql_child_number = s.child_number (+)
and q.duration_seconds > 20
order by q.end_time desc


/*******************
  2. DBA_HIST_ASH
********************/
select
    q.*, dbms_lob.substr(s.sql_text, 128,1)
from (
   select
        to_char(min(start_time),'YYYY-MM-DD HH24:MI:SS') start_time
        ,to_char(max(end_time),'YYYY-MM-DD HH24:MI:SS') end_time,
        max(delta) duration_seconds,
        instance_number,
        username,
        sql_id,
  sql_plan_hash_value,
  sql_child_number,
        sql_exec_id
   from ( select
                instance_number,
                session_id,
                u.username,
                sql_id,
    sql_plan_hash_value,
    sql_child_number,
    sql_exec_id,
              cast(sample_time as date)     end_time,
              cast(sql_exec_start as date)  start_time,
              ((cast(sample_time    as date)) -
               (cast(sql_exec_start as date))) * (3600*24) delta
           from
              dba_hist_active_sess_history ash, dba_users u
           where 1=1
       and sql_exec_id is not null
       and ash.user_id = u.user_id
             --and sql_id = '149sra3grycgx'
             -- and (sql_id = 'adkjsx85463kn' or top_level_sql_id = 'adkjsx85463kn')
             --and user_id = 73
             --and sample_time > sysdate -1
             --and sample_time between to_date('2017-03-15 16:00:00', 'YYYY-MM-DD HH24:MI:SS') and to_date('2017-03-15 17:00:00', 'YYYY-MM-DD HH24:MI:SS')
        )
   group by instance_number, session_id, username, sql_id,sql_exec_id,sql_plan_hash_value,sql_child_number,start_time
) q,
dba_hist_sqltext s 
where 1=1
  and q.sql_id = s.sql_id (+)
  and q.duration_seconds > 100
order by q.start_time desc
 
