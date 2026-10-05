#!/bin/sh
echo "Content-Type: text/plain; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo ""

CHATFILE="/www/wifi_chat.txt"
LOCK="/tmp/wifi_chat.lock"
FLOODDIR="/tmp/chat_fl"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1517393659773980712/WKwgT5Wsplr8D0sapc1d58KSnropdq30g0hWhsoNT9tOkx8FKlX_5rSLf1SSOwPM1aQB"

touch "$CHATFILE"
mkdir -p "$FLOODDIR"

ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

if [ "$ACTION" = "send" ]; then
  CLIENT_IP="$REMOTE_ADDR"

  # Flood control: 1 message per 3 second per IP
  NOW=$(date +%s)
  LAST=$(cat "$FLOODDIR/$CLIENT_IP" 2>/dev/null || echo 0)
  if [ $((NOW - LAST)) -lt 3 ]; then
    echo "SLOW"
    exit 0
  fi
  echo "$NOW" > "$FLOODDIR/$CLIENT_IP"

  RAWMSG=$(echo "$QUERY_STRING" | sed -n 's/.*msg=\([^&]*\).*/\1/p')
  RAWNAME=$(echo "$QUERY_STRING" | sed -n 's/.*name=\([^&]*\).*/\1/p')

  MSG=$(printf '%s' "$RAWMSG" | sed 's/+/ /g' | python3 -c "import sys,urllib.parse
s=urllib.parse.unquote(sys.stdin.read().strip())
for c in ['|','\n','\r']: s=s.replace(c,' ')
print(s[:200])")
  NAME=$(printf '%s' "$RAWNAME" | sed 's/+/ /g' | python3 -c "import sys,urllib.parse
s=urllib.parse.unquote(sys.stdin.read().strip())
for c in ['|','\n','\r']: s=s.replace(c,' ')
print(s[:15])")

  [ -z "$MSG" ] && { echo "empty"; exit 0; }

  MAC=$(ip neigh show 2>/dev/null | grep "^$CLIENT_IP " | awk '{print $5}' | head -1)
  [ -z "$MAC" ] && MAC="--:--:--:--"
  SHORT_MAC=$(echo "$MAC" | awk -F: '{print $(NF-1)":"$NF}')
  LN=$(echo "$NAME" | tr 'A-Z' 'a-z')
  if [ -z "$NAME" ] || [ "$LN" = "guest" ]; then
    HN=$(grep -i "$MAC" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}' | head -1 | tr -cd 'A-Za-z0-9_-' | cut -c1-12)
    if [ "$MAC" = "--:--:--:--" ]; then
      GID=$(echo "$CLIENT_IP" | awk -F. '{print $NF}')
    else
      GID=$(echo "$SHORT_MAC" | tr -d ':')
    fi
    if [ -n "$HN" ]; then NAME="$HN-$GID"; else NAME="Guest-$GID"; fi
  fi
  TIME=$(date +"%I:%M %p")

  (
    flock -x 200 2>/dev/null
    echo "[$TIME] $NAME [$SHORT_MAC]: $MSG" >> "$CHATFILE"
    tail -50 "$CHATFILE" > "$CHATFILE.tmp" && mv "$CHATFILE.tmp" "$CHATFILE"
    SEQ=$(($(cat /tmp/wifi_chat_seq 2>/dev/null || echo 0)+1)); echo "$SEQ" > /tmp/wifi_chat_seq
  ) 200>"$LOCK"

  DISCORD_MSG=$(printf '%s' "[$SHORT_MAC] $NAME: $MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
  curl -s -m 5 -X POST -H "Content-Type: application/json" -d "{\"content\":\"$DISCORD_MSG\"}" "$DISCORD_WEBHOOK" > /dev/null 2>&1 &
  printf 'Naam: %s\nMessage: %s\nMAC: %s\nTime: %s' "$NAME" "$MSG" "$SHORT_MAC" "$(date +'%H:%M %d/%m/%Y')" | curl -s -m 5 -H "Title: New Message from Client!" -H "Tags: envelope,bell" -H "Priority: high" -H "Click: http://192.168.20.1/cgi-bin/admin.sh" --data-binary @- https://ntfy.sh/Nexorapayments > /dev/null 2>&1 &

  echo "sent"
elif [ "$ACTION" = "seq" ]; then
  cat /tmp/wifi_chat_seq 2>/dev/null || echo 0
elif [ "$ACTION" = "seen" ]; then
  M0=$(ip neigh show 2>/dev/null | grep "^$REMOTE_ADDR " | awk '{print $5}' | head -1)
  [ -z "$M0" ] && M0="$REMOTE_ADDR"
  touch /tmp/wifi_chat_seen
  grep -v "^$M0 " /tmp/wifi_chat_seen > /tmp/wifi_chat_seen.tmp
  echo "$M0 $(cat /tmp/wifi_chat_seq 2>/dev/null || echo 0)" >> /tmp/wifi_chat_seen.tmp
  mv /tmp/wifi_chat_seen.tmp /tmp/wifi_chat_seen
  AS=$(cat /tmp/wifi_chat_admin_seq 2>/dev/null || echo 0)
  awk -v a="$AS" '$2+0>=a+0{print $1}' /tmp/wifi_chat_seen | while read M; do
    S=$(echo "$M" | awk -F: 'NF>=2{print $(NF-1)":"$NF}')
    N=$(grep -F "[$S]:" "$CHATFILE" | grep -v ADMIN | tail -1 | sed 's/^\[[^]]*\] //; s/ \[[^]]*\]:.*$//')
    [ -z "$N" ] && N=$(grep -i "$M" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}' | head -1)
    { [ -z "$N" ] || [ "$N" = "*" ]; } && N="Guest-$(echo "$S" | tr -d ':')"
    echo "$N"
  done | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g'
else
  tail -30 "$CHATFILE"
fi
