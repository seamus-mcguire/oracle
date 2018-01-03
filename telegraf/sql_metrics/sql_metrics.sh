#!/bin/env bash

sqlplus -S /nolog <<'EOF'
        set echo off
        set pause off
        set feedback off
        set pagesize 0
        set heading off
set line 500
	connect / as sysdba

@@sql_avg.sql
@@sql_duration.sql

exit
EOF


