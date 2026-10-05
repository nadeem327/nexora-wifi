#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

MAC=$(echo "$QUERY_STRING" | sed -n 's/^.*mac=\([^&]*\).*$/\1/p' | sed 's/%3A/:/g')
IP=$(ip neigh show | grep -i "$MAC" | awk '{print $1}' | head -1)

if [ -z "$IP" ]; then
    echo '{"error":"IP not found for this MAC"}'
    exit 0
fi

NOWSEC=$(date +%H:%M:%S | awk -F: '{print ($1*3600)+($2*60)+$3}')

grep "$IP" /tmp/dnsmasq.log 2>/dev/null | grep "query\[A\]" | tail -100 | awk -v now="$NOWSEC" -v ip="$IP" '
BEGIN{print "{\"ip\":\"" ip "\",\"entries\":["}
{
  split($3,t,":")
  secs = t[1]*3600+t[2]*60+t[3]
  ago = now - secs
  if (ago < 0) ago += 86400
  domain=$8
  printf("%s{\"domain\":\"%s\",\"ago\":%d}", (NR>1?",":""), domain, ago)
}
END{print "]}"}
'
