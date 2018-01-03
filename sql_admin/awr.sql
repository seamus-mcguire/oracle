
-- Manually create a Snapshot
exec dbms_workload_repository.create_snapshot;

-- check snap/retention settings
select * from dba_hist_wr_control
-- 131400 3 months, 262800 6 months
exec dbms_workload_repository.modify_snapshot_settings(retention=>131400, interval=>30);


@?/rdbms/admin/awrrpt.sql      -- basic AWR report
@?/rdbms/admin/awrsqrpt.sql    -- Standard SQL statement Report
@?/rdbms/admin/awrddrpt.sql    -- Period diff on current instance
@?/rdbms/admin/awrrpti.sql     -- Workload Repository Report Instance (RAC)
@?/rdbms/admin/awrgrpt.sql     -- AWR Global Report (RAC)
@?/rdbms/admin/awrgdrpt.sql    -- AWR Global Diff Report (RAC)
@?/rdbms/admin/awrinfo.sql     -- Script to output general AWR information

@?/rdbms/admin/addmrpt.sql		-- ADDM current instance
@?/rdbms/admin/addmrpti.sql		-- ADDM RAC

@?/rdbms/admin/ashrpti.sql	-- ASH RAC
@?/rdbms/admin/ashrpt.sql	-- ASH current instance

-- Snapshots
select distinct snap_id, to_char(trunc(begin_interval_time, 'MI'), 'YYYY-MM-DD HH24:MI:SS') begin_date, to_char(trunc(end_interval_time, 'MI'), 'YYYY-MM-DD HH24:MI:SS') end_date 
from dba_hist_snapshot
order by end_date desc


-- Generate AWR - replace the snapshot IDs
set feedback off;
set pages 0  
set linesize 1500;
spool awr.html
variable dbid number                                                                                                    
declare                                                                                                                 
begin                                                                                                                   
select dbid  into :dbid from dba_hist_database_instance where rownum=1;                                                                                                         
end;                                                                                                                    
/                                                                                                                       
select output 
from table(dbms_workload_repository.awr_global_report_html(
l_dbid=>:dbid, l_inst_num=>'',l_bid=>55357,l_eid=>55381,l_options=>0));  
--awr_report_html
spool off


-- Sizing AWR
@?/rdbms/admin/utlsyxsz.sql 

prompt
prompt Weekly Snap IDs
prompt ~~~~~~~~~~~~~~~~
SELECT MIN(snap_id) start_snap, TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD HH24:MI') date_time
FROM sys.wrm$_snapshot
WHERE TRUNC(begin_interval_time) = TRUNC(NEXT_DAY(SYSDATE-14,'SUNDAY')+1);

SELECT MIN(snap_id) end_snap, TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD HH24:MI') date_time
FROM sys.wrm$_snapshot
WHERE TRUNC(begin_interval_time) = TRUNC(NEXT_DAY(SYSDATE-7,'SUNDAY')+1);

