#!/bin/sh
# Get category from POST data (simple method)
CATEGORY=$(echo "$QUERY_STRING" | sed -n 's/.*cat=\([^&]*\).*/\1/p')
[ -z "$CATEGORY" ] && CATEGORY="cartoon"

VIDDIR="/www/videos"
mkdir -p "$VIDDIR"
echo "Content-Type: text/plain"
echo "Access-Control-Allow-Origin: *"
echo ""
TMPRAW="$VIDDIR/uploading.bin"
cat > "$TMPRAW"
SIZE=$(wc -c < "$TMPRAW")
if [ "$SIZE" -lt 1000 ]; then
  echo "Error: File empty"
  rm -f "$TMPRAW"
  exit 0
fi
echo "Upload mil gaya, '$CATEGORY' folder ke liye process ho raha hai..."
# Passing category as an argument to the python script
setsid sh -c "python3 /www/cgi-bin/extract_video.py '$CATEGORY' > /tmp/extract.log 2>&1" &
