#!/bin/sh
echo "Content-Type: text/html; charset=UTF-8"
echo ""

NTFY_TOPIC="Nexorapayments"
NTFY_SERVER="https://ntfy.sh"
REQUESTS_FILE="/etc/nodogsplash/requests.txt"

urldecode(){ printf '%b' "$(echo "$1" | sed 's/+/ /g; s/%\(..\)/\\x\1/g')"; }

EMAIL=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)email=[^&]*' | sed 's/.*email=//')")
CLIENT_IP="${REMOTE_ADDR}"
CLIENT_MAC=$(arp -n 2>/dev/null | awk -v ip="$CLIENT_IP" '$1==ip{print $3}')
[ -z "$CLIENT_MAC" ] && CLIENT_MAC="unknown"

if [ -z "$EMAIL" ]; then
  echo "<p>ERROR: No email provided.</p>"
  exit 1
fi

REQ_ID=$(date '+%s')
NOW=$(date '+%H:%M %d/%m/%Y')

printf '%s\n' "${REQ_ID}|${EMAIL}|email_request|Message Request||${CLIENT_MAC}|pending|${NOW}" >> "$REQUESTS_FILE"

curl -s \
  -H "Title: New Message Request!" \
  -H "Priority: high" \
  -H "Tags: email,bell" \
  -d "Email: ${EMAIL}
MAC: ${CLIENT_MAC}
Time: ${NOW}" \
  "${NTFY_SERVER}/${NTFY_TOPIC}" > /dev/null 2>&1

echo "<html><body style='background:#0b1120;color:white;font-family:Arial;text-align:center;padding:50px'>
<h2 style='color:#22c55e'>✅ Request Received!</h2>
<p style='color:#cbd5e1'>Aap ka message mil gaya.<br>Admin jald rabta karega.</p>
</body></html>"
