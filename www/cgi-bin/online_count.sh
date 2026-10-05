#!/bin/sh
echo "Content-Type: text/plain"
echo "Access-Control-Allow-Origin: *"
echo ""
CACHE="/tmp/online_count_cache"
LOCK="/tmp/online_count.lock"
NOW=$(date +%s)
LAST=$(cat "$CACHE" 2>/dev/null | cut -d'|' -f1)
[ -z "$LAST" ] && LAST=0
AGE=$((NOW - LAST))
if [ -f "$CACHE" ] && [ "$AGE" -lt 10 ]; then
  cat "$CACHE" | cut -d'|' -f2
  exit 0
fi
(
flock -x 200 2>/dev/null
C=$(ip neigh show dev br-hotspot 2>/dev/null | grep -v fe80 | grep lladdr | grep -E 'REACHABLE|DELAY' | wc -l)
echo "$NOW|$C" > "$CACHE"
echo "$C"
) 200>"$LOCK"
