#!/bin/bash

this_dir=$(dirname $0)

metrics() {

sqlplus -S /nolog <<EOF

set echo off
set pause off
set feedback off
set pagesize 0
set heading off
set line 500

connect / as sysdba

@@${this_dir}/sql_avg.sql
@@${this_dir}/sql_duration.sql

exit
EOF

}

{% for item in databases %}
{% if item.telegraf_db is defined and item.telegraf_db %}
. "oraenv" "{{ item.name }}"
metrics

{% endif %}
{% endfor %}


