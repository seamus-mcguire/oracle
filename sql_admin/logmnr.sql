
/********************
Supplemental logging needs to be enabled

select supplemental_log_data_min from v$database;
alter database add supplemental log data;

********************/

-- 2017-06-20 08:14 UK Time

-- Setup
CREATE TABLESPACE logmnrts DATAFILE SIZE 25M
AUTOEXTEND ON NEXT 25M MAXSIZE UNLIMITED;

exec DBMS_LOGMNR_D.SET_TABLESPACE (new_tablespace => 'logmnrts');

create role logmnr_admin;
grant select on v_$logmnr_contents to logmnr_admin;
grant select on v_$logmnr_parameters to logmnr_admin;
grant select on v_$logmnr_logs to logmnr_admin;
grant select on v_$archived_log to logmnr_admin;
grant  execute_catalog_role, select any dictionary, select any transaction, select any table, create tablespace, drop tablespace to logmnr_admin;

grant logmnr_admin to dba_user;
alter user dba_user quota unlimited on logmnrts;


--- Prepare to Mine
SELECT distinct name, TO_CHAR(first_time, 'DD-MON-YYYY HH24:MI:SS') first_time
FROM v$archived_log
WHERE name IS NOT NULL AND first_time BETWEEN TO_DATE('20-JUN-2017 08:00:00', 'DD-MON-YYYY HH24:MI:SS')
AND TO_DATE('20-JUN-2017 08:30:00', 'DD-MON-YYYY HH24:MI:SS')
and dest_id = 1
ORDER BY 2 desc

exec dbms_logmnr.add_logfile(LogFileName=>'+DG/db/archivelog/2017_06_20/thread_1_seq_321739.4985.947147541', Options=>dbms_logmnr.NEW);
exec dbms_logmnr.add_logfile(LogFileName=>'+DG/db/archivelog/2017_06_20/thread_2_seq_286555.6151.947147609', Options=>dbms_logmnr.NEW);
...

exec DBMS_LOGMNR.START_LOGMNR(OPTIONS => DBMS_LOGMNR.DICT_FROM_ONLINE_CATALOG); 

--exec dbms_logmnr.add_logfile(LogFileName=>'+FRA01/uflx01/archivelog/2017_06_20/thread_3_seq_171544.1543.947147543', Options=>dbms_logmnr.ADDFILE);

--- Process the results
SELECT count(*)
FROM  v$logmnr_contents
WHERE table_name = 'APPLICATION_PROPERTIES';

CREATE TABLE dba_user.log_miner tablespace logmnrts AS
SELECT * FROM v$logmnr_contents;

CREATE INDEX log_idx
    ON dba_user.log_miner(table_name);

SELECT timestamp, sql_redo
FROM log_miner
WHERE table_name = 'APPLICATION_PROPERTIES'
order by timestamp

exec  DBMS_LOGMNR.END_LOGMNR();

