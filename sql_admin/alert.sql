

select 
       ora_hash(originating_timestamp-to_date('1970-01-01','YYYY-MM-DD') || row_number() over (partition by originating_timestamp order by originating_timestamp)) as id,
       to_char(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') time_, 
       host_id, 
       decode(message_level, 1,'CRITICAL', 2,'SEVERE', 8,'IMPORTANT', 16,'NORMAL', message_level) message_level,
       decode(message_type,  1,'UNKNOWN', 2,'INCIDENT_ERROR', 3,'ERROR', 4,'WARNING', 5,'NOTIFICATION', 6,'TRACE', message_type) message_type,
       message_group, message_text
from sys.x$dbgalertext
where message_level <> 16
and originating_timestamp > SYSDATE-186
UNION ALL
select 1,to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS'),'dummy_row','GENEOS','GENEOS','GENEOS','GENEOS'
from dual 
order by 1
