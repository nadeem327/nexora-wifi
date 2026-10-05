#!/bin/sh
echo "Content-type: text/html"
echo ""

ADMIN_PASS="CHANGE_ME_ADMIN_PASS"
NAMES_FILE="/etc/nodogsplash/device_names.txt"
TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"
BW_FILE="/tmp/data_usage.txt"

# ---------- Login ----------
if ! echo "$QUERY_STRING" | grep -q "pass=$ADMIN_PASS"; then
    cat << 'LOGIN'
<html>
<head><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEXORA Admin</title>
<style>
body{font-family:'Segoe UI',Roboto,sans-serif;background:#0f172a;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}
.login-card{background:#1e293b;padding:40px;border-radius:24px;box-shadow:0 20px 50px rgba(0,0,0,0.6);text-align:center;width:90%;max-width:360px}
.login-card h2{color:#22c55e;margin-bottom:25px}
input{width:100%;padding:14px;margin:10px 0;border-radius:14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.05);color:white;font-size:1rem;box-sizing:border-box}
button{width:100%;padding:14px;border:none;border-radius:14px;background:#22c55e;color:white;font-weight:bold;font-size:1rem;cursor:pointer;transition:0.2s}
button:hover{background:#16a34a}
</style></head>
<body><div class="login-card"><h2>NEXORA Admin</h2><form method="get"><input type="password" name="pass" placeholder="Password"><br><button type="submit">Login</button></form></div></body></html>
LOGIN
    exit 0
fi

# ---------- Helpers ----------
human_bytes() {
    bytes=$1
    [ "$bytes" -lt 1024 ] && echo "${bytes} B" && return
    [ "$bytes" -lt 1048576 ] && echo "$((bytes/1024)) KB" && return
    echo "$((bytes/1048576)) MB"
}

get_name() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    grep -i "^$mac|" "$NAMES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2-
}

set_name() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    name=$(echo "$2" | sed 's/+/ /g; s/%20/ /g')
    if grep -qi "^$mac|" "$NAMES_FILE" 2>/dev/null; then
        sed -i "s/^$mac|.*/$mac|$name/" "$NAMES_FILE"
    else
        echo "$mac|$name" >> "$NAMES_FILE"
    fi
}

# ---------- Handle POST ----------
if [ "$REQUEST_METHOD" = "POST" ]; then
    POST_DATA=$(dd bs=$CONTENT_LENGTH count=1 2>/dev/null)
    action=$(echo "$POST_DATA" | sed -n 's/.*action=\([^&]*\).*/\1/p')
    mac=$(echo "$POST_DATA" | sed -n 's/.*mac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
    key=$(echo "$POST_DATA" | sed -n 's/.*key=\([^&]*\).*/\1/p')
    name=$(echo "$POST_DATA" | sed -n 's/.*name=\([^&]*\).*/\1/p')

    if [ "$action" = "delmac" ] && [ -n "$mac" ]; then
        sed -i "/^$mac$/d" "$TRUSTED_FILE"
        sed -i "/LOCKED-$mac-/d" "$VOUCHER_FILE"
        uci del_list nodogsplash.@nodogsplash[0].trustedmac="$mac" 2>/dev/null
        uci commit nodogsplash
        /etc/init.d/nodogsplash reload
        echo "<script>alert('MAC $mac deleted');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "blockmac" ] && [ -n "$mac" ]; then
        ndsctl block "$mac" 2>/dev/null
        echo "<script>alert('MAC $mac blocked permanently');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "setname" ] && [ -n "$mac" ] && [ -n "$name" ]; then
        set_name "$mac" "$name"
        echo "<script>alert('Name updated');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "addvoucher" ] && [ -n "$key" ]; then
        echo "$key" >> "$VOUCHER_FILE"
        echo "<script>alert('Voucher $key added');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "sync" ]; then
        /usr/bin/sync_trusted_macs.sh
        echo "<script>alert('Sync completed');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "restart_nds" ]; then
        /etc/init.d/nodogsplash restart
        echo "<script>alert('NoDogSplash restarted');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "stop_nds" ]; then
        /etc/init.d/nodogsplash stop
        echo "<script>alert('NoDogSplash stopped');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "disable_hotspot" ]; then
        ifdown br-hotspot
        echo "<script>alert('Hotspot interface disabled');window.location='test_panel.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "reboot" ]; then
        reboot
        exit 0
    fi
fi

# ---------- Stats ----------
total_v=$(wc -l < "$VOUCHER_FILE")
free_v=$(grep -cv "LOCKED-" "$VOUCHER_FILE")
trusted_m=$(wc -l < "$TRUSTED_FILE")
if /etc/init.d/nodogsplash status >/dev/null 2>&1; then
    NDS_STATUS="Active"
    NDS_COLOR="#22c55e"
else
    NDS_STATUS="Down"
    NDS_COLOR="#ef4444"
fi

# ---------- Temperatures ----------
TEMP_2G=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G0=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G1=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
[ -z "$TEMP_2G" ] && TEMP_2G="N/A"
[ -z "$TEMP_5G0" ] && TEMP_5G0="N/A"
[ -z "$TEMP_5G1" ] && TEMP_5G1="N/A"

# ---------- Total Nexora Usage ----------
TOTAL_DOWN="0"; TOTAL_UP="0"
ndsctl status 2>/dev/null | grep -q "Total download" && {
    TOTAL_DOWN=$(ndsctl status 2>/dev/null | awk '/Total download:/ {print $3}')
    TOTAL_UP=$(ndsctl status 2>/dev/null | awk '/Total upload:/ {print $3}')
}
TOTAL_DOWN_HR=$(human_bytes $((TOTAL_DOWN * 1024)))
TOTAL_UP_HR=$(human_bytes $((TOTAL_UP * 1024)))

# ---------- ARP + Bandwidth ----------
arp_all=$(ip neigh show dev br-hotspot 2>/dev/null | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v 'fe80' | grep 'REACHABLE\|STALE\|DELAY')
ONLINE=0
[ -n "$arp_all" ] && ONLINE=$(echo "$arp_all" | wc -l)

# Counting vars
BLOCKED_DEV=0
REACHABLE_DEV=0

auth_entries=""
blocked_entries=""
if [ -n "$arp_all" ]; then
    while read -r ip _ mac _ state; do
        st=$(echo "$state" | awk '{print $NF}')
        case "$st" in
            REACHABLE) clr="#22c55e" ;;
            STALE) clr="#fbbf24" ;;
            *) clr="#94a3b8" ;;
        esac

        # Counting
        if ! grep -qi "^$mac$" "$TRUSTED_FILE" 2>/dev/null; then
            BLOCKED_DEV=$((BLOCKED_DEV + 1))
        fi
        [ "$st" = "REACHABLE" ] && REACHABLE_DEV=$((REACHABLE_DEV + 1))

        # Bandwidth data
        down=0; up=0
        if [ -f "$BW_FILE" ]; then
            stats=$(grep "^$mac " "$BW_FILE" | tail -1 | awk '{print $3, $4}')
            down=$(echo "$stats" | awk '{print $1}')
            up=$(echo "$stats" | awk '{print $2}')
        fi
        [ -z "$down" ] && down=0
        [ -z "$up" ] && up=0
        down_hr=$(human_bytes $down)
        up_hr=$(human_bytes $up)
        usage_str="⬇ $down_hr  ⬆ $up_hr"

        devname=$(get_name "$mac")
        [ -z "$devname" ] && devname="$mac"
        edit_link="<a href='test_panel.sh?pass=$ADMIN_PASS&editname=$mac' class='edit-link'>✏️</a>"

        if grep -qi "^$mac$" "$TRUSTED_FILE" 2>/dev/null; then
            auth="Authenticated"
            auth_clr="#22c55e"
            auth_entries="${auth_entries}$(echo "<div class='device'><div class='icon'>📱</div><div class='info'><div class='devname'>$devname $edit_link</div><div class='mac'>$mac</div><div class='ip'>$ip</div><div class='usage'>$usage_str</div><div class='status-line'><span class='arp-state' style='color:$clr'>$st</span><span class='auth-badge' style='background:${auth_clr}20;color:${auth_clr}'>$auth</span></div></div></div>")"$'\n'
        else
            auth="Blocked"
            auth_clr="#fbbf24"
            blocked_entries="${blocked_entries}$(echo "<div class='device'><div class='icon'>📱</div><div class='info'><div class='devname'>$devname $edit_link</div><div class='mac'>$mac</div><div class='ip'>$ip</div><div class='usage'>$usage_str</div><div class='status-line'><span class='arp-state' style='color:$clr'>$st</span><span class='auth-badge' style='background:${auth_clr}20;color:${auth_clr}'>$auth</span></div><div style='margin-top:4px;'><form method='post'><input type='hidden' name='action' 
        fi
    done <<EOF
