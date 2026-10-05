#!/bin/sh

# Device tracker - har device ka last seen time store karta hai
TRACKER_FILE="/tmp/device_tracker.json"

# Agar file nahi hai toh empty JSON banao
if [ ! -f "$TRACKER_FILE" ]; then
    echo "{}" > "$TRACKER_FILE"
fi

# Current timestamp (seconds since epoch)
CURRENT_TIME=$(date +%s)

# API se devices fetch karo
curl -s "http://127.0.0.1/cgi-bin/signal_api.sh?t=$CURRENT_TIME" > /tmp/current_devices.json 2>/dev/null

# Python se tracker update karo
python3 << 'PYEOF'
import json
import os
import sys

tracker_file = "/tmp/device_tracker.json"
current_time = int(os.popen('date +%s').read().strip())

# Load existing tracker
try:
    with open(tracker_file, 'r') as f:
        tracker = json.load(f)
except:
    tracker = {}

# Load current devices
try:
    with open("/tmp/current_devices.json", 'r') as f:
        data = json.load(f)
        devices = data.get("devices", [])
except:
    devices = []

# Update tracker for each device
for device in devices:
    mac = device.get("mac", "").lower()
    status = device.get("status", "")
    online = device.get("online", False)
    
    if not mac:
        continue
    
    if mac not in tracker:
        tracker[mac] = {
            "first_seen": current_time,
            "last_online": None,
            "last_seen": current_time,
            "status_history": []
        }
    
    # Always update last_seen
    tracker[mac]["last_seen"] = current_time
    
    # Update last_online if device is online/reachable
    if online == True or online == "true" or status == "REACHABLE":
        tracker[mac]["last_online"] = current_time
    
    # Add status history (keep last 10)
    tracker[mac]["status_history"].append({
        "status": status,
        "time": current_time
    })
    tracker[mac]["status_history"] = tracker[mac]["status_history"][-10:]

# Save tracker
with open(tracker_file, 'w') as f:
    json.dump(tracker, f, indent=2)

print("Tracker updated successfully")
PYEOF

# Output current tracker
cat "$TRACKER_FILE"
