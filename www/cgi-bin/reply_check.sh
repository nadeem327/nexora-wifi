#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
FILE="/etc/nodogsplash/admin_replies.txt"
QMAC=$(printf '%s' "$QUERY_STRING" | sed -n 's/.*mac=\([^&]*\).*/\1/p' | tr 'A-F' 'a-f')
NOW=$(date +%s)
CUTOFF=$((NOW - 7200))   # replies 2 ghante valid
LATEST=""
if [ -f "$FILE" ] && [ -n "$QMAC" ]; then
  # 1) MAC wala reply
  LATEST=$(grep "|$QMAC|" "$FILE" 2>/dev/null | tail -1)
  # 2) Agar nahi to broadcast (jiska target broadcast ho)
  [ -z "$LATEST" ] && LATEST=$(grep "|broadcast|" "$FILE" 2>/dev/null | tail -1)
fi
if [ -n "$LATEST" ]; then
  TS=$(printf '%s' "$LATEST" | cut -d'|' -f1)
  TXT=$(printf '%s' "$LATEST" | cut -d'|' -f3)
  [ "$TS" -ge "$CUTOFF" ] && { printf '{"ok":1,"msg":"%s"}\n' "$(printf '%s' "$TXT" | sed 's/"/\\"/g')"; exit 0; }
fi
echo '{"ok":0}'
