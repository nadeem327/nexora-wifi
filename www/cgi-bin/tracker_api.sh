#!/bin/sh
echo "Content-type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
cat /tmp/device_tracker.json 2>/dev/null || echo "{}"
