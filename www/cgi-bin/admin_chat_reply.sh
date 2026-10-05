#!/bin/sh
echo "Content-Type: text/plain"
echo ""
MSG=$(echo "$QUERY_STRING" | sed -n 's/.*msg=\([^&]*\).*/\1/p' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
TIME=$(date +"%I:%M %p")
echo "[$TIME] [ad:00]: Nexora WiFi Admin: $MSG" >> /www/watch_chat.txt
tail -30 /www/watch_chat.txt > /www/watch_chat.txt.tmp && mv /www/watch_chat.txt.tmp /www/watch_chat.txt
echo "sent"
