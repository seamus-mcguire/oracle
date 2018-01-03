#!/usr/bin/python
# -*- coding: utf-8 -*-
# 
# Not every option has been test
#  
import os
import datetime

DOCUMENTATION = '''
---
module: oracle_sql
version_added: devel
short_description: execute SQL on an oracle database
description:
   - Launch sqlplus session on remote machine and send arbitrary
     SQL text into stdin. Output can be captured in the register
     or spooled to a file. Before launching sqlplus, the module 
     will attempt to setup the environment. If an oracle_home is 
     not supplied then it will try to detect the home by looking 
     for oratab. The only environment setup will be PATH and 
     LD_LIBRARY_PATH (no ORACLE_BASE or SQLPATH or TNSADMIN). The 
     module will use OS authentication by default if a user and 
     password is not supplied.
options: 
  sql:
    description:
      - SQL to pass into sqlplus
    required: true
    default: null
  sid: 
    description:
      - SID or DB Name of the oracle instance to run SQL
    required: true
    default: null
  oracle_home:
    description:
      - ORACLE_HOME of oracle instance. If this is not supplied
        then it will be auto-detected from oratab.
    required: false
    default: null
  connect:
    description:
      - Connect string (user/password [as sysdba]). Sqlplus is
        launched with /nolog then connect command is issued with
        this text as the parameter.
      - not tested
    required: false
    default: / as sysdba
  spool:
    description:
      - File on remote server which sqlplus output gets spooled
        into. Note that this string is appended to the sqlplus
        spool command so it also accepts "create/replace/append".
      - not tested
    required: false
    default: off
  verbose:
    description:
      - Verbose output (doesn't clear linesize and feedback in
        sqlplus)
    required: false
    default: false
'''

EXAMPLES = '''
# Show active sessions for instance RAC1 on 'dbserver'
ansible dbserver -U oracle -m oracle_sql -a "sid=RAC1 sql=\"select sid,username,sql_id,event from v\$session where status='ACTIVE';\""
'''

def main():
    module = AnsibleModule(
        argument_spec = dict(
            sql         = dict(required=True),
            sid         = dict(required=True),
            oracle_home = dict(required=False),
            spool       = dict(required=False,default="off"),
            verbose     = dict(type='bool',required=False,default=False),
            connect     = dict(required=False,default="/ as sysdba")
        ),
    )

    oracle_home = module.params['oracle_home']
    sid = module.params['sid']

    if os.path.exists("/etc/oratab"):
      oratab="/etc/oratab"
    else:
      if os.path.exists("/var/opt/oracle/oratab"):
        oratab="/var/opt/oracle/oratab"
      else:
        module.fail_json(msg="Could not find oratab in /etc or /var/opt/oracle")

    if oracle_home is None:
      for line in open(oratab,'r'):
        items = line.split(":")
        if items[0].lower() == sid.lower():
          oracle_home=items[1]

    if oracle_home is None:
      module.fail_json(msg="Could not find oracle_home for sid %s in %s" % (sid,oratab))

    if not os.path.exists(oracle_home):
      module.fail_json(msg="oracle_home %s does not exist" % oracle_home)

    if module.params['verbose']:
      sqlplus_flags=""
      verbose=""
    else:
      sqlplus_flags="-S"
      verbose="set pagesize 0 feedback off;"

    os.environ['ORACLE_HOME']=oracle_home
    os.environ['LD_LIBRARY_PATH']="%s/lib" % oracle_home

    # Use Bespoke Oraenv to set SID, needed for RAC DBs
    orasid = module.run_command("source ~/.profile_jobs; source oraenv %s ; echo $ORACLE_SID" % (sid), use_unsafe_shell=True)
    
    os.environ['ORACLE_SID']=orasid[1].rstrip("\r\n")

    input ="whenever sqlerror exit failure; \n whenever oserror exit failure; \n set echo off; \n"
    #input ="whenever sqlerror continue; \n whenever oserror exit failure; \n set echo off; \n"
    input+="%s \n" % verbose
    input+="connect %s \n" % module.params['connect']
    #input+="spool %s \n" % module.params['spool']
    input+="%s \n\n" % module.params['sql']
    input+="exit; \n"

    ### Run the SQL
    startd = datetime.datetime.now()
    rc, out, err = module.run_command("%s/bin/sqlplus %s /nolog" % (oracle_home,sqlplus_flags), data=input, check_rc=True)
    endd = datetime.datetime.now()
    delta = endd - startd

    if out is None:
        out = ''
    if err is None:
        err = ''

    module.exit_json(
        input       = input,
        stdout      = sid + '- ' + out.rstrip("\r\n"),
        stderr      = err.rstrip("\r\n"),
        rc          = rc,
        start       = str(startd),
        end         = str(endd),
        delta       = str(delta),
        changed     = True
    )

from ansible.module_utils.basic import *
main()

