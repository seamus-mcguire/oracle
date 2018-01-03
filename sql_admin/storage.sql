
-- Tablespace Sizing
SELECT 
       ts_name,
       ts_size_gb,
       ts_used_gb,
       ts_size_gb-ts_used_gb ts_free_gb,
       round(100*(ts_used_gb/decode(ts_size_gb,0,null,ts_size_gb)),1) pct_used_alloc,
       ts_extend_gb,
       round(100*(ts_used_gb/decode(ts_extend_gb,0,null,ts_extend_gb)),1) pct_used_extend,
       sum(ts_size_gb) over() db_current_size,
       sum(ts_extend_gb) over() db_extend_size 
FROM (
   SELECT
          ts.tablespace_name ts_name,
          round(NVL(df.bytes, 0)/1024/1024/1024,1) ts_size_gb,
          round(NVL(df.bytes - NVL(fs.bytes, 0), 0)/1024/1024/1024,1) ts_used_gb,
          round(NVL(df.extend_bytes,0)/1024/1024/1024,1) ts_extend_GB
   FROM dba_tablespaces ts,
       (SELECT
               tablespace_name, SUM(bytes) bytes,
               sum(decode(AUTOEXTENSIBLE, 'YES', MAXBYTES, BYTES)) extend_bytes
        FROM dba_data_files
        GROUP BY tablespace_name) df,
       (SELECT
               tablespace_name, SUM(bytes) bytes
        FROM dba_free_space
        GROUP BY tablespace_name) fs
   WHERE ts.tablespace_name = df.tablespace_name (+)
     AND ts.tablespace_name = fs.tablespace_name (+)
     AND NOT (ts.extent_management LIKE 'LOCAL' AND ts.contents LIKE 'TEMPORARY')
    )
ORDER BY ts_name

-- Space Used by Schema
SELECT owner, segment_type, ROUND(SUM(bytes)/1024/1024/1024,0) size_gb, 
       round(sum(SUM(bytes)/1024/1024/1024) over(),0) total_size_gb 
FROM dba_segments
WHERE 1=1 
--and owner = ''
GROUP BY owner, segment_type
ORDER BY owner

-- Space Used by Segments
SELECT segment_name as object_name, 
      (CASE WHEN segment_type = 'LOBSEGMENT' THEN 
           (select 'LOB on ' || table_name || '.' || column_name 
            from dba_lobs l 
            where l.owner = s.owner 
               and l.segment_name = s.segment_name) 
            WHEN segment_type = 'INDEX' THEN 
           (select 'INDEX on ' || table_name  
            from dba_indexes i  
            where i.owner = s.owner 
               and i.index_name = s.segment_name)
         ELSE segment_type END) as object_type,   
       ROUND(bytes/1024/1024/1024,1) size_gb
FROM dba_segments s
WHERE 1=1 
--  and owner = 'OWNER'
ORDER BY bytes desc


-- All files for DB
select name from v$datafile
UNION ALL
select name from v$tempfile
UNION ALL
select member from v$logfile
UNION ALL
select name from v$controlfile
order by 1

-- DB Size
select round(sum(bytes)/1024/1024/1024,1) db_size_gb
from (
select bytes from v$datafile
UNION ALL
select bytes from v$tempfile
UNION ALL
select bytes from v$log
UNION ALL
select bytes from v$standby_log
UNION ALL
SELECT block_size*file_size_blks 
FROM v$controlfile)


-- Max DB size compared to ASM disk group
-- assumes only one disk group for the database
-- To test - partition by dg_usage.name if TS (and all data files) in different DG
SELECT 
       ts_usage.ts_name,
       ts_size_gb,
       ts_used_gb,
       ts_size_gb-ts_used_gb ts_free_gb,
       ts_extend_GB,
       round(100*(ts_used_gb/decode(ts_size_gb,0,null,ts_size_gb)),1) pct_used,
       sum(ts_size_gb) over() db_current_size,
       sum(ts_extend_gb) over() db_extend_size,
       dg_usage.name,
       dg_usage.free_gb,
       dg_usage.total_gb,
       dg_usage.free_gb - (sum(ts_extend_gb) over() - sum(ts_size_gb) over()) db_dg_growth_gap 
