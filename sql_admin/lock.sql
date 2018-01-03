

-- Who's blocking
select (select username from gv$session where sid=blocker.sid and inst_id = blocker.inst_id) blocker,
        blocker.sid,
        sblocker.serial#,
        blocker.inst_id,
        sblocker.program,
        sblocker.osuser,
       ' is blocking ',
       (select username from gv$session where sid=blockee.sid and inst_id = blockee.inst_id) blockee,
       sblockee.last_call_et seconds_blocked,
       blockee.sid,
       sblockee.serial#,
       blockee.inst_id,
       sblockee.program,
       sblockee.osuser,
       o.owner table_owner,
       o.object_name table_name,
       SUBSTR(sql.sql_text, 1, 128) as blocked_sql 
from gv$lock blocker, gv$lock blockee, gv$locked_object lo, dba_objects o, 
     gv$session sblocker,gv$session sblockee, gv$sql sql
where blocker.id1 = blockee.id1
  and blocker.id2 = blockee.id2
  AND blocker.sid = lo.session_id (+)
  and blocker.inst_id = lo.inst_id (+)
  AND lo.object_id = o.object_id (+)
  and blocker.block > 0
  and blockee.request > 0
  and blocker.sid = sblocker.sid
  and blocker.inst_id = sblocker.inst_id
  and blockee.sid = sblockee.sid
  and blockee.inst_id = sblockee.inst_id
  and sblocker.username is not null
  and sblockee.inst_id = sql.inst_id (+)
  and sblockee.SQL_ADDRESS = sql.ADDRESS (+)
  and sblockee.SQL_HASH_VALUE = sql.HASH_VALUE (+)
  and sblockee.SQL_CHILD_NUMBER = sql.CHILD_NUMBER (+)
  and sblockee.username = 

REM
REM Program      : Show blocker and waiting sessions
REM Author       : Lee Payne.    Date : 21 May 2002
REM              : Add in instance details and use gv$ for RAC 28/05/2008
REM
SELECT   a.instance_name A,
         DECODE(l.request,0,'Holder: ','Waiter: ')||l.sid B, 
	 ob.owner||'.'||ob.object_name C,
--         l.id1||','||l.id2 D, 
	 decode(l.lmode,
	        0,'none',
                1,'null(NULL)',
	        2,'row-S(SS)',
		3,'row-X(SX)',
		4,'share(S)',
	        5,'S/Row-X(SSX)',
                6,'exclusive(X)',
		l.lmode) E,
	 decode(l.request,
	        0,'none',
                1,'null(NULL)',
	        2,'row-S(SS)',
		3,'row-X(SX)',
		4,'share(S)',
	        5,'S/Row-X(SSX)',
                6,'exclusive(X)',
		l.request) F,
	 decode(l.type,
	        'TM','DML enqueue(TM)',
		'TX','Transaction enqueue(TX)',
		'UL','User supplied(UL)',
		l.type) G
FROM gV$LOCK l,
     gv$instance a,
     gv$locked_object lo,
     dba_objects ob
WHERE (l.id1, l.id2, l.type) IN
      (SELECT id1, id2, type FROM gV$LOCK WHERE request>0)
AND a.inst_id=l.inst_id
AND l.sid = lo.session_id (+)
AND lo.object_id = ob.object_id (+)
ORDER BY id1, request;


-- Pins and more
select /*+ ordered */
        w1.inst_id waiting_inst_id,
        w1.sid  waiting_session,
        w1.program  waiting_program,
        h1.inst_id holding_inst_id,
        h1.sid  holding_session,
        h1.program  holding_program,
        h1.serial#  holding_serial#,
        w.kgllktype lock_or_pin,
        w.kgllkhdl address,
        decode(h.kgllkmod,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive',
           'Unknown') mode_held,
        decode(w.kgllkreq,  0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive',
           'Unknown') mode_requested
  from dba_kgllock w, dba_kgllock h, gv$session w1, gv$session h1
 where
  (((h.kgllkmod != 0) and (h.kgllkmod != 1)
     and ((h.kgllkreq = 0) or (h.kgllkreq = 1)))
   and
     (((w.kgllkmod = 0) or (w.kgllkmod= 1))
     and ((w.kgllkreq != 0) and (w.kgllkreq != 1))))
  and  w.kgllktype         =  h.kgllktype
  and  w.kgllkhdl         =  h.kgllkhdl
  and  w.kgllkuse     =   w1.saddr
  and  h.kgllkuse     =   h1.saddr

  
-- Sessions with locks
select *
from gv$lock l, gv$locked_object lo
where l.SID = lo.SESSION_ID
and l.inst_id = lo.inst_id


-- Transctions and locked objects
SELECT DISTINCT
       t.start_time,
       s.inst_id,
       s.sid,
       s.username,
       s.osuser,
       s.machine,
       s.program,
       o.object_name,
       o.object_type
