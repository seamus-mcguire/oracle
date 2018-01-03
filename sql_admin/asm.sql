
-- Disk Groups and Usage
SET LINE 500
Col Name form a20
SELECT 
       name,
       block_size,
       state,
       type,
       round(total_mb/1024,2) total_gb,
       round(free_mb/1024,2) free_gb,
       round((free_mb/total_mb),2)*100 pct_free,
	   round(((total_mb-free_mb)/total_mb),2)*100 pct_used
  FROM v$asm_diskgroup
 ORDER BY name;

 -- Disk Status
set line 1000
Col  disk_group form a20
Col  disk_name form a20
Col  device_path form a50
select dg.name disk_group,
       d.name disk_name,
       d.path device_path,
       d.total_mb,
	   d.state
  FROM v$asm_disk d,
       v$asm_diskgroup dg
 WHERE dg.group_number = d.group_number
 -- and dg.name IN ('DG')
 ORDER BY dg.name,
          d.group_number,
       d.disk_number;

-- Free ASM disks and their paths
set line 500
col "Path"    		form a35
col "Disk Size"    form a9
select header_status                   "Header"
, mode_status                     "Mode"
, path                            "Path"
, lpad(round(os_mb/1024),7)||'Gb' "Disk Size"
from   v$asm_disk
where header_status in ('FORMER','CANDIDATE')
order by os_mb,path;

-- List all Files in ASM
SELECT
       concat('+'||gname, sys_connect_by_path(aname, '/')) full_path
FROM
    (SELECT g.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex
     FROM v$asm_alias a, v$asm_diskgroup g
     WHERE a.group_number = g.group_number
	 --AND g.name = 'DG'
	 )
START WITH (mod(pindex, power(2, 24))) = 0
CONNECT BY PRIOR rindex = pindex;

-- files in ASM not in the DB, not perfect
with asm_files as (
SELECT
       concat('+'||gname, sys_connect_by_path(aname, '/')) full_path
FROM
    (SELECT g.name gname, a.parent_index pindex, a.name aname, a.reference_index rindex
     FROM v$asm_alias a, v$asm_diskgroup g
     WHERE a.group_number = g.group_number
	 AND g.name = 'DG'
	 )
START WITH (mod(pindex, power(2, 24))) = 0
CONNECT BY PRIOR rindex = pindex), 
data_files as (select file_name from dba_data_files)
select upper(full_path) from asm_files
minus 
select upper(file_name) from data_files


-- Space used by DB per Disk Group ** Very Slow **
col database format a10
SELECT 
        disk_group_name,
        SUBSTR(alias_path,2,INSTR(alias_path,'/',1,2)-2) Database
        ,ROUND(SUM(alloc_bytes)/1024/1024/1024,1) "GB"
FROM
    (SELECT
             SYS_CONNECT_BY_PATH(alias_name, '/') alias_path
             ,alloc_bytes
             ,disk_group_name
     FROM
          (SELECT
                   g.name disk_group_name
                   , a.parent_index pindex
                   , a.name alias_name
                   , a.reference_index rindex
                   , f.space alloc_bytes
                   , f.type type
           FROM v$asm_file f RIGHT OUTER JOIN v$asm_alias a
           USING (group_number, file_number)
           JOIN v$asm_diskgroup g
           USING (group_number))
     WHERE type IS NOT NULL
     START WITH (MOD(pindex, POWER(2, 24))) = 0
     CONNECT BY PRIOR rindex = pindex)
GROUP BY SUBSTR(alias_path,2,INSTR(alias_path,'/',1,2)-2), disk_group_name
ORDER BY 1,2

-- ASM Templates
SELECT dg.name gnam,
       t.entry_number en,
       t.redundancy re,
       t.stripe,
       DECODE(t.system,'Y','Yes','N','No') system,
       t.name
  FROM v$asm_template t,
       v$asm_diskgroup dg
 WHERE dg.group_number = t.group_number
 
 
 --
 --- Run in +ASM
 --
 
 -- ASM Connected Clients
  SELECT 
       dg.inst_id,
       dg.name disk_group,
       c.instance_name asm_instance,
       c.db_name db_name,
       status
  FROM gv$asm_diskgroup dg,
       gv$asm_client c
 WHERE dg.group_number = c.group_number
   AND dg.inst_id = c.inst_id
 ORDER BY c.instance_name,
       c.db_name, 
       c.group_number

-- Performance, can be run in database for disk groups used by the database only
SELECT   inst_id,group_number gn,writes,READS,write_time,
         bytes_written,write_time/writes avg_write_time,
         write_errs werrs
    FROM gv$asm_disk_iostat
ORDER BY 7 DESC

