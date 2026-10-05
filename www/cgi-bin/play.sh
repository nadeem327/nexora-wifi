#!/bin/sh
CATEGORY=$(echo "$QUERY_STRING" | sed -n 's/.*cat=\([^&]*\).*/\1/p')
[ -z "$CATEGORY" ] && CATEGORY="cartoon"
VIDDIR="/www/videos_lib/$CATEGORY"

FILE=$(find "$VIDDIR" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) | head -n 1)

if [ -z "$FILE" ]; then
  echo "Status: 404 Not Found"
  echo ""
  exit 0
fi

SIZE=$(stat -c %s "$FILE")
CTYPE="video/mp4"

echo "Content-Type: $CTYPE"
echo "Access-Control-Allow-Origin: *"
echo "Accept-Ranges: bytes"

if [ -n "$HTTP_RANGE" ]; then
  RANGE_VAL=$(echo "$HTTP_RANGE" | sed 's/bytes=//')
  START=$(echo "$RANGE_VAL" | cut -d'-' -f1)
  END=$(echo "$RANGE_VAL" | cut -d'-' -f2)

  [ -z "$START" ] && START=0
  [ -z "$END" ] && END=$((SIZE - 1))

  LENGTH=$((END - START + 1))

  echo "Status: 206 Partial Content"
  echo "Content-Range: bytes $START-$END/$SIZE"
  echo "Content-Length: $LENGTH"
  echo ""
  
  # BusyBox tail اور head روٹر کے اندر فوری لک اپ (lseek) کرتے ہیں
  tail -c "+$((START + 1))" "$FILE" | head -c "$LENGTH"
else
  echo "Content-Length: $SIZE"
  echo ""
  cat "$FILE"
fi
