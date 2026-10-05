#!/bin/sh
echo "Content-Type: text/plain; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo ""
CHATFILE="/www/watch_chat.txt"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1517393659773980712/WKwgT5Wsplr8D0sapc1d58KSnropdq30g0hWhsoNT9tOkx8FKlX_5rSLf1SSOwPM1aQB"
touch "$CHATFILE"
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')
if [ "$ACTION" = "send" ]; then
  MSG=$(echo "$QUERY_STRING" | sed -n 's/.*msg=\([^&]*\).*/\1/p' | sed 's/+/ /g' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
  NAME=$(echo "$QUERY_STRING" | sed -n 's/.*name=\([^&]*\).*/\1/p' | sed 's/+/ /g' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
  CLIENT_IP="$REMOTE_ADDR"
  MAC=$(ip neigh show | grep "$CLIENT_IP" | awk '{print $5}' | head -1)
  [ -z "$MAC" ] && MAC="--:--:--:--"
  SHORT_MAC=$(echo "$MAC" | awk -F: '{print $(NF-1)":"$NF}')
  TIME=$(date +"%I:%M %p")
  echo "[$TIME] $NAME [$SHORT_MAC]: $MSG" >> "$CHATFILE"
  tail -30 "$CHATFILE" > "$CHATFILE.tmp" && mv "$CHATFILE.tmp" "$CHATFILE"
  DISCORD_MSG=$(printf '%s' "[$SHORT_MAC] $NAME: $MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
  curl -s -X POST -H "Content-Type: application/json" -d "{\"content\":\"$DISCORD_MSG\"}" "$DISCORD_WEBHOOK" > /dev/null 2>&1
  echo "sent"
else
  tail -15 "$CHATFILE"
fi
