#!/bin/sh
echo "Content-type: text/html"
echo ""

ADMIN_PASS="CHANGE_ME_ADMIN_PASS"
NAMES_FILE="/etc/nodogsplash/device_names.txt"
TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"
BW_FILE="/etc/nodogsplash/data_usage.txt"

# ---------- Login (support extra params) ----------
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

# ---------- Helper functions ----------
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
        # Replace the line with the new name
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
        echo "<script>alert('MAC $mac deleted');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "setname" ] && [ -n "$mac" ] && [ -n "$name" ]; then
        set_name "$mac" "$name"
        echo "<script>alert('Name updated');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "addvoucher" ] && [ -n "$key" ]; then
        echo "$key" >> "$VOUCHER_FILE"
        echo "<script>alert('Voucher $key added');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "sync" ]; then
        /usr/bin/sync_trusted_macs.sh
        echo "<script>alert('Sync completed');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
    elif [ "$action" = "genkeys" ]; then
        keycount=$(echo "$POST_DATA" | sed -n 's/.*keycount=\([^&]*\).*/\1/p')
        [ -z "$keycount" ] && keycount=5
        generated=""
        i=0
        while [ $i -lt $keycount ]; do
            key="Nexora-$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)"
            echo "$key" >> "$VOUCHER_FILE"
            generated="$generated $key"
            i=$((i+1))
        done
        echo "<script>alert('$keycount keys generate ho gayi!');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "customtime" ]; then
        custommac=$(echo "$POST_DATA" | sed -n 's/.*custommac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
        customval=$(echo "$POST_DATA" | sed -n 's/.*customval=\([^&]*\).*/\1/p')
        customunit=$(echo "$POST_DATA" | sed -n 's/.*customunit=\([^&]*\).*/\1/p')
        customname=$(echo "$POST_DATA" | sed -n 's/.*customname=\([^&]*\).*/\1/p' | sed 's/+/ /g;s/%20/ /g')
        case "$customunit" in
            m) SECONDS_DUR=$((customval * 60)) ;;
            h) SECONDS_DUR=$((customval * 3600)) ;;
            d) SECONDS_DUR=$((customval * 86400)) ;;
            *) SECONDS_DUR=86400 ;;
        esac
        FREE_VOUCHER=$(grep -m1 '^Nexora-[A-Z0-9]*$' "$VOUCHER_FILE")
        [ -n "$FREE_VOUCHER" ] && sed -i "s/^${FREE_VOUCHER}$/${FREE_VOUCHER} LOCKED-${custommac}-$(date +%s)-EXP-$(($(date +%s) + SECONDS_DUR))/" "$VOUCHER_FILE"
        grep -iq "^${custommac}$" "$TRUSTED_FILE" || echo "$custommac" >> "$TRUSTED_FILE"
        ndsctl auth "$custommac" "$SECONDS_DUR" 2>/dev/null || ndsctl trust "$custommac" 2>/dev/null
        /usr/bin/untrust_after.sh "$custommac" "$SECONDS_DUR" &
        EXPIRE_FILE="/etc/nodogsplash/mac_expire.txt"
        sed -i "/^${custommac} /d" "$EXPIRE_FILE" 2>/dev/null
        echo "$custommac $(($(date +%s) + SECONDS_DUR))" >> "$EXPIRE_FILE"
        [ -n "$customname" ] && grep -qi "^${custommac}|" "$NAMES_FILE" && sed -i "s/^${custommac}|.*/${custommac}|${customname}/" "$NAMES_FILE" || echo "${custommac}|${customname}" >> "$NAMES_FILE"
        echo "<script>alert('$custommac ko $customval$customunit internet diya gaya!');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
        exit 0
    elif [ "$action" = "restart_nds" ]; then
        /etc/init.d/nodogsplash restart
        echo "<script>alert('NoDogSplash restarted');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
    elif [ "$action" = "quickend" ]; then
        qmac=$(echo "$POST_DATA" | sed -n 's/.*qmac=\([^&]*\).*/\1/p' | sed 's/%3A/:/g' | tr '[:upper:]' '[:lower:]')
        qval=$(echo "$POST_DATA" | sed -n 's/.*qval=\([^&]*\).*/\1/p')
        qunit=$(echo "$POST_DATA" | sed -n 's/.*qunit=\([^&]*\).*/\1/p')
        case "$qunit" in
            m) Q_SECS=$((qval * 60)) ;;
            h) Q_SECS=$((qval * 3600)) ;;
            d) Q_SECS=$((qval * 86400)) ;;
            *) Q_SECS=3600 ;;
        esac
        grep -iq "^${qmac}$" "$TRUSTED_FILE" || echo "$qmac" >> "$TRUSTED_FILE"
        ndsctl auth "$qmac" "$Q_SECS" 2>/dev/null || ndsctl trust "$qmac" 2>/dev/null
        /usr/bin/untrust_after.sh "$qmac" "$Q_SECS" &
        EXPIRE_FILE="/etc/nodogsplash/mac_expire.txt"
        sed -i "/^${qmac} /d" "$EXPIRE_FILE" 2>/dev/null
        echo "$qmac $(($(date +%s) + Q_SECS))" >> "$EXPIRE_FILE"
        echo "<script>alert('Done!');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
        exit 0
    elif [ "$action" = "stop_nds" ]; then
        /etc/init.d/nodogsplash stop
        echo "<script>alert('NoDogSplash stopped');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "disable_hotspot" ]; then
        ifdown br-hotspot
        echo "<script>alert('Hotspot interface disabled');window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "reboot" ]; then
        reboot
        exit 0
    fi
