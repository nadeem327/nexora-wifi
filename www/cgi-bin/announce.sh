#!/bin/sh
echo "Content-Type: text/html; charset=utf-8"
echo ""

ANNOUNCE_FILE="/etc/nodogsplash/htdocs/announcement.txt"
PASS="CHANGE_ME_ADMIN_PASS"

urldecode() {
  local data="${1//+/ }"
  printf '%b' "${data//%/\\x}"
}

GET_PASS=""
if [ -n "$QUERY_STRING" ]; then
  GET_PASS=$(echo "$QUERY_STRING" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
  GET_PASS=$(urldecode "$GET_PASS")
fi

STATUS=""
if [ "$REQUEST_METHOD" = "POST" ]; then
  POST_DATA=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
  msg=$(echo "$POST_DATA" | sed -n 's/.*msg=\([^&]*\).*/\1/p')
  pass=$(echo "$POST_DATA" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
  msg=$(urldecode "$msg")
  pass=$(urldecode "$pass")
  if [ "$pass" = "$PASS" ] && [ -n "$msg" ]; then
    echo "$msg" > "$ANNOUNCE_FILE"
    STATUS="<p style='color:#39ff88;font-weight:bold;'>✅ Message Updated!</p>"
  else
    STATUS="<p style='color:#ff5050;font-weight:bold;'>❌ Wrong password or empty message</p>"
  fi
  GET_PASS="$pass"
fi

CURRENT=$(cat "$ANNOUNCE_FILE" 2>/dev/null)

cat << HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NEXORA Announcement</title>
<style>
body { background:#0a1420; color:#fff; font-family:sans-serif; text-align:center; padding:30px 15px; margin:0; }
.card { max-width:420px; margin:0 auto; background:#0d1b2a; border:2px solid #00e0c6; border-radius:14px; padding:24px; box-shadow:0 0 20px #00e0c655; }
h2 { color:#00e0c6; margin-top:0; }
textarea { width:100%; box-sizing:border-box; padding:12px; border-radius:8px; border:1px solid #00e0c6; background:#1a2b3c; color:#fff; font-size:16px; resize:vertical; }
input[type=password] { width:100%; box-sizing:border-box; padding:12px; margin-top:12px; border-radius:8px; border:1px solid #00e0c6; background:#1a2b3c; color:#fff; font-size:16px; }
button { width:100%; margin-top:16px; padding:14px; border:none; border-radius:8px; background:#00e0c6; color:#0a1420; font-weight:bold; font-size:16px; }
</style>
</head>
<body>
<div class="card">
<h2>📢 NEXORA Announcement</h2>
$STATUS
<form method="POST" action="/cgi-bin/announce.sh">
<textarea name="msg" rows="4">$CURRENT</textarea>
<input type="password" name="pass" placeholder="Admin Password" value="$GET_PASS">
<button type="submit">Update Message</button>
</form>
</div>
</body>
</html>
HTML
