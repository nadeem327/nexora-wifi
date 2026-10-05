#!/bin/sh
echo "Content-Type: text/plain; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo ""
CHATFILE="/www/wifi_chat.txt"
ADMIN_PASS=$(sed -n 's/^ADMIN_PASS="\(.*\)"/\1/p' /www/cgi-bin/wifi_chat_admin.sh)
PASS=$(echo "$QUERY_STRING" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
[ "$PASS" != "$ADMIN_PASS" ] && { echo DENIED; exit 0; }
touch /tmp/wifi_chat_seen
AS=$(cat /tmp/wifi_chat_admin_seq 2>/dev/null || echo 0)
awk -v a="$AS" '$2+0>=a+0{print $1}' /tmp/wifi_chat_seen | while read M; do
  S=$(echo "$M" | awk -F: 'NF>=2{print $(NF-1)":"$NF}')
  N=$(grep -F "[$S]:" "$CHATFILE" | grep -v ADMIN | tail -1 | sed 's/^\[[^]]*\] //; s/ \[[^]]*\]:.*$//')
  [ -z "$N" ] && N=$(grep -i "$M" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}' | head -1)
  { [ -z "$N" ] || [ "$N" = "*" ]; } && N="Guest-$(echo "$S" | tr -d ':')"
  echo "$N"
done | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g'
