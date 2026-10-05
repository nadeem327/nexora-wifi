#!/bin/sh
CATEGORY=$(echo "$QUERY_STRING" | sed -n 's/.*cat=\([^&]*\).*/\1/p')
[ -z "$CATEGORY" ] && CATEGORY="cartoon"
VIDDIR="/www/videos_lib/$CATEGORY"
USBDIR="/mnt/usb/Cartoons"
mkdir -p "$VIDDIR"
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')
if [ "$ACTION" = "delete" ]; then
  rm -f "$VIDDIR"/*.mp4 "$VIDDIR"/*.mkv "$VIDDIR"/*.avi
  echo '{"status":"deleted","msg":"'$CATEGORY' folder khali ho gaya"}'
  exit 0
fi
if [ "$ACTION" = "copyusb" ]; then
  FILE=$(ls "$USBDIR"/*.mp4 "$USBDIR"/*.mkv "$USBDIR"/*.avi 2>/dev/null | head -1)
  if [ -z "$FILE" ]; then
    echo '{"status":"error","msg":"USB mein koi video nahi mili"}'
  else
    rm -f "$VIDDIR"/*.mp4 "$VIDDIR"/*.mkv "$VIDDIR"/*.avi
    cp "$FILE" "$VIDDIR/"
    echo '{"status":"ok","msg":"File '$CATEGORY' mein copy ho gayi"}'
  fi
  exit 0
fi
CURRENT=$(ls "$VIDDIR"/*.mp4 "$VIDDIR"/*.mkv "$VIDDIR"/*.avi 2>/dev/null | head -1)
CNAME=""
SIZE=""
[ -n "$CURRENT" ] && CNAME=$(basename "$CURRENT")
[ -n "$CURRENT" ] && SIZE=$(ls -lh "$CURRENT" | awk '{print $5}')
echo "{\"category\":\"$CATEGORY\",\"current\":\"$CNAME\",\"size\":\"$SIZE\"}"
