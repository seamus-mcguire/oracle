

-- Who is using Temp
SELECT s.inst_id, s.sid, s.username, u.tablespace, s.sql_hash_value||'/'||u.sqlhash hash_value, u.segtype, u.contents, u.blocks, s.status, s.program
FROM gv$session s, gv$tempseg_usage u
WHERE s.saddr=u.session_addr
and s.inst_id = u.inst_id
order by u.blocks;

-- who is using Temp 2
select s.sid || ',' || s.serial# sid,s.username,u.tablespace,substr(a.sql_text, 1, (instr(a.sql_text, ' ')-1)) sql_text,
round(((u.blocks*p.value)/1024/1024),2) size_mb
from v$sort_usage u, v$session s, v$sqlarea a,v$parameter p 
where s.saddr = u.session_addr and a.address (+) = s.sql_address 
and a.hash_value (+) = s.sql_hash_value and p.name = 'db_block_size' 
group by s.sid || ',' || s.serial#, s.username,substr(a.sql_text, 1, (instr(a.sql_text, ' ')-1)),u.tablespace,round(((u.blocks*p.value)/1024/1024),2)

-- who is using Temp 3
SELECT sysdate "TIME_STAMP", vsu.username, vsu.sql_id, vsu.tablespace,
   vsu.usage_mb, vst.sql_text, vp.spid
           FROM
           (
                   SELECT username, sqladdr, sqlhash, sql_id, tablespace, session_addr,inst_id,
   sum(blocks)*8192/1024/1024 "USAGE_MB"
                   FROM gv$sort_usage
                 --  HAVING SUM(blocks)> 10000 -- 80MB
                   GROUP BY inst_id,username, sqladdr, sqlhash, sql_id, tablespace, session_addr
           ) "VSU",
           gv$sqltext vst,
           gv$session vs,
           gv$process vp
   WHERE vsu.sql_id = vst.sql_id
   and vsu.inst_id = vst.inst_id
   and vst.inst_id = vs.inst_id
   and vs.inst_id = vp.inst_id
           AND vsu.sqladdr = vst.address
           AND vsu.sqlhash = vst.hash_value
           AND vsu.session_addr = vs.saddr
           AND vs.paddr = vp.addr
           AND vst.piece = 0;
		   
-- Historical Temp Usage
-- not 100% coverage but better than nothing
select distinct sql_id, hash_value, temp_size_gb, sql_text
from (
select 
     s.sql_id, s.hash_value, s.child_number, total_executions, onepass_executions, multipasses_executions, max_tempseg_size,
     round(max_tempseg_size/1024/1024/1024) temp_size_gb
     ,s.sql_text
from 
     gv$sql_workarea sw, gv$sql s
where   1=1
and sw.inst_id = s.inst_id
and sw.sql_id = s.sql_id
and sw.hash_value = s.hash_value 
and sw.child_number = s.child_number 
and  total_executions != optimal_executions
--and max_tempseg_size is not null
)
where temp_size_gb  >= 1
order by temp_size_gb desc 

-- Extents ever allocated 
select tablespace_name, bytes_used/1024/1024/1024 used_gb, bytes_free/1024/1024/1024 free_gb
from v$temp_space_header

-- Sort Usage Sessions
SELECT a.inst_id, a.sid, a.username, a.osuser, a.program, b.tablespace, b.extents, b.blocks,  
      (b.blocks*t.block_size)/1024/1024 size_mb, b.segtype, c.sql_id, c.sql_text
FROM gv$session a, gv$tempseg_usage b, dba_tablespaces t, gv$sqlarea c
WHERE a.saddr = b.session_addr
  and a.inst_id = b.inst_id
  AND b.sql_id= c.sql_id (+)
  and b.inst_id = c.inst_id  (+)
  and t.tablespace_name = b.tablespace
ORDER BY a.inst_id, a.sid, b.tablespace, b.blocks desc