FROM (
   SELECT
          ts.tablespace_name ts_name,
          round(NVL(df.bytes, 0)/1024/1024/1024,1) ts_size_gb,
          round(NVL(df.bytes - NVL(fs.bytes, 0), 0)/1024/1024/1024,1) ts_used_gb,
          round(NVL(df.extend_bytes,0)/1024/1024/1024,1) ts_extend_GB
   FROM dba_tablespaces ts,
       (SELECT
               tablespace_name, SUM(bytes) bytes,
               sum(decode(AUTOEXTENSIBLE, 'YES', MAXBYTES, BYTES)) extend_bytes
        FROM dba_data_files
        GROUP BY tablespace_name) df,
       (SELECT
               tablespace_name, SUM(bytes) bytes
        FROM dba_free_space
        GROUP BY tablespace_name) fs
   WHERE ts.tablespace_name = df.tablespace_name (+)
     AND ts.tablespace_name = fs.tablespace_name (+)
     AND NOT (ts.extent_management LIKE 'LOCAL' AND ts.contents LIKE 'TEMPORARY')
 ) ts_usage,
  (select  distinct
       dg.name,
       df.tablespace_name ts_name,
       round(total_mb/1024,2) total_gb,
       round(free_mb/1024,2) free_gb,
       round((free_mb/total_mb),2)*100 pct_free
   FROM v$asm_diskgroup dg, dba_data_files df
   where substr(df.file_name,2, instr(df.file_name, '/')-2) = dg.name (+) 
   ) dg_usage
WHERE ts_usage.ts_name = dg_usage.ts_name 
ORDER BY ts_name


-- all segment sizes for a table
-- not tested, LOB subpartitions
with segs as
(select segment_owner, 
			-- segment name returned by proc is the segment table name, not the lob segment name
            (case when segment_type LIKE 'LOB%' then
               (select segment_name
                 from dba_lobs 
                 where owner = t.segment_owner
                   and table_name = t.segment_name
                   and column_name = t.lob_column_name
                   and partition_name = t.partition_name) 
              else segment_name end) as segment_name, 
            decode(segment_type,'LOB','LOBSEGMENT',segment_type) segment_type,
            tablespace_name, 
			-- parition name returned by proc is the table, not the lob partition
             (case when segment_type LIKE 'LOB PARTITION' then
               (select lob_partition_name
                 from dba_lob_partitions
                 where table_owner = t.segment_owner
                   and table_name = t.segment_name
                   and column_name = t.lob_column_name
                   and partition_name = t.partition_name) 
              else partition_name end) as partition_name,  
            lob_column_name
      FROM table(DBMS_SPACE.OBJECT_DEPENDENT_SEGMENTS('SCHEMA','TABLE',NULL,1)) t)
select 
       round(sum(s.bytes/1024/1024/1024) over(),1) tot_size,
       round(sum(s.bytes/1024/1024/1024) over(partition by s.segment_type),1) as seg_type_size, 
       round(s.bytes/1024/1024/1024,1) seg_size, 
       segs.*
from  
     segs,
     dba_segments s
where s.owner = segs.segment_owner
  and s.segment_name = segs.segment_name 
  and s.segment_type = segs.segment_type
  and nvl(s.partition_name,1) = nvl(segs.partition_name,1)
order by 2 desc,6 


-- Historical Tablespace Usage  
SELECT t.name,
       MAX(to_char(ROUND((u.tablespace_size*dt.block_size)/1024/1024/1024, 1), '999999.99')) size_gb,
       MAX(to_char(ROUND((u.tablespace_usedsize*dt.block_size)/1024/1024/1024,1), '999999.99')) used_gb,
       trunc(to_date(u.rtime, 'MM/DD/YYYY HH24:MI:SS'))
FROM dba_hist_tbspc_space_usage u, v$tablespace t, dba_tablespaces dt
WHERE 1=1
  AND u.tablespace_id = t.ts#
  AND t.name = dt.tablespace_name
    AND t.name = 'TABLESPACE'
GROUP BY t.name, trunc(to_date(u.rtime, 'MM/DD/YYYY HH24:MI:SS'))
ORDER BY 1, 4 DESC

-- Historical full Database Usage
select
       min((select name from v$database)),
       to_char(sysdate, 'YYYY-MM-DD') "Date",
       round(sum(tablespace_size*dts.BLOCK_SIZE)/1024/1024/1024) "DB Total Size GB",
       round(sum(used_space*dts.BLOCK_SIZE)/1024/1024/1024) "DB Used Size GB"
from dba_tablespace_usage_metrics t, DBA_TABLESPACES dts
where t.TABLESPACE_NAME = dts.TABLESPACE_NAME
UNION ALL
Select  
        min(d.name),
        to_char(to_date(min(rtime), 'MM/DD/YYYY HH24:MI:SS'), 'YYYY-MM-DD'),
        round(sum(tablespace_size*dts.BLOCK_SIZE)/1024/1024/1024),
        round(sum(tablespace_usedsize*dts.BLOCK_SIZE)/1024/1024/1024)
