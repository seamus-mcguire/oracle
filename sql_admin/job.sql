
-- Run all jobs
begin
for i in (select job
          from dba_jobs)

loop
  sys.dbms_ijob.run(i.job);
  commit;
end loop;
end;

-- Submit a job
DECLARE
  v_job_id                       BINARY_INTEGER;
BEGIN
  dbms_job.submit(what => 'BEGIN NULL; END;',
                  next_date => SYSDATE, 
                  interval => '(NEXT_DAY(TRUNC(SYSDATE), ''SUNDAY'')) + 16/24',
                  job => v_job_id);
END;
/
COMMIT;


-- Running Job Details
select j.job, j.what, s.sid, s.program, s.event, s.seconds_in_wait 
from dba_jobs j, dba_jobs_running jr, v$session s
where j.job = jr.job
  and jr.sid = s.sid
  
  