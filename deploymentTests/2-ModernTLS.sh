#!/usr/bin/env bash

TARGET='invoicer-api.3pjw7ca4hi.us-east-1.elasticbeanstalk.com'
TARGET_LEVEL='modern'

resp="$(curl -s -X POST "https://tls-observatory.services.mozilla.com/api/v1/scan?target=$TARGET")"
[ $? -gt 0 ] && echo $resp && exit $?

id="$(echo $resp | jq -r '.scan_id')"
[ $? -gt 0 ] && echo $resp && exit $?
[ "$id" -lt 1 ] && echo "Failed to scan target" && exit 10

while true; do
    resp="$(curl -s https://tls-observatory.services.mozilla.com/api/v1/results?id=$id)"

    # check that the scan finished or wait and retry
    compl="$(echo $resp | jq -r '.completion_perc')"
    [ $? -gt 0 ] && echo $resp && exit $?
    [ "$compl" != '100' ] && sleep 3 && continue

    # check target supports TLS at all
    has_tls="$(echo $resp | jq -r '.has_tls')"
    [ $? -gt 0 ] && echo $resp && exit $?
    [ "$has_tls" != 'true' ] && echo "Endpoint is not TLS enabled" && exit 100

    # check TLS configuration is modern
    level="$(echo $resp | jq -r -c '.analysis[] | select(.analyzer | contains("mozillaEvaluationWorker")) | .result.level')"
    [ $? -gt 0 ] && echo $resp && exit $?
    [ "$level" != "$TARGET_LEVEL" ] && echo "Endpoint has $level TLS, which isn't $TARGET_LEVEL" && exit 200
    exit 0
done
