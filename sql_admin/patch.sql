
-- DB Version with PSU, works > 12.1.0.2
SELECT NVL(  
  (SELECT version FROM  
    (SELECT version || '.' || bundle_id version  
    FROM dba_registry_sqlpatch  
    WHERE BUNDLE_SERIES = 'PSU'  
    ORDER BY ACTION_TIME DESC) WHERE rownum = 1),  
  (SELECT version FROM v$instance)) version  
FROM dual