From SYS.DBA_HIST_TBSPC_SPACE_USAGE t, v$database d, DBA_TABLESPACES dts, v$tablespace vts
where 1=1
and t.DBID = d.dbid
and t.TABLESPACE_ID = vts.TS#
and vts.NAME = dts.TABLESPACE_NAME
and (t.rtime, t.dbid) =(select min(rtime),min(dbid) from SYS.DBA_HIST_TBSPC_SPACE_USAGE );


-- Table Candidates for Reorg
SELECT
      UT.TABLE_NAME,
      ROUND(UT.NUM_ROWS * UT.AVG_ROW_LEN / 1024 / 1024, 2) "CALCULATED SIZE MB",
      ROUND(US.BYTES / 1024 /1024,2) "ALLOCATED SIZE MB",
      ROUND(US.BYTES / (UT.NUM_ROWS * UT.AVG_ROW_LEN),2) "TIMES LARGER"
FROM USER_TABLES UT, USER_SEGMENTS US
WHERE (UT.NUM_ROWS > 0 AND UT.AVG_ROW_LEN > 0 AND US.BYTES > 0)
  AND UT.PARTITIONED = 'NO'
  AND UT.IOT_TYPE IS NULL
  AND UT.IOT_NAME IS NULL
  AND UT.TABLE_NAME = US.SEGMENT_NAME
  AND ROUND(US.BYTES / 1024 /1024,2) > 5
  AND ROUND(US.BYTES / 1024 /1024,2) > (ROUND(UT.NUM_ROWS * UT.AVG_ROW_LEN / 1024 / 1024, 2)* 2)
ORDER BY 4 DESC



