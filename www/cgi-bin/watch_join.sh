#!/bin/sh
echo "Content-Type: text/plain"
echo "Access-Control-Allow-Origin: *"
echo ""

FLAGDIR="/tmp/watch_viewers"
mkdir -p "$FLAGDIR"
CLIENT="$REMOTE_ADDR"

# Agar user leave kar raha hai
if echo "$QUERY_STRING" | grep -q "action=leave"; then
  rm -f "$FLAGDIR/$CLIENT"
else
  # Agar naya user hai aur pehle se 2 log hain, toh block karein
  COUNT=$(ls "$FLAGDIR" 2>/dev/null | wc -l)
  if [ ! -f "$FLAGDIR/$CLIENT" ] && [ "$COUNT" -ge 2 ]; then
    echo "FULL"
    exit 0
  fi
  # Agar jagah hai ya purana user hi ping kar raha hai
  touch "$FLAGDIR/$CLIENT"
fi

# 10 seconds se purani files ko saaf karein
NOW=$(date +%s)
for f in "$FLAGDIR"/*; do
  [ -f "$f" ] && [ $((NOW - $(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f"))) -gt 15 ] && rm -f "$f"
done

# Active viewers ka total count print karein
ls "$FLAGDIR" 2>/dev/null | wc -l
