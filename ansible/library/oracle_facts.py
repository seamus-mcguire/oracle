#!/usr/bin/python
# -*- coding: utf-8 -*-

import datetime
import os

DOCUMENTATION = '''
---
module: oracle_facts
version_added: devel
short_description: gather facts about oracle dbs
description:
   - Gather facts about all oracle databases supplied in the list passed to the
     module. databases that are open, this module will also query each database for some
     additional basic facts.
options: 
  db_list:
    description:
      - Group Var "databases" list in format:
         - {name: DB_NAME1, oracle_home: /u01/sq/ora_1/db/12.1.0.2,      type: rac}
         - {name: DB_NAME2, oracle_home: /u01/sq/ora_1/db/12.1.0.2,      type: rac}
    required: true
    default: null
'''

EXAMPLES = '''
# Gather facts for 'dbserver'
ansible dbserver -m oracle_facts -a "db_list={{ databases }}"
'''

def oraenv(module, dbsid, oracle_home):
    os.environ['ORACLE_HOME']=oracle_home
    os.environ['LD_LIBRARY_PATH']="%s/lib" % oracle_home
    # Use bespoke Oraenv to set SID, needed for RAC DBs
    orasid = module.run_command("source ~/.profile_jobs; source oraenv %s ; echo $ORACLE_SID" % (dbsid), use_unsafe_shell=True)

    dbsid = orasid[1].rstrip("\r\n")
    os.environ['ORACLE_SID']=dbsid

    return dbsid

def run_sql(module, sid, oracle_home, sql):
    input ="whenever sqlerror exit failure; \n whenever oserror exit failure; \n"
    input+="set pagesize 0; \n set feedback off; \n"
    input+="connect / as sysdba \n"
    input+="%s \n\n"
    input+="exit \n"

    return module.run_command("%s/bin/sqlplus -S /nolog" % oracle_home, data=input % sql, check_rc=True)

def main():
    module = AnsibleModule(
      argument_spec = dict(
            db_list     = dict(type='list', required=True)
      ),
      supports_check_mode=True
    )

    facts = dict()
    dbs = module.params['db_list']
    for db in dbs:
      if db['type'] in ['std','rac']:
        db_name = db['name']
        oracle_home = db['oracle_home']
        dbsid = oraenv(module,db_name,oracle_home)

        rc, out, err = run_sql(module,dbsid,oracle_home,
         """select
                   name as db_name,
                   db_unique_name,
                   (select version from v$instance) version,
                   database_role,
                   replace(open_mode, ' ', '_') open_mode,
                   log_mode,
                   flashback_on,
                   replace(protection_mode, ' ', '_') protection_mode,
                   replace(protection_level, ' ', '_') protection_level,
                   replace(switchover_status, ' ', '_') switchover_status,
                   replace(dataguard_broker, ' ', '_') dataguard_broker,
                   force_logging
            from v$database;   """)
        fact = out.split()
        facts[db_name] = dict(
              db_name           =  fact[0].strip(),
              db_unique_name    =  fact[1].strip(),
              version           =  fact[2].strip(),
              database_role     =  fact[3].strip(),
              open_mode         =  fact[4].strip(),
              log_mode          =  fact[5].strip(),
              flashback_on      =  fact[6].strip(),
              protection_mode   =  fact[7].strip(),
              protection_level  =  fact[8].strip(),
              switchover_status =  fact[9].strip(),
              dataguard_broker  =  fact[10].strip(),
              force_logging     =  fact[11].strip()
            )

    module.exit_json(
       ansible_facts = dict(
         db_facts = facts
        ),
        changed   = False
    )

from ansible.module_utils.basic import *
main()

