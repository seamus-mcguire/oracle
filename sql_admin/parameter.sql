
-- view hidden params
col KSPPSTVL format a30
col KSPPSTVL format a30
select 
  ksppinm,
  ksppstvl 
from 
  x$ksppi a, 
  x$ksppsv b 
where 
  a.indx=b.indx and 
  substr(ksppinm,1,1) = '_'
  and ksppinm = '_fix_control';
  