fi

# ---------- Stats ----------
total_v=$(wc -l < "$VOUCHER_FILE")
free_v=$(grep -cv "LOCKED-" "$VOUCHER_FILE")
locked_v=$(grep -c "LOCKED-" "$VOUCHER_FILE")
trusted_m=$(wc -l < "$TRUSTED_FILE")
if /etc/init.d/nodogsplash status >/dev/null 2>&1; then
    NDS_STATUS="Active"
    NDS_COLOR="#22c55e"
else
    NDS_STATUS="Down"
    NDS_COLOR="#ef4444"
fi

# ---------- Temperature sensors ----------
TEMP_2G=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G0=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G1=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
[ -z "$TEMP_2G" ] && TEMP_2G="N/A"
[ -z "$TEMP_5G0" ] && TEMP_5G0="N/A"
[ -z "$TEMP_5G1" ] && TEMP_5G1="N/A"
[ -z "$TEMP_WIFI1" ] && TEMP_WIFI1="N/A"
[ -z "$TEMP_WIFI2" ] && TEMP_WIFI2="N/A"
# ---------- ARP + Bandwidth ----------
arp_all=$(ip neigh show dev br-hotspot 2>/dev/null | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v 'fe80' | grep 'REACHABLE\|STALE\|DELAY')
ONLINE=0
[ -n "$arp_all" ] && ONLINE=$(echo "$arp_all" | wc -l)

