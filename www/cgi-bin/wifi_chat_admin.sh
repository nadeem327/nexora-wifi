#!/bin/sh
echo "Content-Type: text/plain; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo ""

CHATFILE="/www/wifi_chat.txt"
ADMIN_PASS="CHANGE_ME_ADMIN_PASS"

touch "$CHATFILE"

PASS=$(echo "$QUERY_STRING" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

if [ "$PASS" != "$ADMIN_PASS" ]; then
  echo "DENIED"
  exit 0
fi

case "$ACTION" in
  load)
    tail -60 "$CHATFILE"
    ;;
  reply)
    RAWMSG=$(echo "$QUERY_STRING" | sed -n 's/.*msg=\([^&]*\).*/\1/p')
    MSG=$(printf '%s' "$RAWMSG" | sed 's/+/ /g' | python3 -c "import sys,urllib.parse
s=urllib.parse.unquote(sys.stdin.read().strip())
for c in ['|','\n','\r']: s=s.replace(c,' ')
print(s[:200])")
    [ -z "$MSG" ] && { echo "empty"; exit 0; }
    TIME=$(date +"%I:%M %p")
    (
      flock -x 200 2>/dev/null
      echo "[$TIME] Nexora WiFi Admin [ADMIN]: $MSG" >> "$CHATFILE"
      tail -50 "$CHATFILE" > "$CHATFILE.tmp" && mv "$CHATFILE.tmp" "$CHATFILE"
      SEQ=$(($(cat /tmp/wifi_chat_seq 2>/dev/null || echo 0)+1)); echo "$SEQ" > /tmp/wifi_chat_seq; echo "$SEQ" > /tmp/wifi_chat_admin_seq
    ) 200>/tmp/wifi_chat.lock
    echo "sent"
    ;;
  clear)
    : > "$CHATFILE"
    echo 0 > /tmp/wifi_chat_seq 2>/dev/null; echo 0 > /tmp/wifi_chat_admin_seq; : > /tmp/wifi_chat_seen
    echo "cleared"
    ;;
  *)
    echo "unknown"
    ;;
esac
