#!/bin/sh
echo "Content-Type: text/plain"
echo "Access-Control-Allow-Origin: *"
echo ""
NAMEFILE="/tmp/watch_names.txt"
touch "$NAMEFILE"
CLIENT_IP="$REMOTE_ADDR"
CLIENT_MAC=$(ip neigh show | grep -i "$CLIENT_IP" | awk '{print $5}')
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

if [ "$ACTION" = "set" ]; then
  NAME=$(echo "$QUERY_STRING" | sed -n 's/.*name=\([^&]*\).*/\1/p')
  NAME=$(echo "$NAME" | sed 's/+/ /g; s/%20/ /g')
  grep -v "^$CLIENT_MAC|" "$NAMEFILE" > "$NAMEFILE.tmp" 2>/dev/null
  echo "$CLIENT_MAC|$NAME" >> "$NAMEFILE.tmp"
  mv "$NAMEFILE.tmp" "$NAMEFILE"
  echo "$NAME"
else
  EXISTING=$(grep "^$CLIENT_MAC|" "$NAMEFILE" | cut -d'|' -f2)
  if [ -n "$EXISTING" ]; then
    echo "$EXISTING"
  else
    echo "NONE"
  fi
fi
