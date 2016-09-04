#!/bin/bash
grants="$(psql -U deployer \
        -h invoicer201605211320.czvvrkdqhklf.us-east-1.rds.amazonaws.com -p 5432 \
        invoicer -c '
COPY ( 
    SELECT oid::regclass, acl.privilege_type
    FROM pg_class, aclexplode(relacl) AS acl
    WHERE relacl IS NOT null AND acl.grantee=16431
) TO STDOUT WITH CSV ')"

EXPECTEDGRANTS=(
    'invoices_id_seq,USAGE'
    'charges_id_seq,USAGE'
    'invoices,INSERT'
    'invoices,SELECT'
    'charges,INSERT'
    'charges,SELECT'
    'sessions,INSERT'
    'sessions,SELECT'
    'sessions,UPDATE'
    'sessions,DELETE'
)

for grant in $grants; do
    expected=0
    for egrant in ${EXPECTEDGRANTS[@]}; do
        if [ "$grant" == "$egrant" ]; then
            expected=1
        fi
    done
    if [ "$expected" -eq 0 ]; then
        echo "Grant '$grant' was not expected"
        exit 1
    fi
done
exit 0