auth_entries=""
blocked_entries=""
if [ -n "$arp_all" ]; then
    while read -r client_ip _ mac _ state; do
        st=$(echo "$state" | awk '{print $NF}')
        case "$st" in
            REACHABLE) clr="#22c55e" ;;
            STALE) clr="#fbbf24" ;;
            *) clr="#94a3b8" ;;
        esac

        if [ -f "$BW_FILE" ]; then
            total_bytes=0
            if [ -f "$BW_FILE" ]; then
                total_bytes=$(grep -i "^$mac " "$BW_FILE" | tail -1 | awk '{print $3+$4}')
            fi
            [ -z "$total_bytes" ] && total_bytes=0
        fi
        total_hr=$(human_bytes $total_bytes)
        down_bytes=$(grep -i "^$mac " "$BW_FILE" | tail -1 | awk '{print $3+0}'); down_hr=$(human_bytes ${down_bytes:-0}); usage_str="Data Usage: $down_hr"

        # Device name (saved or fallback)
        devname=$(get_name "$mac")
        devname=$(get_name "$mac")
        [ -z "$devname" ] && devname=$(grep "|${mac}|" /etc/nodogsplash/requests.txt 2>/dev/null | tail -1 | cut -d"|" -f2)
        [ -z "$devname" ] && devname=$(grep -i "$mac" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}' | grep -v "^\*$" | head -1)
        [ -z "$devname" ] && devname="$mac"

        if grep -qi "^$mac$" "$TRUSTED_FILE" 2>/dev/null; then
            auth="Authenticated"
            auth_clr="#22c55e"
            auth_entries="${auth_entries}$(echo "<div class='device'><div class='icon'>📱</div><div class='info'><div class='devname'>$devname $edit_link</div><div class='mac'>$mac</div><div class="ip">$client_ip</div><div class='usage'>$usage_str</div><div class='status-line'><span class='arp-state' style='color:$clr'>$st</span><span class='auth-badge' style='background:${auth_clr}20;color:${auth_clr}'>$auth</span></div></div></div>")"$'\n'
        else
            auth="Blocked"
            auth_clr="#fbbf24"
            blocked_entries="${blocked_entries}$(echo "<div class='device'><div class='icon'>📱</div><div class='info'><div class='devname'>$devname $edit_link</div><div class='mac'>$mac</div><div class="ip">$client_ip</div><div class='usage'>$usage_str</div><div class='status-line'><span class='arp-state' style='color:$clr'>$st</span><span class='auth-badge' style='background:${auth_clr}20;color:${auth_clr}'>$auth</span></div></div></div>")"$'\n'
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
<link rel="stylesheet" href="/nexora/admin.css">
<script>
function toggleVouchers() {
    var x = document.getElementById("voucherTable");
    var btn = document.getElementById("toggleBtn");
    if (x.style.display === "none") {
        x.style.display = "block";
        btn.innerText = "🔽 Hide Voucher Keys";
    } else {
        x.style.display = "none";
        btn.innerText = "🔽 Hide Voucher Keys";
    }
}
</script>
</head>
<body>
<div class="header">
  <div class="header-left">
    <div class="wifi-icon">
      <svg viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="glow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" style="stop-color:#a78bfa;stop-opacity:0.8"/>
            <stop offset="100%" style="stop-color:#06ffd4;stop-opacity:0"/>
          </radialGradient>
          <filter id="blur"><feGaussianBlur stdDeviation="1.5"/></filter>
        </defs>
        <style>
          .s1{animation:sa 2.5s infinite ease-out;animation-delay:0s;opacity:0;stroke:#06ffd4}
          .s2{animation:sa 2.5s infinite ease-out;animation-delay:0.5s;opacity:0;stroke:#a78bfa}
          .s3{animation:sa 2.5s infinite ease-out;animation-delay:1s;opacity:0;stroke:#60a5fa}
          @keyframes sa{0%{opacity:0}20%{opacity:1}100%{opacity:0}}
          .core{animation:pulse2 1.5s infinite;fill:#06ffd4}
          @keyframes pulse2{0%,100%{opacity:1}50%{opacity:0.5}}
          .ring{animation:spin 8s linear infinite;transform-origin:30px 30px}
          @keyframes spin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}
          .dot1{animation:blink2 1s infinite;fill:#06ffd4}
          .dot2{animation:blink2 1s infinite;animation-delay:0.3s;fill:#a78bfa}
          .dot3{animation:blink2 1s infinite;animation-delay:0.6s;fill:#60a5fa}
          @keyframes blink2{0%,100%{opacity:1}50%{opacity:0.2}}
        </style>
        <circle cx="30" cy="30" r="25" fill="url(#glow)" filter="url(#blur)"/>
        <g class="ring">
          <circle cx="30" cy="8" r="2" fill="#a78bfa" opacity="0.6"/>
          <circle cx="52" cy="30" r="2" fill="#06ffd4" opacity="0.6"/>
          <circle cx="30" cy="52" r="2" fill="#60a5fa" opacity="0.6"/>
          <circle cx="8" cy="30" r="2" fill="#a78bfa" opacity="0.6"/>
        </g>
        <path class="s1" d="M20,34 Q30,24 40,34" fill="none" stroke-linecap="round"/>
        <path class="s2" d="M15,28 Q30,14 45,28" fill="none" stroke-linecap="round"/>
        <path class="s3" d="M10,22 Q30,4 50,22" fill="none" stroke-linecap="round"/>
        <circle class="core" cx="30" cy="38" r="4"/>
        <circle class="dot1" cx="22" cy="50" r="2.5"/>
        <circle class="dot2" cx="30" cy="50" r="2.5"/>
        <circle class="dot3" cx="38" cy="50" r="2.5"/>
      </svg>
    </div>
    <h1>NEXORA</h1>
  </div>
  <div class="status"><span class="status-dot"></span> ${NDS_STATUS}</div>
</div>
HEADER

# Stats variables
STALE_COUNT=$(ip neigh show dev br-hotspot 2>/dev/null | grep -v 'fe80' | grep 'lladdr' | grep 'STALE' | wc -l)
ONLINE=$(ip neigh show dev br-hotspot 2>/dev/null | grep -v 'fe80' | grep 'lladdr' | grep 'REACHABLE\|DELAY' | wc -l)

cat << STATS
<div class="temp-full">
  <div class="temp-bar"><span class="temp-label">2.4 GHz</span><span class="temp-val">$TEMP_2G</span></div>
  <div class="temp-bar"><span class="temp-label">5 GHz (R0)</span><span class="temp-val">$TEMP_5G0</span></div>
  <div class="temp-bar"><span class="temp-label">5 GHz (R2)</span><span class="temp-val">$TEMP_5G1</span></div>
</div>
<div class="stats">
<div class="card"><div class="num">$total_v</div><div class="lbl">Total Keys</div></div>
<div class="card"><div class="num">$free_v</div><div class="lbl">Free</div></div>
<div class="card"><div class="num">$locked_v</div><div class="lbl">Locked</div></div>
<div class="card"><div class="num">$trusted_m</div><div class="lbl">Trusted MACs</div></div>
<div class="card"><div class="num">$ONLINE</div><div class="lbl">Online Now</div></div>
<div class="card"><div class="num">$STALE_COUNT</div><div class="lbl">Stale</div></div>
</div>
STATS

# ---------- Name edit form ----------
EDIT_MAC=""
if echo "$QUERY_STRING" | grep -q "editname="; then
    EDIT_MAC=$(echo "$QUERY_STRING" | sed -n 's/.*editname=\([^&]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
    CURRENT_NAME=$(get_name "$EDIT_MAC")
    # Fallback to DHCP hostname if no custom name
    if [ -z "$CURRENT_NAME" ] && [ -f /tmp/dhcp.leases ]; then
        CURRENT_NAME=$(grep -i "$EDIT_MAC" /tmp/dhcp.leases | awk '{print $4}' | head -1)
    fi
    # Final fallback to MAC
    [ -z "$CURRENT_NAME" ] && CURRENT_NAME="$EDIT_MAC"
    echo "<div class='edit-form'>"
    echo "<strong style='color:#38bdf8;'>✏️ Set Name for $EDIT_MAC</strong>"
    echo "<form method='post' style='display:flex; gap:10px; align-items:center; margin-top:8px;'>"
    echo "<input type='hidden' name='action' value='setname'>"
    echo "<input type='hidden' name='mac' value='$EDIT_MAC'>"
    echo "<input type='text' name='name' value='$CURRENT_NAME' placeholder='Enter device/user name' style='flex:1;'>"
    echo "<button class='btn btn-primary' type='submit'>Save</button>"
    echo "<a href='admin.sh?pass=$ADMIN_PASS' class='btn' style='background:#475569;'>Cancel</a>"
    echo "</form></div>"
fi

# ---------- Authenticated Devices ----------
echo "<div class='section'><h2>🟢 Authenticated Devices (Live Bandwidth)</h2>"
if [ -n "$auth_entries" ]; then
    echo "$auth_entries"
else
    echo "<p style='color:#64748b;'>No authenticated devices at the moment.</p>"
fi
echo "</div>"

# ---------- Blocked Devices ----------
echo "<div class='section'><h2>🟡 Pre‑auth / Blocked Devices</h2>"
if [ -n "$blocked_entries" ]; then
    echo "$blocked_entries"
else
    echo "<p style='color:#64748b;'>All connected devices are authenticated.</p>"
fi
echo "</div>"

# ---------- Trusted MACs (with Name column) ----------
echo "<div class='section'><h2>⏳ Trusted MACs & Remaining Days</h2><table><tr><th>Name</th><th>MAC</th><th>Voucher</th><th>Days Left</th><th>Remove</th></tr>"
NOW=$(date +%s)
VALIDITY=2592000
grep "LOCKED-" "$VOUCHER_FILE" | while read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    mac=$(echo "$line" | sed -n 's/.*LOCKED-\([0-9a-fA-F:]*\)-.*/\1/p')
    start=$(echo "$line" | sed -n 's/.*LOCKED-[^-]*-\([0-9]*\).*/\1/p')
    expire=$(echo "$line" | sed -n 's/.*-EXP-\([0-9]*\)$/\1/p')
    [ -z "$expire" ] && expire=$((start + 2592000))
    remaining=$(( (expire - NOW) / 86400 ))
    devname=$(get_name "$mac")
    phone=$(grep "|${mac}|" "/etc/nodogsplash/requests.txt" | tail -1 | cut -d"|" -f2)
    [ -z "$phone" ] && phone="$devname"
    [ -z "$phone" ] && phone="-"
    [ -z "$devname" ] && devname="-"
    echo "<tr><td>$phone</td><td>$mac</td><td>$key</td><td>${remaining} days</td><td><form method='post'><input type='hidden' name='action' value='delmac'><input type='hidden' name='mac' value='$mac'><button class='btn btn-danger' style='padding:6px 12px;'>Remove</button></form></td></tr>"
done
echo "</table></div>"

# ---------- Voucher Keys ----------
echo "<div class='section'><h2>🔑 Voucher Keys <button id='toggleBtn' class='toggle-btn' onclick='toggleVouchers()'>🔽 Hide Voucher Keys</button></h2><div id='voucherTable' style='display:none'><table><tr><th>Key</th><th>Status</th><th>Used by MAC</th><th>Action</th></tr>"
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
echo "<div class='section'><h2>🔑 Generate Voucher Keys</h2><form method='post'><input type='hidden' name='action' value='genkeys'><label style='color:#cbd5e1;'>Kitni keys:</label> <input type='number' name='keycount' value='5' min='1' max='50' style='padding:8px;border-radius:8px;border:1px solid #38bdf8;background:#0f172a;color:white;width:80px;margin:0 10px;'> <button type='submit' class='btn' style='width:auto;padding:10px 20px;background:#7c3aed;'>Generate</button></form></div>"
echo "<div class='section'><h2>⏱️ Custom Time Access</h2>"
echo "<form method='post' style='display:flex;gap:10px;flex-wrap:wrap;align-items:center;'>"
echo "<input type='hidden' name='action' value='customtime'>"
echo "<input type='text' name='custommac' placeholder='MAC Address' style='padding:10px;border-radius:10px;border:1px solid #38bdf8;background:#0f172a;color:white;flex:2;min-width:160px;'>"
echo "<input type='number' name='customval' value='1' min='1' max='9999' style='padding:10px;border-radius:10px;border:1px solid #38bdf8;background:#0f172a;color:white;width:80px;'>"
echo "<select name='customunit' style='padding:10px;border-radius:10px;border:1px solid #38bdf8;background:#0f172a;color:white;'><option value='m'>Minutes</option><option value='h'>Hours</option><option value='d' selected>Days</option></select>"
echo "<input type='text' name='customname' placeholder='Name optional' style='padding:10px;border-radius:10px;border:1px solid #38bdf8;background:#0f172a;color:white;flex:2;'>"
echo "<button type='submit' class='btn btn-primary' style='width:auto;padding:10px 20px;'>✅ Give Access</button></form></div>"
echo "<div class='actions'>"
echo "<form method='post' onsubmit=\"return confirm('Restart NoDogSplash?')\"><input type='hidden' name='action' value='restart_nds'><button class='btn btn-primary' type='submit'>🔄 Restart NDS</button></form>"
echo "<form method='post' onsubmit=\"return confirm('Stop NoDogSplash? All hotspot access will be blocked.')\"><input type='hidden' name='action' value='stop_nds'><button class='btn btn-warn' type='submit'>⏹️ Stop NDS</button></form>"
echo "<form method='post' onsubmit=\"return confirm('Disable Hotspot interface? Internet on hotspot will go down completely.')\"><input type='hidden' name='action' value='disable_hotspot'><button class='btn btn-danger' type='submit'>📴 Disable Hotspot</button></form>"
echo "<form method='post' onsubmit=\"return confirm('Reboot the router?')\"><input type='hidden' name='action' value='reboot'><button class='btn btn-danger' type='submit'>⏻ Reboot</button></form>"
echo "<a href='admin.sh?pass=$ADMIN_PASS' class='btn btn-primary' style='background:#475569;'>🔁 Refresh Page</a>"
echo "</div>"

echo "</body></html>"
