

-- Session mapped to OS Process
SELECT *
FROM gv$session s, gv$process p
WHERE s.paddr = p.addr
and s.inst_id = p.inst_id

-- Killed sessions OS PID
SELECT spid
FROM v$process
WHERE NOT EXISTS (SELECT 1
                  FROM v$session
                  WHERE paddr = addr);

-- Processes used
SELECT pr.inst_id,
       i.instance_name,
       i.host_name,
       COUNT(pr.pid) procs_used,
       pa.value-count(pr.pid) procs_left,
       ROUND(COUNT(pr.pid)/pa.value * 100) pct_used,
       pa.value procs_max
FROM gv$process pr, gv$parameter pa, gv$instance i
WHERE pr.inst_id = pa.inst_id
AND pr.inst_id = i.inst_id
AND pa.name = 'processes'
GROUP BY pr.inst_id, i.instance_name, i.host_name, pa.value
ORDER BY pr.inst_id

-- Session Statistics
select n.name, s.value
from gv$sesstat s, v$statname n
where 1=1
  and s.statistic# = n.STATISTIC#
  and sid = sys_context('userenv', 'sid')
  and inst_id = sys_context('userenv', 'instance')
order by upper(n.name)

-- Session inactivity
SELECT  
       s.sid, 
       p.spid os_process,
       s.username,status,
       TO_CHAR(logon_time,'YYYY-MM-DD HH24:MI:SS') logon_time,
       FLOOR(last_call_et/3600)||':'|| FLOOR(MOD(last_call_et,3600)/60)||':'|| MOD(MOD(last_call_et,3600),60) last_call,
       s.program
FROM gv$session s, gv$process p
WHERE s.paddr = p.addr
and p.spid  = 

-- LongOps
select sid, serial#, target, opname, sofar/totalwork*100 pct, sofar, totalwork, last_update_time
from v$session_longops--@qsgdtd50
where trunc(last_update_time) >= trunc(sysdate)
Order by last_update_time Desc
