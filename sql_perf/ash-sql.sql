
 
-- % Waits for a SQL
select nvl(event, session_state) event,
       round(100*count(*)/(sum(count(1)) over ()), 2) "% query time"
from gv$active_session_history
where 1=1
--and sql_id = '8rsm5ys9zhxz6'
and sql_exec_id = 50331655
group by nvl(event, session_state)
order by count(*) desc

-- What is a sql_exec_id doing
select sample_time, seq#, session_state, event, o.object_name
from gv$active_session_history s, dba_objects o
where sql_exec_id = 50331655
and o.object_id = s.current_obj#
order by sample_time desc

-- where in the plan for a given SQL
SELECT ash.sql_plan_line_id,
       ash.sql_plan_operation,
       ash.sql_plan_options,
       p.object_name,
       round(100*COUNT(*)/
          sum(count(1)) over(), 2) "% time"
FROM gv$active_session_history ash,
        gv$sql_plan p
WHERE ash.sql_id = p.sql_id
and ash.inst_id = p.inst_id 
AND ash.sql_plan_hash_value = p.plan_hash_value
AND ash.sql_plan_line_id = P.id
AND ash.sql_id = '149sra3grycgx'
--AND ash.sql_plan_hash_value = :plan_hash_value
GROUP BY ASH.SQL_PLAN_LINE_ID,
         ASH.SQL_PLAN_OPERATION,
         ASH.SQL_PLAN_OPTIONS,
         p.object_name
ORDER BY count(*) DESC

