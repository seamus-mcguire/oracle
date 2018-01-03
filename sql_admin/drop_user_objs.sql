
BEGIN

   FOR c_drop IN (SELECT owner, object_name, object_type
                  FROM dba_objects
                  WHERE owner = 'CHANGE_THIS HERE'
                    AND object_type IN ('CLUSTER', 'DIMENSION', 
'FUNCTION', 'MATERIALIZED VIEW', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 
'SEQUENCE', 'SYNONYM', 'TABLE', 'TYPE', 'VIEW')
                    AND object_name NOT IN (SELECT name
                                            FROM user_snapshots)
                  ORDER BY DECODE(object_type,
                                              'FUNCTION', 1,
                                              'PROCEDURE', 2,
                                              'PACKAGE BODY', 3,
                                              'PACKAGE', 4,
                                              'SYNONYM', 5,
                                              'VIEW', 6,
                                              'MATERIALIZED VIEW',7,
                                              'SEQUENCE',8,
                                              'CLUSTER', 9,
                                              'DIMENSION',10,
                                              'TABLE', 11,
                                              'TYPE', 12)
                 )
    LOOP

      IF c_drop.object_type = 'TABLE' THEN

        IF UPPER(c_drop.object_name) NOT LIKE 'RUPD$_%' OR 
UPPER(c_drop.object_name) NOT LIKE 'MLOG$_%' THEN

          --dbms_output.put_line (
          begin
          EXECUTE IMMEDIATE
          'DROP ' || c_drop.object_type || ' ' || c_drop.owner || '."' 
|| c_drop.object_name || '"'  ||
             ' CASCADE CONSTRAINTS';
          exception
           when others then
             dbms_output.put_line(SQLERRM);
          end;
        END IF;
      ELSE
        begin
                 --dbms_output.put_line (
        EXECUTE IMMEDIATE
        'DROP ' || c_drop.object_type || ' '  || c_drop.owner || '."' || 
c_drop.object_name || '"';
        exception
         when others then
           dbms_output.put_line(SQLERRM);
        end;
      END IF;

    END LOOP;

END;
/
