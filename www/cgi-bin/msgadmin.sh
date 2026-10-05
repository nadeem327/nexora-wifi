#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
REQ="/etc/nodogsplash/requests.txt"
NOW=$(date '+%H:%M %d/%m/%Y')

read -r POSTDATA
dec() { printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%\(..\)/\\x\1/g')"; }

PNAME=$(printf '%s' "$POSTDATA" | sed -n 's/.*name=\([^&]*\).*/\1/p')
PMSG=$(printf '%s' "$POSTDATA" | sed -n 's/.*msg=\([^&]*\).*/\1/p')
PMAC=$(printf '%s' "$POSTDATA" | sed -n 's/.*mac=\([^&]*\).*/\1/p' | tr 'A-F' 'a-f')

NAME=$(dec "$PNAME" | tr -d '|\r\n' | cut -c1-60)
MSG=$(dec "$PMSG" | tr -d '|\r\n' | cut -c1-1000)
[ -z "$NAME" ] || [ -z "$MSG" ] && { echo '{"ok":0,"err":"empty"}'; exit 0; }

NEIGH=$(ip neigh show 2>/dev/null | awk -v ip="$REMOTE_ADDR" '$1==ip{print $5; exit}' | tr 'A-F' 'a-f')
MAC="$NEIGH"; [ -z "$MAC" ] && MAC="$PMAC"; [ -z "$MAC" ] && MAC="$REMOTE_ADDR"

REQ_ID=$(date '+%s')
printf '%s\n' "${REQ_ID}|${NAME}|message_request|${MSG}||${MAC}|pending|${NOW}" >> "$REQ"

RT=$(cat /etc/nodogsplash/ntfy_reply_topic 2>/dev/null)
CODE=$(printf '%s' "$MAC" | tr -d ':' | tail -c 4)
U="https://ntfy.sh/${RT}"
curl -s -H "Title: New Message from Client!" -H "Priority: high" -H "Tags: envelope,bell" \
  -H "Actions: http, Jee, ${U}, method=POST, body=${CODE} Jee bataiye; http, Ruko, ${U}, method=POST, body=${CODE} Thori der ruko main dekhta hun; http, Dekh liya, ${U}, method=POST, body=${CODE} seen" \
  -d "Naam: ${NAME}
Message: ${MSG}
MAC: ${MAC}
Reply code: ${CODE}
Time: ${NOW}
Neeche button dabayein, ya yahin jawab likhein" \
  "${U}" > /dev/null 2>&1

echo '{"ok":1}'
exit 0
