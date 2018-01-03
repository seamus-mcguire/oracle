
-- get ash activity for a session, Update SID below
WITH ash AS (
  SELECT sample_time, session_state, a.wait_class, a.event,
         NVL(o.object_name, TO_CHAR(current_obj#)) object, a.sql_plan_line_id
  FROM   gv$session s, gv$active_session_history a, dba_objects o
  WHERE  1=1
  and s.inst_id  = a.inst_id
  and s.sid = 396
  AND    a.sql_id = NVL(s.sql_id, s.prev_sql_id)
  AND    o.object_id (+) = a.current_obj#
), current_time AS (
  SELECT MAX(sample_time) max_sample_time
  FROM   ash
), prev_line_det AS (
  SELECT sample_time, session_state, wait_class, event, object, sql_plan_line_id,
         LAG(session_state)    OVER (ORDER BY sample_time) AS prev_session_state,
         LAG(wait_class)       OVER (ORDER BY sample_time) AS prev_wait_class,
         LAG(event)            OVER (ORDER BY sample_time) AS prev_event,
         LAG(object)           OVER (ORDER BY sample_time) AS prev_object,
         LAG(sql_plan_line_id) OVER (ORDER BY sample_time) AS prev_sql_plan_line_id,
         ROW_NUMBER()          OVER (ORDER BY sample_time) AS sample_number
  FROM   ash
), lines_match AS (
  SELECT sample_time, session_state, wait_class, event, object, sql_plan_line_id, sample_number,
         CASE WHEN session_state = prev_session_state
              AND  NVL(wait_class, 'x')    = NVL(prev_wait_class, 'x')
              AND  NVL(event, 'x')         = NVL(prev_event, 'x')
              AND  object        = prev_object
              AND  sql_plan_line_id = prev_sql_plan_line_id
              THEN 'Y'
              ELSE 'N'
         END as match_prev
  FROM   prev_line_det
), distinct_only AS (
  SELECT sample_time, session_state, wait_class, event, object, sql_plan_line_id, sample_number,
         LEAD(sample_number) OVER (ORDER BY sample_number) next_sample_number
  FROM   lines_match, current_time
  WHERE  match_prev = 'N'
  OR     sample_time = max_sample_time
  ORDER BY sample_time DESC
)
SELECT sample_time "Start", (next_sample_number - sample_number) "Samples", session_state, wait_class,
       event, object, sql_plan_line_id
FROM   distinct_only
WHERE  1=1