-- Move Files around
select 'alter database rename file ''' || name || ''' to ''' ||
replace(replace(name, '/u15', '/u20'), '/u09', '/u20')
|| ''';'
--sum(bytes)/1024/1024/1024
from (select name, bytes
      from v$datafile
      union all
      select name, bytes
      from v$tempfile
      union all
      select member, group#
      from v$logfile)
Order by 1 Asc


-- Segment location in Datafile
select owner, segment_name, file_id, block_id start_, (block_id+blocks)-1 end_, blocks
from dba_extents
where file_id=33
union
select 'SYS', '***FREE***', file_id, block_id start_, (block_id+blocks)-1 end_, blocks
from dba_free_space
where file_id=33
order by 4


-- Object for a given block
SELECT TABLESPACE_NAME, SEGMENT_TYPE, OWNER, SEGMENT_NAME
FROM DBA_EXTENTS
WHERE FILE_ID = :1
AND :2  BETWEEN BLOCK_ID AND block_id + BLOCKS - 1


-- DB Size by Path 
SELECT 
      SUBSTR(name,1, INSTR(name,'/',-1)) path_,  
      ROUND(SUM(bytes)/1024/1024/1024) size_in_gb
FROM 
     (SELECT name, bytes
      FROM v$datafile
      UNION ALL
      SELECT name, bytes
      FROM v$tempfile
      UNION ALL
      SELECT lf.member name, l. bytes
      FROM v$logfile lf, v$log l
      WHERE l.group# = lf.group# 
      UNION ALL
      SELECT name, block_size*file_size_blks 
      FROM v$controlfile
     )
GROUP BY SUBSTR(name,1, INSTR(name,'/',-1))
ORDER BY path_

-- Duplicate File Names with Path stripped out
select name, bytes/1024/1024
from v$datafile
where SUBSTR(name, INSTR(name,'/',-1)+1 ) IN  (
select SUBSTR(name, INSTR(name,'/',-1)+1 )
from v$datafile
group by SUBSTR(name, INSTR(name,'/',-1)+1 )
having count(*) > 1
)
order by SUBSTR(name, INSTR(name,'/',-1)+1 )


-- Data file Fragmentation (how much can be shrinked)
SELECT *
FROM 
     (SELECT
             df.tablespace_name,
             file#,
             vd.blocks blocks_t,
             block_id start_,
             (block_id+df.blocks)-1 end_,
             df.blocks,
             FIRST_VALUE(block_id) OVER (PARTITION BY df.tablespace_name, file# ORDER BY block_id DESC) s,
             FIRST_VALUE((block_id+df.blocks)-1) OVER (PARTITION BY df.tablespace_name, file# ORDER BY block_id DESC) e,
             round(vd.block_size*vd.blocks/1048576) mb,
             -- round(vd.block_size*DFLINIT/1048576) ext_mb,
             round(vd.block_size*df.block_id/1048576) last_mb,
             round((vd.block_size*DFLINIT+vd.block_size*df.block_id)/1048576)+1 resize_to_mb,
             round((vd.block_size*df.blocks-vd.block_size*DFLINIT)/1048576) saving_mb
      FROM dba_free_space df, v$datafile vd, sys.ts$
      WHERE file#=file_id
        AND ts$.ts#=vd.ts#
		--and vd.file# in ()
        --  and vd.blocks =(block_id+df.blocks)-1
      --ORDER BY df.tablespace_name, file#, block_id desc
     ) 
WHERE start_ = s
  AND end_ = e
ORDER BY tablespace_name, file#

-- More shrink possibility
SELECT contents         AS "Contents",
    tablespace_name     AS "Tablespace",
    file_id             AS "File_ID",
    status              AS "Status",
    blocks * block_size AS "Total",
    autoextensible      AS "AutoExtends",
    CASE
        WHEN maxblocks < greatest (minblocks, minblocks_empty_ts) THEN '-- Be carefull, the datafile will not grow after srhirnk due to the maxsize being lower than the new size'||chr (10)
    END||'ALTER DATABASE DATAFILE ' || TO_CHAR (file_id) || ' RESIZE ' || TO_CHAR (greatest (minblocks, minblocks_empty_ts) * block_size) ||chr (59) AS "Resize_File_Command"
FROM
    (
    -- tablespaces info
    SELECT contents,
        tablespace_name,
        block_size,
        CASE
            WHEN bigfile = 'YES' THEN 3 * min_extlen / block_size
            ELSE 2 * min_extlen / block_size
        END AS minblocks_empty_ts
    FROM dba_tablespaces
    )
JOIN
    (
    -- datafiles info
    SELECT tablespace_name,
        file_id,
        file_name,
        status,
        blocks,
        CASE
            WHEN user_blocks < lastfreeblockend AND NOT lastfreeblockbegin IS NULL THEN lastfreeblockbegin - 1
            ELSE blocks
        END AS minblocks,
        CASE autoextensible
            WHEN 'YES' THEN maxblocks
            WHEN 'NO'  THEN blocks
        END AS maxblocks,
        autoextensible
    FROM dba_data_files
    LEFT OUTER JOIN
        (
        -- datafiles last free extent position & free space info NEW
        SELECT file_id,
            MAX (block_id) AS lastfreeblockbegin,
            MAX (block_id + blocks - 1) lastfreeblockend
        FROM dba_free_space
        GROUP BY file_id
        ) USING (file_id)
    ) USING (tablespace_name)
WHERE contents = 'UNDO'


-- same as above
set linesize 1000 pagesize 0 feedback off trimspool on
with
 hwm as (
  -- get highest block id from each datafiles ( from x$ktfbue as we don't need all joins from dba_extents )
  select /*+ materialize */ ktfbuesegtsn ts#,ktfbuefno relative_fno,max(ktfbuebno+ktfbueblks-1) hwm_blocks
  from sys.x$ktfbue group by ktfbuefno,ktfbuesegtsn
 ),
 hwmts as (
  -- join ts# with tablespace_name
  select name tablespace_name,relative_fno,hwm_blocks
  from hwm join v$tablespace using(ts#)
 ),
 hwmdf as (
  -- join with datafiles, put 5M minimum for datafiles with no extents
  select file_name,nvl(hwm_blocks*(bytes/blocks),5*1024*1024) hwm_bytes,bytes,autoextensible,maxbytes
  from hwmts right join dba_data_files using(tablespace_name,relative_fno)
 )
select
 case when autoextensible='YES' and maxbytes>=bytes
 then -- we generate resize statements only if autoextensible can grow back to current size
  '/* reclaim '||to_char(ceil((bytes-hwm_bytes)/1024/1024),999999)
   ||'M from '||to_char(ceil(bytes/1024/1024),999999)||'M */ '
   ||'alter database datafile '''||file_name||''' resize '||ceil(hwm_bytes/1024/1024)||'M;'
 else -- generate only a comment when autoextensible is off
  '/* reclaim '||to_char(ceil((bytes-hwm_bytes)/1024/1024),999999)
   ||'M from '||to_char(ceil(bytes/1024/1024),999999)
   ||'M after setting autoextensible maxsize higher than current size for file '
   || file_name||' */'
 end SQL
from hwmdf
where bytes-hwm_bytes>1024*1024 -- resize only if at least 1MB can be reclaimed
order by bytes-hwm_bytes desc;



