#!/bin/sh
echo "Content-Type: text/plain"
echo ""

NTFY_TOPIC="Nexorapayments"
NTFY_SERVER="https://ntfy.sh"
REQUESTS_FILE="/etc/nodogsplash/requests.txt"
APPROVE_BASE="http://192.168.20.1/cgi-bin/approve.sh"

urldecode(){ printf '%b' "$(echo "$1" | sed 's/+/ /g; s/%\(..\)/\\x\1/g')"; }

PHONE=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)phone=[^&]*' | sed 's/.*phone=//')")
TXID=$(urldecode  "$(echo "$QUERY_STRING" | grep -oE '(^|&)txid=[^&]*'  | sed 's/.*txid=//')")
PLAN=$(urldecode  "$(echo "$QUERY_STRING" | grep -oE '(^|&)plan=[^&]*'  | sed 's/.*plan=//')")
DAYS=$(urldecode  "$(echo "$QUERY_STRING" | grep -oE '(^|&)days=[^&]*'  | sed 's/.*days=//')")
MAC_FROM_SPLASH=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)mac=[^&]*' | sed 's/.*mac=//')")

CLIENT_IP="${REMOTE_ADDR}"

if [ -n "$MAC_FROM_SPLASH" ] && [ "$MAC_FROM_SPLASH" != "unknown" ]; then
  CLIENT_MAC="$MAC_FROM_SPLASH"
else
  CLIENT_MAC=$(arp -n 2>/dev/null | awk -v ip="$CLIENT_IP" '$1==ip{print $3}')
  [ -z "$CLIENT_MAC" ] && CLIENT_MAC="unknown"
fi

if [ -z "$PHONE" ] || [ -z "$TXID" ] || [ -z "$PLAN" ]; then
  echo "ERROR: Missing fields"
  exit 1
fi

touch /tmp/request_received
REQ_ID=$(date '+%s' 2>/dev/null | grep -E '^[0-9]+$' | head -1)
NOW=$(date '+%H:%M %d/%m/%Y' 2>/dev/null | grep -E '^[0-9]' | head -1)
[ -z "$REQ_ID" ] && REQ_ID=$(awk 'BEGIN{srand(); print srand()}')
[ -z "$NOW" ] && NOW="unknown time"

mkdir -p /etc/nodogsplash
printf '%s\n' "${REQ_ID}|${PHONE}|${TXID}|${PLAN}|${DAYS}|${CLIENT_MAC}|pending|${NOW}" >> "$REQUESTS_FILE"

APPROVE_URL="${APPROVE_BASE}?id=${REQ_ID}&mac=${CLIENT_MAC}&plan=${PLAN}&days=${DAYS}&phone=${PHONE}"

curl -s \
  -H "Title: New Payment Request!" \
  -H "Priority: high" \
  -H "Tags: moneybag,bell" \
  -H "Actions: view, APPROVE, ${APPROVE_URL}" \
  -d "Plan: ${PLAN} (${DAYS} Days)
Phone: ${PHONE}
TX ID: ${TXID}
MAC: ${CLIENT_MAC}
Time: ${NOW}" \
  "${NTFY_SERVER}/${NTFY_TOPIC}" > /dev/null 2>&1

printf 'OK\n'