$arp_all
EOF
fi

# ---------- HTML ----------
cat << HEADER
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>NEXORA Admin</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',Roboto,Oxygen,Ubuntu,sans-serif;background:#0f172a;color:#e2e8f0;padding:15px;min-height:100vh}
.header{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;margin-bottom:30px}
.header-left{display:flex;align-items:center;gap:12px}
.wifi-icon{width:45px;height:45px}
.wifi-icon svg{width:100%;height:100%}
.arc{stroke:#22c55e;stroke-width:4;fill:none;stroke-linecap:round;opacity:0;animation:arcAnim 2s infinite ease-out}
.arc:nth-child(2){animation-delay:0s}
.arc:nth-child(3){animation-delay:0.5s}
.arc:nth-child(4){animation-delay:1s}
@keyframes arcAnim{0%{opacity:0;transform:scale(0.8)}30%{opacity:1}70%{opacity:0;transform:scale(1.2)}100%{opacity:0;transform:scale(1.2)}}
.dot{fill:#22c55e}
.header h1{font-size:2rem;font-weight:700;color:#22c55e;letter-spacing:1px}
.status{display:flex;align-items:center;gap:8px;background:rgba(255,255,255,0.06);padding:8px 18px;border-radius:30px;font-weight:600;font-size:0.9rem}
.status-dot{width:12px;height:12px;border-radius:50%;background:${NDS_COLOR};box-shadow:0 0 12px ${NDS_COLOR}}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:15px;margin-bottom:30px}
.stats .card{background:#1e293b;border-radius:20px;padding:20px;text-align:center;box-shadow:0 5px 20px rgba(0,0,0,0.3)}
.stats .card .num{font-size:2.2rem;font-weight:700;color:#22c55e}
.stats .card .lbl{font-size:0.85rem;color:#94a3b8;margin-top:5px}
.temp-card .num{font-size:1.4rem;line-height:1.4;display:flex;flex-direction:column;align-items:center;gap:5px}
.temp-item{font-size:0.9rem;font-weight:500;display:flex;justify-content:space-between;width:100%;max-width:160px;margin:0 auto}
.temp-item span:first-child{color:#94a3b8;font-size:0.8rem}
.temp-item span:last-child{color:#cbd5e1;font-weight:600}
.section{background:#1e293b;border-radius:24px;padding:20px;margin-bottom:25px;box-shadow:0 8px 30px rgba(0,0,0,0.4);overflow-x:auto}
.section h2{color:#22c55e;margin-bottom:20px;font-size:1.3rem}
.device{border-bottom:1px solid rgba(255,255,255,0.06);padding:12px 0;display:flex;align-items:center;gap:12px}
.device:last-child{border-bottom:none}
.device .icon{font-size:1.8rem;width:45px}
.device .info{flex:1}
.device .info .mac{font-family:monospace;font-weight:bold;color:#cbd5e1}
.device .info .ip{font-size:0.8rem;color:#64748b}
.device .info .usage{font-size:0.85rem;color:#94a3b8;margin:4px 0}
.device .info .status-line{display:flex;gap:15px;align-items:center;margin-top:4px}
.device .info .arp-state{font-size:0.8rem;font-weight:500}
.device .info .auth-badge{font-size:0.75rem;padding:2px 10px;border-radius:12px;font-weight:600}
.device .info .devname{font-weight:600;color:#d0bcff;margin-bottom:2px}
.edit-link{font-size:0.8rem;color:#38bdf8;text-decoration:none;margin-left:8px}
table{width:100%;border-collapse:collapse;margin-top:10px}
th,td{padding:12px 8px;border-bottom:1px solid rgba(255,255,255,0.06);text-align:left}
th{color:#94a3b8;font-weight:500}
.status-locked{background:rgba(251,191,36,0.2);color:#fbbf24;padding:3px 12px;border-radius:20px;font-size:0.8rem;font-weight:600}
.status-free{background:rgba(34,197,94,0.2);color:#22c55e;padding:3px 12px;border-radius:20px;font-size:0.8rem;font-weight:600}
.btn{padding:10px 20px;border:none;border-radius:14px;font-weight:600;cursor:pointer;transition:0.2s;display:inline-flex;align-items:center;gap:6px;font-size:0.9rem;white-space:nowrap}
.btn-primary{background:#22c55e;color:white}
.btn-primary:hover{background:#16a34a}
.btn-danger{background:#ef4444;color:white}
.btn-danger:hover{background:#dc2626}
.btn-warn{background:#f59e0b;color:white}
.btn-warn:hover{background:#d97706}
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:15px}
input[type=text]{padding:10px 15px;border-radius:14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.05);color:white;font-size:0.9rem;flex:1;min-width:200px}
.toggle-btn{background:#475569;color:white;padding:6px 14px;border-radius:10px;font-size:0.8rem;cursor:pointer;border:none;margin-left:10px}
.edit-form{background:rgba(56,189,248,0.1);border:1px solid #38bdf8;border-radius:14px;padding:12px;margin:10px 0}
@media(max-width:600px){.header h1{font-size:1.5rem}.wifi-icon{width:38px;height:38px}.btn{padding:6px 12px;font-size:0.75rem}}
</style>
<script>
function toggleVouchers() {
    var x = document.getElementById("voucherTable");
    var btn = document.getElementById("toggleBtn");
    if (x.style.display === "none") {
        x.style.display = "block";
        btn.innerText = "🔽 Hide Voucher Keys";
    } else {
        x.style.display = "none";
        btn.innerText = "🔼 Show Voucher Keys";
    }
}
</script>
</head>
<body>
<div class="header">
  <div class="header-left">
    <div class="wifi-icon">
      <svg viewBox="0 0 40 40"><circle class="dot" cx="20" cy="30" r="3"/><path class="arc" d="M12,23 Q20,16 28,23"/><path class="arc" d="M7,18 Q20,8 33,18"/><path class="arc" d="M2,13 Q20,0 38,13"/></svg>
    </div>
    <h1>NEXORA</h1>
  </div>
  <div class="status"><span class="status-dot"></span> ${NDS_STATUS}</div>
</div>
<div class="stats">
<div class="card"><div class="num">$total_v</div><div class="lbl">Total Keys</div></div>
<div class="card"><div class="num">$free_v</div><div class="lbl">Free</div></div>
<div class="card"><div class="num">$BLOCKED_DEV</div><div class="lbl">Block</div></div>
<div class="card"><div class="num">$trusted_m</div><div class="lbl">Trusted MACs</div></div>
<div class="card"><div class="num">$REACHABLE_DEV</div><div class="lbl">Online</div></div>
<div class="card temp-card">
    <div class="num">
        <div class="temp-item"><span>2.4 GHz:</span><span>$TEMP_2G</span></div>
        <div class="temp-item"><span>5 GHz (Radio0):</span><span>$TEMP_5G0</span></div>
        <div class="temp-item"><span>5 GHz (Radio2):</span><span>$TEMP_5G1</span></div>
    </div>
    <div class="lbl">🌡️ Temperatures</div>
</div>
<div class="card">
    <div class="num" style="font-size:1.6rem;">⬇ $TOTAL_DOWN_HR  ⬆ $TOTAL_UP_HR</div>
    <div class="lbl">📊 Total Nexora Usage</div>
</div>
</div>
HEADER

# ---------- Name edit form ----------
EDIT_MAC=""
if echo "$QUERY_STRING" | grep -q "editname="; then
    EDIT_MAC=$(echo "$QUERY_STRING" | sed -n 's/.*editname=\([^&]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
    CURRENT_NAME=$(get_name "$EDIT_MAC")
    if [ -z "$CURRENT_NAME" ] && [ -f /tmp/dhcp.leases ]; then
        CURRENT_NAME=$(grep -i "$EDIT_MAC" /tmp/dhcp.leases | awk '{print $4}' | head -1)
    fi
    [ -z "$CURRENT_NAME" ] && CURRENT_NAME="$EDIT_MAC"
    echo "<div class='edit-form'>"
    echo "<strong style='color:#38bdf8;'>✏️ Set Name for $EDIT_MAC</strong>"
    echo "<form method='post' style='display:flex; gap:10px; align-items:center; margin-top:8px;'>"
    echo "<input type='hidden' name='action' value='setname'>"
    echo "<input type='hidden' name='mac' value='$EDIT_MAC'>"
    echo "<input type='text' name='name' value='$CURRENT_NAME' placeholder='Enter device/user name' style='flex:1;'>"
    echo "<button class='btn btn-primary' type='submit'>Save</button>"
    echo "<a href='test_panel.sh?pass=$ADMIN_PASS' class='btn' style='background:#475569;'>Cancel</a>"
    echo "</form></div>"
fi

# ---------- Blocked Devices (pehle) ----------
echo "<div class='section'><h2>🟡 Pre‑auth / Blocked Devices</h2>"
if [ -n "$blocked_entries" ]; then
    echo "$blocked_entries"
else
    echo "<p style='color:#64748b;'>All connected devices are authenticated.</p>"
fi
echo "</div>"

# ---------- Authenticated Devices ----------
echo "<div class='section'><h2>🟢 Authenticated Devices (Live Bandwidth)</h2>"
if [ -n "$auth_entries" ]; then
    echo "$auth_entries"
else
    echo "<p style='color:#64748b;'>No authenticated devices at the moment.</p>"
fi
echo "</div>"

# ---------- Trusted MACs & Remaining Days ----------
echo "<div class='section'><h2>⏳ Trusted MACs & Remaining Days</h2><table><tr><th>Name</th><th>MAC</th><th>Voucher</th><th>Days Left</th><th>Remove</th></tr>"
NOW=$(date +%s)
VALIDITY=2592000
grep "LOCKED-" "$VOUCHER_FILE" | while read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    mac=$(echo "$line" | sed -n 's/.*LOCKED-\([0-9a-fA-F:]*\)-.*/\1/p')
    start=$(echo "$line" | sed -n 's/.*-\([0-9]*\)$/\1/p')
    remaining=$(( (start + VALIDITY - NOW) / 86400 ))
    devname=$(get_name "$mac")
    [ -z "$devname" ] && devname="-"
    echo "<tr><td>$devname</td><td>$mac</td><td>$key</td><td>${remaining} days</td><td><form method='post'><input type='hidden' name='action' value='delmac'><input type='hidden' name='mac' value='$mac'><button class='btn btn-danger' style='padding:6px 12px;'>Remove</button></form></td></tr>"
done
echo "</table></div>"

# ---------- Voucher Keys ----------
echo "<div class='section'><h2>🔑 Voucher Keys <button id='toggleBtn' class='toggle-btn' onclick='toggleVouchers()'>🔽 Hide Voucher Keys</button></h2><div id='voucherTable'><table><tr><th>Key</th><th>Status</th><th>Used by MAC</th><th>Action</th></tr>"
while read -r line; do
    if echo "$line" | grep -q "LOCKED-"; then
        key=$(echo "$line" | awk '{print $1}')
        mac=$(echo "$line" | sed -n 's/.*LOCKED-\([0-9a-fA-F:]*\)-.*/\1/p')
        echo "<tr><td>$key</td><td><span class='status-locked'>LOCKED</span></td><td>$mac</td><td><form method='post' style='display:inline'><input type='hidden' name='action' value='delmac'><input type='hidden' name='mac' value='$mac'><button class='btn btn-danger' style='padding:6px 12px;'>Delete</button></form></td></tr>"
    else
        echo "<tr><td>$line</td><td><span class='status-free'>FREE</span></td><td>—</td><td></td></tr>"
    fi
done < "$VOUCHER_FILE"
echo "</table></div></div>"

# ---------- Add Voucher ----------
echo "<div class='section'><h2>➕ Add Voucher</h2><form method='post' style='display:flex;gap:10px;flex-wrap:wrap'><input type='hidden' name='action' value='addvoucher'><input type='text' name='key' placeholder='Enter voucher code' required><button type='submit' class='btn btn-primary'>Add</button></form></div>"

# ---------- Actions ----------
echo "<div class='actions'>
<form method='post' onsubmit=\"return confirm('Restart NoDogSplash?')\"><input type='hidden' name='action' value='restart_nds'><button class='btn btn-primary' type='submit'>🔄 Restart NDS</button></form>
<form method='post' onsubmit=\"return confirm('Stop NoDogSplash? All hotspot access will be blocked.')\"><input type='hidden' name='action' value='stop_nds'><button class='btn btn-warn' type='submit'>⏹️ Stop NDS</button></form>
<form method='post' onsubmit=\"return confirm('Disable Hotspot interface? Internet on hotspot will go down completely.')\"><input type='hidden' name='action' value='disable_hotspot'><button class='btn btn-danger' type='submit'>📴 Disable Hotspot</button></form>
<form method='post' onsubmit=\"return confirm('Reboot the router?')\"><input type='hidden' name='action' value='reboot'><button class='btn btn-danger' type='submit'>⏻ Reboot</button></form>
<a href='test_panel.sh?pass=$ADMIN_PASS' class='btn btn-primary' style='background:#475569;'>🔁 Refresh Page</a>
</div>"

echo "</body></html>"
