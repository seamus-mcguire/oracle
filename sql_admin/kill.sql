

select  'alter system kill session ''' || sid || ', '||serial#||''';'
select 'alter system kill session '||''''||sid||','||serial#||','||'@'||INST_ID||''''||' immediate ;'
from v$session
where username = ?

SELECT sid, serial#, username
 FROM v$session
where sid=93 ;


-- SID, SERIAL#
ALTER SYSTEM KILL SESSION '93, 6425';


/***************************************************************
  Stored proc to be used by under privileged users
 ***************************************************************/

CREATE OR REPLACE PROCEDURE kill_session (
  p_sid                             NUMBER,
  p_serial                          NUMBER) AS
 
  v_user                             VARCHAR2(30);
  
BEGIN

  SELECT username 
  INTO v_user 
  FROM v$session 
  WHERE sid = p_sid 
   AND serial# = p_serial;
 
  IF v_user = USER then
    EXECUTE IMMEDIATE 
     'ALTER SYSTEM KILL SESSION ''' || p_sid || ',' || p_serial || '''';
  ELSE
    raise_application_error(-20000,'Invalid session user ''' || v_user || '''.' || CHR(10) ||
                           'You must be logged in as the same account your are attempting to kill.');
  END IF;

EXCEPTION
  WHEN no_data_found THEN
   raise_application_error(-20001,'Sid,Serial# not found in v$session - '|| p_sid || ',' || p_serial);
END;
/ 

GRANT EXECUTE ON kill_session to schema_owner;
CREATE PUBLIC SYNONYM kill_session for kill_session;

