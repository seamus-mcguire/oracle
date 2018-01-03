
-- Explain plan for SQL IDENTIFIED 
set verify off
set pages 9999
set lines 150
select * from table(dbms_xplan.display_cursor(sql_id=>'8rsm5ys9zhxz6',cursor_child_no=>6,format=>'ALL'));
select * from table(dbms_xplan.display_awr(sql_id=>'149sra3grycgx',plan_hash_value=>3678468368,format=>'ALL'));

select plan_table_output
    from v$sql s,
   table(dbms_xplan.display_cursor(s.sql_id, s.child_number, 'basic')) t
    where 1=1
    --and s.sql_text like 'select PROD_CATEGORY%'
    and s.sql_id = '8rsm5ys9zhxz6'

