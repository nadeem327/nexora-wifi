#!/bin/sh
echo "Content-Type: text/html; charset=UTF-8"
echo ""

TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
REQUESTS_FILE="/etc/nodogsplash/requests.txt"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"

urldecode(){ printf '%b' "$(echo "$1" | sed 's/+/ /g; s/%\(..\)/\\x\1/g')"; }

MAC=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)mac=[^&]*' | sed 's/.*mac=//')")
DURATION=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)duration=[^&]*' | sed 's/.*duration=//')")
ID=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)id=[^&]*' | sed 's/.*id=//')")
PHONE=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)phone=[^&]*' | sed 's/.*phone=//')")
PLAN=$(urldecode "$(echo "$QUERY_STRING" | grep -oE '(^|&)plan=[^&]*' | sed 's/.*plan=//')")

[ -z "$MAC" ] && echo "<h2>Error: MAC missing!</h2>" && exit 1

# Duration to seconds
case "$DURATION" in
    0) echo "<html><body style='background:#0b1120;color:white;text-align:center;padding:50px'><h2 style='color:#ef4444'>❌ Rejected!</h2><p style='color:#cbd5e1'>Request reject kar di gayi.</p></body></html>"; exit 0 ;;
    2m)  SECONDS_DUR=120 ;;
    1h)  SECONDS_DUR=3600 ;;
    6h)  SECONDS_DUR=21600 ;;
    1d)  SECONDS_DUR=86400 ;;
    7d)  SECONDS_DUR=604800 ;;
    30d) SECONDS_DUR=2592000 ;;
    *)   SECONDS_DUR=86400 ;;
esac

# Free voucher dhundo
FREE_VOUCHER=$(grep -m1 '^Nexora-[A-Z0-9]*$' "$VOUCHER_FILE")
[ -n "$FREE_VOUCHER" ] && ! grep -q "LOCKED-${MAC}-" "$VOUCHER_FILE" && sed -i "s/^${FREE_VOUCHER}$/${FREE_VOUCHER} LOCKED-${MAC}-$(date +%s)-EXP-$(($(date +%s) + SECONDS_DUR))/" "$VOUCHER_FILE"

# MAC trusted list mein add karo

# NDS mein trust karo duration ke saath
ndsctl auth "$MAC" "$SECONDS_DUR" 2>/dev/null
# Expire time save karo
EXPIRE_FILE="/etc/nodogsplash/mac_expire.txt"
EXPIRE_TIME=$(($(date +%s) + SECONDS_DUR))
sed -i "/^${MAC} /d" "$EXPIRE_FILE"
echo "$MAC $EXPIRE_TIME" >> "$EXPIRE_FILE"
/usr/bin/untrust_after.sh "$MAC" "$SECONDS_DUR" &

# Request approved mark karo
sed -i "s/^${ID}|/approved_${ID}|/" "$REQUESTS_FILE" 2>/dev/null

echo "<html><body style='background:#0b1120;color:white;font-family:Arial;text-align:center;padding:50px'>
<h2 style='color:#22c55e'>✅ Approved!</h2>
<p style='color:#cbd5e1'>MAC: <b style='color:#00ffff'>${MAC}</b></p>
<p style='color:#cbd5e1'>Duration: <b style='color:#fbbf24'>${DURATION}</b></p>
<p style='color:#cbd5e1'>Phone: ${PHONE} | Plan: ${PLAN}</p>
<p style='color:#22c55e;font-size:20px;margin-top:20px'>Device ko internet mil gaya!</p>
</body></html>"
