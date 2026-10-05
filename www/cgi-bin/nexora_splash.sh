#!/bin/sh
echo "Content-type: text/html; charset=UTF-8"
echo "Cache-Control: no-cache"
echo ""
QS="$QUERY_STRING"
fas_raw=$(echo "$QS"|grep -o 'fas=[^&]*'|cut -d= -f2-)
if [ -n "$fas_raw" ]; then
  dec=$(printf '%s' "$fas_raw"|sed 's/%2B/+/g;s/%2F/\//g;s/%3D/=/g'|base64 -d 2>/dev/null)
  tok=$(echo "$dec"|grep -o 'hid=[^,]*'|cut -d= -f2-|tr -d ' ')
  ip2=$(echo "$dec"|grep -o 'clientip=[^,]*'|cut -d= -f2-|tr -d ' ')
  mac=$(echo "$dec"|grep -o 'clientmac=[^,]*'|cut -d= -f2-|tr -d ' ')
  gw=$(echo "$dec"|grep -o 'gatewayaddress=[^,]*'|cut -d= -f2-|tr -d ' ')
  ori=$(echo "$dec"|grep -o 'originurl=[^,]*'|cut -d= -f2-|tr -d ' ')
  AUTH="http://${gw}/opennds_auth/"
else
  tok=""; ip2="N/A"; mac="N/A"; ori=""; AUTH="http://192.168.20.1:2050/opennds_auth/"
fi
[ -z "$gw" ] && AUTH="http://192.168.20.1:2050/opennds_auth/"
check=$(echo "$QS"|grep -o 'check=[^&]*'|cut -d= -f2-)
if [ "$check" = "1" ]; then
  vraw=$(echo "$QS"|grep -o 'voucher=[^&]*'|cut -d= -f2-)
  v=$(printf '%s' "$vraw"|sed 's/+/ /g;s/%20/ /g'|tr '[:lower:]' '[:upper:]')
  VFILE="/etc/opennds/vouchers.txt"
  if [ -n "$v" ] && grep -qx "$v" "$VFILE" 2>/dev/null; then
    sed -i "s|^${v}$|LOCKED-${v}|" "$VFILE"
    printf 'OK'
  else
    printf 'INVALID'
  fi
  exit 0
fi
sed -e "s|__TOK__|${tok}|g" -e "s|__REDIR__|${ori}|g" \
    -e "s|__AUTH__|${AUTH}|g" -e "s|__IP__|${ip2}|g" \
    -e "s|__MAC__|${mac}|g" /www/nexora.html
