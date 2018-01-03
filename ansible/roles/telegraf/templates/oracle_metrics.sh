#!/bin/bash

# If TZ is not set there is weird behaviour with oracle datas and oracle_load
# does not work does not happen in 11.2.0.3 but does in 11.2.0.4 and 12.1.0.2
export TZ="{{ telegraf_tz }}"


this_dir=$(dirname $0)

metrics() {

sqlplus -S /nolog <<EOF
connect / as sysdba

@@${this_dir}/oracle_metrics.sql

exit
EOF

}

{% for item in databases %}
{% if item.telegraf_db is defined and item.telegraf_db %}
. "oraenv" "{{ item.name }}"
metrics

{% endif %}
{% endfor %}

