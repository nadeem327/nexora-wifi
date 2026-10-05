#!/bin/sh
echo "Content-type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Cache-Control: no-cache, no-store, must-revalidate"
echo ""

# Load tracker data
TRACKER_FILE="/tmp/device_tracker.json"
if [ -f "$TRACKER_FILE" ]; then
    TRACKER_DATA=$(cat "$TRACKER_FILE")
else
    TRACKER_DATA="{}"
fi

# Get current server time
SERVER_TIME=$(date +%s)

# Original signal_api.sh ka output lo aur tracker data add karo
cat << JSON
{
  "server_time": $SERVER_TIME,
  "tracker": $TRACKER_DATA,
  "devices": [
JSON

# Ab original signal_api.sh ka logic yahan paste karo
# Ya phir original signal_api.sh call karo aur modify karo

