#!/bin/sh
echo "Access-Control-Allow-Origin: *"
F=$(echo "$QUERY_STRING" | sed -n 's/.*f=\([^&]*\).*/\1/p')
case "$F" in
  ""|*..*|*/*)
    echo "Content-Type: text/plain"; echo ""
    echo "BAD"; exit 0;;
esac
FILE="/www/chat_audio/$F"
if [ ! -f "$FILE" ]; then
  echo "Content-Type: text/plain"; echo ""
  echo "NOFILE"; exit 0
fi
EXT="${F##*.}"
case "$EXT" in
  webm) CT="audio/webm" ;;
  m4a|mp4) CT="audio/mp4" ;;
  ogg|opus) CT="audio/ogg" ;;
  wav) CT="audio/wav" ;;
  *) CT="application/octet-stream" ;;
esac
echo "Content-Type: $CT"
echo ""
cat "$FILE"
