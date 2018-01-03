

-- Backup Status
select start_time, end_time, round((end_time-start_time)*60*60,0) minutes, object_type, operation, status, mbytes_processed mb_bytes_processed
from v$rman_status s
where operation !='RMAN'
and start_time >= sysdate-7
order by start_time desc


-- SESSION_RECID, SESSION_STAMP are the PK/Join columns for the views

-- Rman Backup Job History
SELECT TO_CHAR (completion_time, 'YYYY-MON-DD') completion_time
       , TYPE
       , ROUND (SUM (bytes) / 1048576)          MB
       , ROUND (SUM (elapsed_seconds) / 60)     BCPTIME
    FROM (SELECT CASE
                    WHEN s.backup_type = 'L' THEN 'Archive Log'
--                    WHEN s.controlfile_included = 'YES' THEN 'Control File'
                 WHEN s.backup_type = 'D' THEN 'Full (Level ' || NVL (s.incremental_level, 0) || ')'
                    WHEN s.backup_type = 'I' THEN 'Incemental (Level ' || s.incremental_level || ')'
                    ELSE s.backup_type
                 END
                    TYPE
               , TRUNC (s.completion_time) completion_time
               , p.tag
               , p.bytes
               , s.elapsed_seconds
            FROM v$backup_piece p, v$backup_set s
           WHERE status = 'A' AND p.recid = s.recid
          UNION ALL
          SELECT 'Datafile Copy' TYPE, TRUNC (completion_time), tag, output_bytes, 0 elapsed_seconds FROM v$backup_copy_details)
GROUP BY tag, TO_CHAR (completion_time, 'YYYY-MON-DD'), TYPE
ORDER BY 1 ASC, 2, 3;

-- Recent Job Rman Output
select *
from GV$RMAN_OUTPUT
order by session_recid desc, session_stamp desc, recid; 

-- Backup set details
select ctime "Date"
        , decode(backup_type, 'L', 'Archive Log', 'D', 'Full', 'Incremental') backup_type
        , bsize "Size MB"
   from (select trunc(bp.completion_time) ctime
           , backup_type
           , round(sum(bp.bytes/1024/1024),2) bsize
      from v$backup_set bs, v$backup_piece bp
      where bs.set_stamp = bp.set_stamp
    and bs.set_count  = bp.set_count
      and bp.status = 'A'
      group by trunc(bp.completion_time), backup_type)
   order by 1 desc, 2
   

-- Tablespace Begin Backup mode
SELECT 
       'alter tablespace '|| t || ' begin backup;'
from (
      select distinct tablespace_name t
      from (
            select a.tablespace_name, b.status
            from sys.dba_data_files a ,v$backup b
            where 1=1
              and b.status = 'NOT ACTIVE'
              and b.file# = a.file_id
           )
    )
order by 1

-- Tablespace End Backup mode
SELECT 
       'alter tablespace '|| t || ' end backup;'
from (
      select distinct tablespace_name t
      from (
            select a.tablespace_name, b.status
            from sys.dba_data_files a ,v$backup b
            where 1=1
              and b.status = 'ACTIVE'
              and b.file# = a.file_id
           )
    )
order by 1


-- Backup Size
Select tag, sum(bytes/1024/1024/1024)
From RCAT_PLNDTD40.RC_BACKUP_PIECE
group by tag
having sum(bytes/1024/1024/1024) > 10
order by 1   desc


-- SCN for Last Level 0 Backup (use for set until scn in duplicate DB)
-- Rman Catalog
select min(next_chng)
from (select thread#, max(next_change#) next_chng
      from rc_backup_archivelog_details
      where btype = 'BACKUPSET'
        and btype_key in (select distinct bs.bs_key
                          from rc_backup_set bs,
                               rc_backup_piece bp,
                              (select max(start_time) start_time
                               from rc_backup_set
                               where incremental_level = 0) max_ex,
                              (select min(start_time) start_time
                               from rc_backup_set
                               where CONTROLFILE_INCLUDED = 'BACKUP'
                                 and start_time >  (select max(start_time) start_time
                                                    from rc_backup_set
                                                    where incremental_level = 0)
                              ) max_bs
                           where bs.start_time > (select max(start_time)
                                                  from (select sysdate-999 start_time
                                                        from dual
                                                        union
                                                        select start_time
                                                        from rc_backup_set
                                                        where CONTROLFILE_INCLUDED = 'BACKUP') ctrl
                                                  where ctrl.start_time < max_ex.start_time)
                            and bs.start_time <= max_bs.start_time
                            and bs.set_stamp = bp.set_stamp)
   group by thread#)
   
