#!/bin/sh
ADMIN_PASS="CHANGE_ME_ADMIN_PASS"
if ! echo "$QUERY_STRING" | grep -q "pass=$ADMIN_PASS"; then
    echo "Content-type: application/json"
    echo ""
    echo '{"error":"unauthorized"}'
    exit 0
fi
echo "Content-type: application/json"
echo ""
vnstat --json
