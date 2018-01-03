#!/bin/env bash

metrics() {

sqlplus -S /nolog <<'EOF'
connect / as sysdba

@@oracle_metrics.sql

exit
EOF

}

. oraenv ${DB_NAME}
metrics