FROM gv$transaction t, gv$session s, gv$lock l, gv$locked_object lo, dba_objects o
WHERE t.addr = s.taddr
  and t.inst_id = s.inst_id
  and s.sid = l.sid
  and s.inst_id = l.inst_id
  and l.SID = lo.SESSION_ID (+)
  and l.inst_id = lo.inst_id (+)
  and o.object_id (+) = lo.object_id 
order by t.start_time


-- Who is executing what procedures
select
  decode(o.kglobtyp,
    7, 'PROCEDURE',
    8, 'FUNCTION',
    9, 'PACKAGE',
    12, 'TRIGGER',
    13, 'CLASS'
  )  "TYPE",
  o.kglnaown  "OWNER",
  o.kglnaobj  "NAME",
  s.indx  "SID",
  s.ksuseser  "SERIAL",
  s.ksuudnam "USERNAME",
  s.ksuseapp "PROGRAM",
  x.app "MODULE",
  x.act "ACTION",
  x.clinfo "CLIENT_INFO"
from
  sys.x$kglob  o,
  sys.x$kglpn  p,
  sys.x$ksuse  s,
  sys.x$ksusex x
where
  o.inst_id = userenv('Instance') and
  p.inst_id = userenv('Instance') and
  s.inst_id = userenv('Instance') and
  x.inst_id = userenv('Instance') and
  p.kglpnhdl = o.kglhdadr and
  s.addr = p.kglpnses and
  s.indx = x.sid and
  s.ksuseser = x.serial and
  o.kglhdpmd = 2 and
  o.kglobtyp in (7, 8, 9, 12, 13)
order by 1,2,3


--  TX Locks only (Transaction Enqueue)
SELECT
       t.start_time,
       s.sid, s.username, s.osuser, s.machine, s.program,
       te.type, te.lmode, te.request, te.block
FROM gv$session s, gv$transaction t, gV$TRANSACTION_ENQUEUE te
WHERE t.addr = s.taddr
  AND t.addr = te.addr (+)


-- Locked Object Details
SELECT
      s.sid, s.program, s.machine,
      s.blocking_session, s.event, s.seconds_in_wait,
      l.type, l.lmode, l.request, l.block, lo.oracle_username, o.object_name, o.object_type
FROM gv$session s, gv$lock l, gv$locked_object lo, dba_objects o
WHERE s.sid = l.sid
  AND l.sid = lo.session_id
  AND lo.object_id = o.object_id


-- Object and Row being locked
SELECT
       do.owner, do.object_name,
       dbms_rowid.rowid_create ( 1, s.row_wait_obj#, s.row_wait_file#, s.row_wait_block#, s.row_wait_row# ) as rowid_,
       s.row_wait_obj#, s.row_wait_file#, s.row_wait_block#, s.row_wait_row#
FROM gv$session s, dba_objects do
WHERE s.row_wait_obj# = do.object_id


-- Lock types
select   OS_USER_NAME os_user,
            PROCESS os_pid,
            ORACLE_USERNAME oracle_user,
            l.SID oracle_id,
            decode(TYPE,
                        'MR', 'Media Recovery',
                        'RT', 'Redo Thread',
                        'UN', 'User Name',
                        'TX', 'Transaction',
                        'TM', 'DML',
                        'UL', 'PL/SQL User Lock',
                        'DX', 'Distributed Xaction',
                        'CF', 'Control File',
                        'IS', 'Instance State',
                        'FS', 'File Set',
                        'IR', 'Instance Recovery',
                        'ST', 'Disk Space Transaction',
                        'TS', 'Temp Segment',
                        'IV', 'Library Cache Invalidation',
                        'LS', 'Log Start or Switch',
                        'RW', 'Row Wait',
                        'SQ', 'Sequence Number',
                        'TE', 'Extend Table',
                        'TT', 'Temp Table', type) lock_type,
            decode(LMODE,
                        0, 'None',
                        1, 'Null',
                        2, 'Row-S (SS)',
                        3, 'Row-X (SX)',
                        4, 'Share',
                        5, 'S/Row-X (SSX)',
                        6, 'Exclusive', lmode) lock_held,
            decode(REQUEST,
                        0, 'None',
                        1, 'Null',
                        2, 'Row-S (SS)',
                        3, 'Row-X (SX)',
                        4, 'Share',
                        5, 'S/Row-X (SSX)',
                        6, 'Exclusive', request) lock_requested,
            decode(BLOCK,
                        0, 'Not Blocking',
                        1, 'Blocking',
                        2, 'Global', block) status,
            OWNER,
            OBJECT_NAME
from      v$locked_object lo,
            dba_objects do,
            v$lock l
where    lo.OBJECT_ID = do.OBJECT_ID
AND     l.SID = lo.SESSION_ID
