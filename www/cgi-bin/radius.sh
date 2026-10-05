#!/bin/sh
AUTH_FILE="/etc/freeradius3/mods-config/files/authorize"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"
ADMIN_PASS="nadeem123"
NAMES_FILE="/etc/nodogsplash/device_names.txt"
TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
echo "Content-Type: text/html; charset=UTF-8"
echo ""
PASS=$(echo "$QUERY_STRING" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
if [ "$PASS" != "$ADMIN_PASS" ]; then
cat << 'LOGIN'
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEXORA Radius</title><style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',sans-serif;background:#0f172a;display:flex;justify-content:center;align-items:center;height:100vh}.card{background:#1e293b;padding:40px;border-radius:24px;box-shadow:0 20px 50px rgba(0,0,0,.6);text-align:center;width:90%;max-width:360px}h2{color:#a78bfa;margin-bottom:25px;font-size:1.4rem;letter-spacing:.1em}
LOGIN
exit 0
fi
if [ "$REQUEST_METHOD" = "POST" ]; then
POST_DATA=$(dd bs=$CONTENT_LENGTH count=1 2>/dev/null)
action=$(echo "$POST_DATA" | sed -n 's/.*action=\([^&]*\).*/\1/p')
voucher=$(echo "$POST_DATA" | sed -n 's/.*voucher=\([^&]*\).*/\1/p' | tr '[:lower:]' '[:upper:]')
days=$(echo "$POST_DATA" | sed -n 's/.*days=\([^&]*\).*/\1/p')
keycount=$(echo "$POST_DATA" | sed -n 's/.*keycount=\([^&]*\).*/\1/p')
if [ "$action" = "add" ] && [ -n "$voucher" ] && [ -n "$days" ]; then
SECS=$((days*86400))
if grep -q "^$voucher " "$AUTH_FILE" 2>/dev/null; then
echo "<script>alert('Already exists!');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
else
printf '%s Cleartext-Password := "%s"\n    Session-Timeout = %s,\n    Reply-Message = "Welcome to Nexora WiFi"\n' "$voucher" "$voucher" "$SECS" >> "$AUTH_FILE"
echo "$voucher" >> "$VOUCHER_FILE"
kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
echo "<script>alert('✅ Added: $voucher ($days days)');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
fi
exit 0
fi
if [ "$action" = "delete" ] && [ -n "$voucher" ]; then
awk -v v="$voucher" '/^[A-Za-z]/{skip=($1==v)}/^[A-Za-z]/&&$1!=v{skip=0}!skip{print}' "$AUTH_FILE" > /tmp/auth_tmp && mv /tmp/auth_tmp "$AUTH_FILE"
sed -i "/^$voucher/d" "$VOUCHER_FILE"
kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
echo "<script>alert('🗑️ Deleted: $voucher');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "test" ] && [ -n "$voucher" ]; then
RESULT=$(radtest "$voucher" "$voucher" 127.0.0.1 0 testing123 2>&1)
if echo "$RESULT" | grep -q "Access-Accept"; then
TO=$(echo "$RESULT" | grep "Session-Timeout" | awk '{print $3}')
DL=$((TO/86400))
echo "<script>alert('✅ Access-Accept!\nDays Left: $DL days');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
else
echo "<script>alert('❌ Access-Reject!');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
fi
exit 0
fi
if [ "$action" = "delmac" ] && [ -n "$voucher" ]; then
mac=$(echo "$POST_DATA" | sed -n 's/.*mac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
sed -i "/^$mac$/d" "$TRUSTED_FILE"
ndsctl deauth "$mac" 2>/dev/null
ndsctl untrust "$mac" 2>/dev/null
echo "<script>alert('Device removed');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "delmac2" ]; then
mac=$(echo "$POST_DATA" | sed -n 's/.*mac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
sed -i "/^$mac$/d" "$TRUSTED_FILE"
ndsctl deauth "$mac" 2>/dev/null
ndsctl untrust "$mac" 2>/dev/null
echo "<script>alert('Device removed');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "setdevname" ]; then
dmac=$(echo "$POST_DATA" | sed -n 's/.*dmac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
dname=$(echo "$POST_DATA" | sed -n 's/.*dname=\([^&]*\).*/\1/p' | sed 's/+/ /g;s/%20/ /g')
if grep -qi "^$dmac|" "$NAMES_FILE" 2>/dev/null; then
sed -i "s/^$dmac|.*/$dmac|$dname/" "$NAMES_FILE"
else
echo "$dmac|$dname" >> "$NAMES_FILE"
fi
echo "<script>alert('Name saved');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "genkeys" ]; then
[ -z "$keycount" ] && keycount=5
i=0
while [ $i -lt $keycount ]; do
key="Nexora-$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)"
printf '%s Cleartext-Password := "%s"\n    Session-Timeout = 2592000,\n    Reply-Message = "Welcome to Nexora WiFi"\n' "$key" "$key" >> "$AUTH_FILE"
echo "$key" >> "$VOUCHER_FILE"
i=$((i+1))
done
kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
echo "<script>alert('✅ $keycount keys generated!');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "sync" ]; then
SYNCED=0
while read -r line; do
V=$(echo "$line" | awk '{print $1}')
[ -z "$V" ] && continue
if ! grep -q "^$V " "$AUTH_FILE" 2>/dev/null; then
printf '%s Cleartext-Password := "%s"\n    Session-Timeout = 2592000,\n    Reply-Message = "Welcome to Nexora WiFi"\n' "$V" "$V" >> "$AUTH_FILE"
SYNCED=$((SYNCED+1))
fi
done < "$VOUCHER_FILE"
kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
echo "<script>alert('✅ Sync done! $SYNCED added');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
if [ "$action" = "reload" ]; then
kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
echo "<script>alert('↺ FreeRADIUS Reloaded!');window.location='radius.sh?pass=$ADMIN_PASS';</script>"
exit 0
fi
fi
NOW=$(date +%s)
TOTAL_R=$(grep -c "Cleartext-Password" "$AUTH_FILE" 2>/dev/null || echo 0)
FREE_V=$(grep -v "LOCKED" "$VOUCHER_FILE" 2>/dev/null | grep -c "^Nexora-" || echo 0)
LOCKED_V=$(grep -c "LOCKED" "$VOUCHER_FILE" 2>/dev/null || echo 0)
RADIUS_PID=$(ps | grep radiusd | grep -v grep | awk '{print $1}')
[ -n "$RADIUS_PID" ] && RS="Active" && RC="22c55e" && BDGC="badge-green" && DOTC="dot-g" || RS="Down" && RC="ef4444" && BDGC="badge-red" && DOTC="dot-r"
T2G=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | awk '{printf "%.1f°C",$1/1000}'); [ -z "$T2G" ] && T2G="N/A"
T5G0=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | awk '{printf "%.1f°C",$1/1000}'); [ -z "$T5G0" ] && T5G0="N/A"
T5G1=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | awk '{printf "%.1f°C",$1/1000}'); [ -z "$T5G1" ] && T5G1="N/A"
cat << HTML
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEXORA Radius Panel</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',Roboto,sans-serif;background:#0f172a;color:#e2e8f0;min-height:100vh;padding:12px}
.hdr{background:linear-gradient(135deg,#1e1b4b,#1e293b);border-radius:20px;padding:16px 20px;margin-bottom:12px;display:flex;align-items:center;justify-content:space-between;border:1px solid rgba(167,139,250,.2)}
.logo{font-size:1.2rem;font-weight:800;letter-spacing:.12em;background:linear-gradient(90deg,#a78bfa,#06ffd4);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.sublabel{font-size:9px;color:#475569;letter-spacing:.15em;margin-top:2px}
.badge{display:inline-flex;align-items:center;gap:5px;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:700}
.badge-green{background:rgba(34,197,94,.13);color:#22c55e;border:1px solid rgba(34,197,94,.3)}
.badge-red{background:rgba(239,68,68,.13);color:#ef4444;border:1px solid rgba(239,68,68,.3)}
.dot{width:6px;height:6px;border-radius:50%;animation:pulse 1.5s infinite}
.dot-g{background:#22c55e;box-shadow:0 0 6px #22c55e}
.dot-r{background:#ef4444;box-shadow:0 0 6px #ef4444}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.4;transform:scale(1.3)}}
.temp-row{display:flex;gap:8px;margin-bottom:12px}
.tc{flex:1;background:#1e293b;border-radius:14px;padding:12px;text-align:center;border:1px solid rgba(255,255,255,.07)}
.tc-lbl{font-size:9px;color:#64748b;letter-spacing:.1em;text-transform:uppercase;margin-bottom:4px;font-family:monospace}
.tc-val{font-size:1.1rem;font-weight:700;font-family:monospace}
.t-or{color:#fb923c}.t-cy{color:#06b6d4}.t-re{color:#f87171}
.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}
.sc{background:#1e293b;border-radius:16px;padding:16px 12px;text-align:center;border:1px solid rgba(255,255,255,.07)}
.sn{font-size:2rem;font-weight:800;font-family:monospace;line-height:1}
.sl{font-size:9px;color:#64748b;text-transform:uppercase;letter-spacing:.1em;margin-top:4px}
.np{color:#a78bfa}.ng{color:#22c55e}.ny{color:#fbbf24}
.acts{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.sec{background:#1e293b;border-radius:16px;padding:16px;margin-bottom:12px;border:1px solid rgba(255,255,255,.07)}
.tabs{display:flex;gap:4px;background:rgba(0,0,0,.3);border-radius:12px;padding:4px;margin-bottom:14px}
.tab{flex:1;padding:8px;border-radius:8px;font-size:10px;font-weight:700;text-align:center;cursor:pointer;color:#475569;letter-spacing:.05em;text-transform:uppercase;border:none;background:none;transition:all .2s}
.tab.on{background:linear-gradient(135deg,#7c3aed,#a78bfa);color:#fff}
.tc2{display:none}.tc2.on{display:block}
.fr{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:4px}
input[type=text],input[type=number]{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:10px 14px;color:#e2e8f0;font-size:13px;outline:none;transition:border-color .2s}
input:focus{border-color:rgba(167,139,250,.5)}
input::placeholder{color:#334155}
.iv{flex:1;min-width:130px}.is{width:68px}
.btn{padding:10px 16px;border:none;border-radius:12px;font-size:11px;font-weight:700;cursor:pointer;letter-spacing:.05em;text-transform:uppercase;transition:all .15s;white-space:nowrap}
.btn:hover{opacity:.85;transform:translateY(-1px)}
.bp{background:linear-gradient(135deg,#7c3aed,#a78bfa);color:#fff;box-shadow:0 4px 14px rgba(124,58,237,.3)}
.bg{background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;box-shadow:0 4px 14px rgba(34,197,94,.25)}
.bc{background:linear-gradient(135deg,#0891b2,#06b6d4);color:#fff;box-shadow:0 4px 14px rgba(6,182,212,.25)}
.br{background:rgba(239,68,68,.15);color:#ef4444;border:1px solid rgba(239,68,68,.3)}
.bo{background:rgba(251,146,60,.15);color:#fb923c;border:1px solid rgba(251,146,60,.3)}
.bsm{padding:5px 10px;font-size:10px;border-radius:8px}
.tw{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:12px}
th{font-size:9px;font-weight:700;letter-spacing:.1em;color:#475569;text-transform:uppercase;padding:8px 10px;text-align:left;border-bottom:1px solid rgba(255,255,255,.06)}
td{padding:10px;border-bottom:1px solid rgba(255,255,255,.04);vertical-align:middle}
tr:hover td{background:rgba(255,255,255,.02)}
.mo{font-family:monospace;font-size:11px}
.chip{display:inline-block;padding:2px 8px;border-radius:20px;font-size:9px;font-weight:700}
.cg{background:rgba(34,197,94,.13);color:#22c55e;border:1px solid rgba(34,197,94,.25)}
.cy2{background:rgba(251,191,36,.13);color:#fbbf24;border:1px solid rgba(251,191,36,.25)}
.cr{background:rgba(239,68,68,.13);color:#ef4444;border:1px solid rgba(239,68,68,.25)}
.cb{background:rgba(96,165,250,.13);color:#60a5fa;border:1px solid rgba(96,165,250,.25)}
.stitle{font-size:10px;font-weight:700;letter-spacing:.12em;color:#64748b;text-transform:uppercase;margin-bottom:10px;display:flex;align-items:center;gap:6px}
.stitle::after{content:'';flex:1;height:1px;background:rgba(255,255,255,.06)}
</style>
</head><body>
<div class="hdr">
  <div><div class="logo">NEXORA RADIUS</div><div class="sublabel">FREERADIUS PANEL</div></div>
  <span class="badge $BDGC"><span class="dot $DOTC"></span>$RS</span>
</div>
<div class="temp-row">
  <div class="tc"><div class="tc-lbl">2.4GHz</div><div class="tc-val t-or">$T2G</div></div>
  <div class="tc"><div class="tc-lbl">5GHz R0</div><div class="tc-val t-cy">$T5G0</div></div>
  <div class="tc"><div class="tc-lbl">5GHz R1</div><div class="tc-val t-re">$T5G1</div></div>
</div>
<div class="stats">
  <div class="sc"><div class="sn np">$TOTAL_R</div><div class="sl">Total Keys</div></div>
  <div class="sc"><div class="sn ng">$FREE_V</div><div class="sl">Free</div></div>
  <div class="sc"><div class="sn ny">$LOCKED_V</div><div class="sl">In Use</div></div>
</div>
<div class="acts">
  <form method="post" style="margin:0"><input type="hidden" name="action" value="reload"><button class="btn bc" type="submit">↺ Reload</button></form>
  <form method="post" style="margin:0"><input type="hidden" name="action" value="sync"><button class="btn bo" type="submit">🔄 Sync</button></form>
  <a href="admin.sh?pass=$ADMIN_PASS" style="text-decoration:none"><button class="btn bp">← Admin</button></a>
</div>
<div class="sec">
<div class="tabs">
  <button class="tab on" onclick="sw('add',this)">➕ Add</button>
  <button class="tab" onclick="sw('gen',this)">⚡ Generate</button>
  <button class="tab" onclick="sw('test',this)">🔍 Test</button>
  <button class="tab" onclick="sw('list',this)">🔑 Keys</button>
  <button class="tab" onclick="sw('dev',this)">📶 Devices</button>
</div>
<div id="t-add" class="tc2 on">
  <div class="stitle">Add Voucher</div>
  <form method="post"><input type="hidden" name="action" value="add">
  <div class="fr">
    <input class="iv" type="text" name="voucher" placeholder="Nexora-XXXXXXXX" required>
    <input class="is" type="number" name="days" value="30" min="1" max="365" required>
    <button class="btn bp" type="submit">+ Add</button>
  </div></form>
</div>
<div id="t-gen" class="tc2">
  <div class="stitle">Generate Keys</div>
  <form method="post"><input type="hidden" name="action" value="genkeys">
  <div class="fr">
    <span style="font-size:13px;color:#64748b">Kitni keys:</span>
    <input class="is" type="number" name="keycount" value="5" min="1" max="50">
    <button class="btn bg" type="submit">⚡ Generate</button>
  </div></form>
</div>
<div id="t-test" class="tc2">
  <div class="stitle">Test Voucher</div>
  <form method="post"><input type="hidden" name="action" value="test">
  <div class="fr">
    <input class="iv" type="text" name="voucher" placeholder="Nexora-XXXXXXXX" required>
    <button class="btn bc" type="submit">▶ Test</button>
  </div></form>
</div>
<div id="t-list" class="tc2">
  <div class="stitle">All Vouchers</div>
  <div class="tw"><table><thead><tr><th>Voucher</th><th>Days</th><th>Status</th><th>Actions</th></tr></thead><tbody>
HTML
awk '/^[A-Za-z]/{v=$1;t=0}/Session-Timeout/{gsub(/,/,"",$3);t=$3;print v"|"t}' "$AUTH_FILE" | while IFS='|' read V T; do
DL=$((T/86400))
VFL=$(grep "^$V" "$VOUCHER_FILE" 2>/dev/null)
ISL=$(echo "$VFL" | grep "LOCKED")
EXP=$(echo "$VFL" | grep -o "EXP-[0-9]*" | cut -d'-' -f2)
if [ -n "$ISL" ]; then
  if [ -n "$EXP" ]; then
    R=$(( (EXP-NOW)/86400 ))
    [ "$R" -le 0 ] && CH="cr" && DS="Exp" || { [ "$R" -le 5 ] && CH="cy2" || CH="cg"; DS="${R}d"; }
  else CH="cg"; DS="${DL}d"; fi
  ST="<span class='chip cb'>🔒 Used</span>"
elif [ -n "$VFL" ]; then
  ST="<span class='chip cg'>✅ Free</span>"; CH="cg"; DS="${DL}d"
else
  ST="<span class='chip cr'>⚠️ R-Only</span>"; CH="cy2"; DS="${DL}d"
fi
echo "<tr><td class='mo'>$V</td><td><span class='chip $CH'>$DS</span></td><td>$ST</td><td>
<form method='post' style='display:inline;margin:0'><input type='hidden' name='action' value='test'><input type='hidden' name='voucher' value='$V'><button class='btn bc bsm' type='submit'>Test</button></form>
<form method='post' style='display:inline;margin:0'><input type='hidden' name='action' value='delete'><input type='hidden' name='voucher' value='$V'><button class='btn br bsm' onclick=\"return confirm('Delete?')\" type='submit'>Del</button></form>
</td></tr>"
done
cat << 'HTML2'
</tbody></table></div>
</div>
<div id="t-dev" class="tc2">
  <div class="stitle">Trusted Devices</div>
HTML2
while IFS= read -r mac; do
[ -z "$mac" ] && continue
dname=$(grep -i "^$mac|" "$NAMES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2-)
[ -z "$dname" ] && dname="$mac"
if ip neigh show dev br-hotspot 2>/dev/null | grep -i "$mac" | grep -qiE "REACHABLE|STALE|DELAY"; then
  SB="<span class='chip cg'>🟢 Online</span>"
else
  SB="<span class='chip cb'>⚪ Offline</span>"
fi
echo "<div style='background:#0f172a;border:1px solid rgba(255,255,255,.08);border-radius:16px;padding:14px 16px;margin-bottom:10px;'>
<div style='display:flex;justify-content:space-between;align-items:center;'>
<div style='font-weight:700;font-size:.95rem;color:#e2e8f0;'>$dname</div>
$SB
</div>
<div style='font-family:monospace;font-size:.75rem;color:#64748b;margin-top:4px;'>$mac</div>
<div style='display:flex;gap:8px;margin-top:10px;'>
<button class='btn bc bsm' onclick=\"renameDevice('$mac')\" type='button'>✏️ Rename</button>
<form method='post' style='display:inline;margin:0'>
<input type='hidden' name='action' value='delmac2'>
<input type='hidden' name='mac' value='$mac'>
<button class='btn br bsm' onclick=\"return confirm('Remove?')\" type='submit'>Remove</button>
</form>
</div>
</div>"
done < "$TRUSTED_FILE"
cat << 'END'
</tbody></table></div>
</div>
</div></div>
<script>
function renameDevice(mac){
  var n = prompt('Naya naam likho:');
  if(n===null || n==='') return;
  var f = document.createElement('form');
  f.method='post';
  f.innerHTML = "<input type='hidden' name='action' value='setdevname'><input type='hidden' name='dmac' value='"+mac+"'><input type='hidden' name='dname' value='"+n+"'>";
  document.body.appendChild(f);
  f.submit();
}
function sw(n,el){
  document.querySelectorAll('.tc2').forEach(t=>t.classList.remove('on'));
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('on'));
  document.getElementById('t-'+n).classList.add('on');
  el.classList.add('on');
}
</script>
</body></html>
END
