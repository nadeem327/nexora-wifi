#!/bin/sh
ADMIN_PASS="CHANGE_ME_ADMIN_PASS"
NAMES_FILE="/etc/nodogsplash/device_names.txt"
TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"
BW_FILE="/etc/nodogsplash/nlbwmon_total.txt"
echo "Content-type: text/html"
echo ""
NTAGE=$(( $(date +%s) - $(cut -d"|" -f1 /tmp/node_temp.txt 2>/dev/null || echo 0) ))
[ "$NTAGE" -gt 60 ] && /usr/bin/node_temp_fetch.sh >/dev/null 2>&1 &
PASS=$(echo "$QUERY_STRING" | sed -n 's/.*pass=\([^&]*\).*/\1/p')
if [ "$PASS" != "$ADMIN_PASS" ]; then
cat << 'LOGIN'
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Nexora WiFi Admin</title><style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',sans-serif;background:#0f172a;display:flex;justify-content:center;align-items:center;height:100vh}
.card{background:#1e293b;padding:40px;border-radius:24px;box-shadow:0 20px 50px rgba(0,0,0,.6);text-align:center;width:90%;max-width:360px}
h2{color:#a78bfa;margin-bottom:25px;font-size:1.4rem;letter-spacing:.1em}
input{width:100%;padding:14px;margin:10px 0;border-radius:14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.05);color:white;font-size:1rem;box-sizing:border-box}
button{width:100%;padding:14px;border:none;border-radius:14px;background:linear-gradient(135deg,#7c3aed,#a78bfa);color:white;font-weight:bold;font-size:1rem;cursor:pointer}
</style></head>
<body><div class="card"><h2>Nexora WiFi ADMIN</h2><form method="get"><input type="password" name="pass" placeholder="Password"><button type="submit">Login</button></form></div></body></html>
LOGIN
exit 0
fi
# ---------- Helper functions ----------
human_bytes() {
    bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$bytes" | awk "{printf \"%.1f GB\", \$1/1073741824}"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes/1048576)) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes/1024)) KB"
    else
        echo "$bytes B"
    fi
}
get_manufacturer() {
    mac=$(echo "$1" | tr "[:upper:]" "[:lower:]")
    cached=$(grep -i "^$mac|" /etc/nodogsplash/mac_manufacturers.txt 2>/dev/null | cut -d"|" -f2)
    if [ -n "$cached" ]; then
        echo "$cached"
        return
    fi
    (
        result=$(curl -s --max-time 3 "https://api.maclookup.app/v2/macs/$mac" 2>/dev/null)
        isRand=$(echo "$result" | sed -n "s/.*\"isRand\":\([^,}]*\).*/\1/p")
        company=$(echo "$result" | sed -n "s/.*\"company\":\"\([^\"]*\)\".*/\1/p")
        [ "$isRand" = "true" ] && company="🔒 Private"
        [ -z "$company" ] && company="❓ Unknown"
        grep -qi "^$mac|" /etc/nodogsplash/mac_manufacturers.txt 2>/dev/null || echo "$mac|$company" >> /etc/nodogsplash/mac_manufacturers.txt
    ) &
    echo "❓ Looking up..."
}
get_name() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    grep -i "^$mac|" "$NAMES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2-
}
get_wifi_band() {
    local mac=$(echo "$1" | tr "[:upper:]" "[:lower:]")
    local band=$(awk -v m="$mac" 'tolower($1)==m {print $3}' /tmp/wifi_signal_cache.txt 2>/dev/null | tail -1)
    if [ "$band" = "5GHz" ]; then
        echo "<span style=\"color:#a855f7;font-size:0.7rem;\">5GHz</span>"
    elif [ "$band" = "2.4GHz" ]; then
        echo "<span style=\"color:#22c55e;font-size:0.7rem;\">2.4GHz</span>"
    elif [ "$band" = "Node-5GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 5GHz</span>"
    elif [ "$band" = "Node-2.4GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 2.4GHz</span>"
    elif [ "$band" = "Node-5GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 5GHz</span>"
    elif [ "$band" = "Node-2.4GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 2.4GHz</span>"
    elif [ "$band" = "Node-5GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 5GHz</span>"
    elif [ "$band" = "Node-2.4GHz" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node &middot; 2.4GHz</span>"
    elif [ "$band" = "Node" ]; then
        echo "<span style=\"color:#eab308;font-size:0.7rem;\">Node</span>"
    else
        echo "<span style=\"color:#64748b;font-size:0.7rem;\">—</span>"
    fi
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
    if [ "$action" = "settheme" ]; then
        THEME=$(echo "$POST_DATA" | sed -n 's/.*theme=\([a-z]*\).*/\1/p')
        if [ "$THEME" = "light" ] || [ "$THEME" = "dark" ]; then
            echo "$THEME" > /tmp/jaat_admin_theme
        fi
        echo "<script>window.location='admin.sh?pass=$ADMIN_PASS';</script>"
        exit 0
    elif [ "$action" = "delmac" ] && [ -n "$mac" ]; then
        sed -i "/^$mac$/d" "$TRUSTED_FILE"
        sed -i "/LOCKED-$mac-/d" "$VOUCHER_FILE"
        ndsctl deauth "$mac" 2>/dev/null
        ndsctl untrust "$mac" 2>/dev/null
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
        printf '%s Cleartext-Password := "%s"\n    Session-Timeout = 2592000,\n    Reply-Message = "Welcome to Nexora WiFi"\n' "$key" "$key" >> "/etc/freeradius3/mods-config/files/authorize"
        kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
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
            printf '%s Cleartext-Password := "%s"\n    Session-Timeout = 2592000,\n    Reply-Message = "Welcome to Nexora WiFi"\n' "$key" "$key" >> "/etc/freeradius3/mods-config/files/authorize"
            generated="$generated $key"
            kill -HUP $(ps | grep radiusd | grep -v grep | awk '{print $1}') 2>/dev/null
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
    NDS_STATUS="Active"; BDGC="badge-green"; DOTC="dot-g"
else
    NDS_STATUS="Down"; BDGC="badge-red"; DOTC="dot-r"
fi
# ---------- Temperature sensors ----------
TEMP_2G=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G0=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
TEMP_5G1=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | awk '{printf "%.1f°C", $1/1000}')
. /usr/bin/node_temp_calc.sh
[ -z "$TEMP_2G" ] && TEMP_2G="N/A"
[ -z "$TEMP_5G0" ] && TEMP_5G0="N/A"
[ -z "$TEMP_5G1" ] && TEMP_5G1="N/A"
# ---------- Mesh Status ----------
# ---------- ARP + Bandwidth ----------
arp_all=$(ip neigh show dev br-hotspot 2>/dev/null | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v 'fe80' | grep 'REACHABLE\|STALE\|DELAY')
ONLINE=0
[ -n "$arp_all" ] && ONLINE=$(echo "$arp_all" | grep -c "REACHABLE")
STALE_COUNT=$(echo "$arp_all" | grep -c 'STALE')
auth_entries=""
blocked_entries=""
seen_macs=""
NLBW_ALL=$(nlbw -c json -g mac 2>/dev/null)
iwinfo phy0-ap1 assoclist 2>/dev/null | awk '/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/{print tolower($1)}' > /tmp/wifi_5g.txt
iwinfo phy1-ap1 assoclist 2>/dev/null | awk '/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/{print tolower($1)}' > /tmp/wifi_24g.txt
if [ -n "$arp_all" ]; then
    while read -r client_ip _ mac state; do
        echo "$seen_macs" | grep -qw "$mac" && continue
        seen_macs="$seen_macs $mac"
        st=$state
        case "$st" in
            REACHABLE) badge_cls="cg" ;;
            STALE) badge_cls="cy2" ;;
            *) badge_cls="cb" ;;
        esac
        total_bytes=0
        if [ -f "$BW_FILE" ]; then
            total_bytes=$(grep -i "^$mac " "$BW_FILE" | tail -1 | awk '{print $2}')
            [ -z "$total_bytes" ] && total_bytes=0
        fi
        nlbw_line=$(echo "$NLBW_ALL" | grep -o "\"$mac\",[0-9]*,[0-9]*,[0-9]*,[0-9]*,[0-9]*")
        if [ -n "$nlbw_line" ]; then
            rx_b=$(echo "$nlbw_line" | cut -d',' -f3)
            tx_b=$(echo "$nlbw_line" | cut -d',' -f5)
            down_bytes=$(human_bytes ${rx_b:-0})
            up_bytes=$(human_bytes ${tx_b:-0})
            usage_str="⚡ Live: ${down_bytes:-0 B} down / ${up_bytes:-0 B} up"
        else
            usage_str="Data Usage: 0 B"
        fi
        devname=$(get_name "$mac")
        if [ -z "$devname" ]; then
            spinline=$(grep "^Nexora-[123]H-[^ ]* LOCKED-$mac-" "$VOUCHER_FILE" 2>/dev/null | tail -n1)
            spin_ok=0
            if [ -n "$spinline" ]; then
                sexp=$(printf '%s' "$spinline" | sed -n 's/.*-EXP-//p')
                case "$sexp" in ''|*[!0-9]*) sexp="" ;; esac
                [ -n "$sexp" ] && [ "$sexp" -gt "$(date +%s)" ] && spin_ok=1
            fi
            if [ "$spin_ok" -eq 1 ]; then
                case "$spinline" in
                    Nexora-1H-*) devname="&#127920; Spin 1 Ghanta" ;;
                    Nexora-2H-*) devname="&#127920; Spin 2 Ghante" ;;
                    Nexora-3H-*) devname="&#127920; Spin 3 Ghante" ;;
                esac
            else
                devname="$mac"
            fi
        fi
        edit_link="<a href='admin.sh?pass=$ADMIN_PASS&editname=$mac' style='color:#a78bfa;text-decoration:none;'>✏️</a>"
        card_open="<div class='device-card' style='border:1px solid rgba(0,245,255,.2);border-radius:16px;padding:14px 16px;margin-bottom:10px;background:rgba(0,20,30,.5);box-shadow:0 0 10px rgba(0,245,255,.06);'>"
        spinlive=0
        SLINE=$(grep "^Nexora-[123]H-.*LOCKED-$mac-" "$VOUCHER_FILE" 2>/dev/null | tail -n1)
        [ -n "$SLINE" ] && { SEXP=$(printf '%s' "$SLINE" | sed -n 's/.*-EXP-//p'); case "$SEXP" in ''|*[!0-9]*) SEXP="";; esac; [ -n "$SEXP" ] && [ "$SEXP" -gt "$(date +%s)" ] && spinlive=1; }
        if [ "$spinlive" -eq 1 ] || grep -qi "^$mac$" "$TRUSTED_FILE" 2>/dev/null; then
                        auth_entries="${auth_entries}${card_open}
<div style='display:flex;justify-content:space-between;align-items:center;'><div style='font-weight:700;font-size:.95rem;'>${devname}</div><div style='display:flex;align-items:center;gap:8px;'><span style='font-size:.75rem;color:#22c55e;'>$(get_wifi_band "$mac")</span><div data-signal='${mac}'></div></div></div>
<div style='font-family:monospace;font-size:.7rem;color:#64748b;margin-top:4px;'>${mac} · $(get_manufacturer "$mac") · ${client_ip}</div>
<div style='margin-top:6px;font-size:.75rem;color:#22d3ee;font-weight:600;' data-usage='${mac}'>${usage_str}</div>
<div style='margin-top:6px;'><span class='chip ${badge_cls}' data-status='${mac}'>${st}</span></div>
<div style='display:flex;justify-content:space-between;align-items:center;margin-top:8px;'><div><a href='admin.sh?pass=$ADMIN_PASS&editname=${mac}' class='btn bc bsm' style='text-decoration:none;display:inline-block;'>Rename</a></div><span class='chip cg'>🟢 Auth</span></div>
</div>"$'\n'
        else
            trial_form() {
                echo "<form method='post' style='display:inline;margin:0'><input type='hidden' name='action' value='customtime'><input type='hidden' name='custommac' value='${mac}'><input type='hidden' name='customval' value='$1'><input type='hidden' name='customunit' value='$2'><button type='submit' class='btn bg bsm'>$3</button></form>"
            }
            blocked_entries="${blocked_entries}${card_open}
<div style='display:flex;justify-content:space-between;align-items:center;'><div style='font-weight:700;font-size:.95rem;'>${devname}</div><div style='display:flex;align-items:center;gap:8px;'><span style='font-size:.75rem;color:#22c55e;'>$(get_wifi_band "$mac")</span><div data-signal='${mac}'></div></div></div>
<div style='font-family:monospace;font-size:.7rem;color:#64748b;margin-top:4px;'>${mac} · $(get_manufacturer "$mac") · ${client_ip}</div>
<div style='margin-top:6px;font-size:.75rem;color:#22d3ee;font-weight:600;' data-usage='${mac}'>${usage_str}</div>
<div style='margin-top:6px;'><span class='chip ${badge_cls}' data-status='${mac}'>${st}</span></div>
<div style='display:flex;justify-content:space-between;align-items:center;margin-top:8px;'><div style='display:flex;gap:6px;flex-wrap:wrap;'>$(trial_form 15 m 15m)$(trial_form 30 m 30m)$(trial_form 1 h 1h)$(trial_form 1 d 1day)<a href='admin.sh?pass=$ADMIN_PASS&editname=${mac}' class='btn bg bsm' style='text-decoration:none;display:inline-block;'>Rename</a></div><span class='chip cy2'>🟡 Pre-auth</span></div>
</div>"$'\n'
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
<title>Nexora WiFi Admin</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',monospace,sans-serif;background:#05070d;color:#e2e8f0;min-height:100vh;padding:12px}
.hdr{background:linear-gradient(135deg,rgba(0,20,30,.9),rgba(30,0,50,.9));border-radius:20px;padding:16px 20px;margin-bottom:12px;display:flex;align-items:center;justify-content:space-between;border:1px solid rgba(0,245,255,.5);box-shadow:0 0 24px rgba(0,245,255,.2),inset 0 0 20px rgba(0,245,255,.05);gap:8px;flex-wrap:wrap}
.logo{font-size:1.15rem;font-weight:900;letter-spacing:.2em;background:linear-gradient(90deg,#00f5ff,#ff00ea);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;text-shadow:0 0 20px rgba(0,245,255,.5)}
.sublabel{font-size:8px;color:#00f5ff;letter-spacing:.25em;margin-top:2px;opacity:.7;font-family:monospace}
.badge{display:inline-flex;align-items:center;gap:5px;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:700}
.badge-green{background:rgba(0,255,136,.08);color:#00ff88;border:1px solid rgba(0,255,136,.5);text-shadow:0 0 6px #00ff88;font-family:monospace}
.badge-red{background:rgba(255,0,85,.08);color:#ff0055;border:1px solid rgba(255,0,85,.5);text-shadow:0 0 6px #ff0055;font-family:monospace}
.dot{width:6px;height:6px;border-radius:50%;animation:pulse 1.5s infinite}
.dot-g{background:#00ff88;box-shadow:0 0 10px #00ff88,0 0 20px #00ff88}
.dot-r{background:#ff0055;box-shadow:0 0 10px #ff0055,0 0 20px #ff0055}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.4;transform:scale(1.3)}}
body::before{content:'';position:fixed;top:0;left:0;right:0;bottom:0;background:radial-gradient(circle at 20% 10%,rgba(0,245,255,.08),transparent 40%),radial-gradient(circle at 80% 90%,rgba(255,0,234,.08),transparent 40%),linear-gradient(rgba(0,245,255,.03) 1px,transparent 1px),linear-gradient(90deg,rgba(0,245,255,.03) 1px,transparent 1px);background-size:100% 100%,100% 100%,30px 30px,30px 30px;pointer-events:none;z-index:0}
body>*{position:relative;z-index:1}
.temp-row{display:flex;gap:8px;margin-bottom:12px}
.tc{flex:1;background:rgba(0,20,30,.7);border-radius:14px;padding:12px;text-align:center;border:1px solid rgba(0,245,255,.25);backdrop-filter:blur(10px);box-shadow:0 0 12px rgba(0,245,255,.05)}
.tc-lbl{font-size:8px;color:#00f5ff;letter-spacing:.15em;text-transform:uppercase;margin-bottom:4px;font-family:monospace;opacity:.7}
.tc-val{font-size:1.05rem;font-weight:900;font-family:monospace;letter-spacing:.05em;text-shadow:0 0 10px currentColor}
.t-or{color:#ff8a00}.t-cy{color:#00f5ff}.t-re{color:#ff0055}
.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}
.sc{background:rgba(10,15,25,.8);border-radius:16px;padding:16px 8px;text-align:center;border:1px solid rgba(0,245,255,.25);position:relative;overflow:hidden;box-shadow:0 0 12px rgba(0,245,255,.05)}
.sn{font-size:1.65rem;font-weight:900;font-family:monospace;line-height:1;letter-spacing:.03em;text-shadow:0 0 15px currentColor}
.sl{font-size:8px;color:#00f5ff;text-transform:uppercase;letter-spacing:.2em;margin-top:5px;opacity:.7;font-family:monospace}
.np{color:#ff00ea}.ng{color:#00ff88}.ny{color:#ffcc00}.nc{color:#00f5ff}.nr{color:#ff0055}
.acts{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.sec{background:rgba(10,15,25,.7);border-radius:16px;padding:16px;margin-bottom:12px;border:1px solid rgba(0,245,255,.2);backdrop-filter:blur(8px);box-shadow:0 0 15px rgba(0,245,255,.05)}
.tabs{display:flex;gap:4px;background:rgba(0,10,20,.6);border:1px solid rgba(0,245,255,.2);border-radius:12px;padding:4px;margin-bottom:14px}
.tab{flex:1;padding:8px;border-radius:8px;font-size:10px;font-weight:700;text-align:center;cursor:pointer;color:#00f5ff;letter-spacing:.1em;text-transform:uppercase;border:none;background:none;transition:all .2s;font-family:monospace;opacity:.7}
.tab.on{background:linear-gradient(135deg,#ff00ea,#00f5ff);color:#000;opacity:1;box-shadow:0 0 12px rgba(0,245,255,.5)}
.tc2{display:none}.tc2.on{display:block}
.fr{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:4px}
input[type=text],input[type=number],select{background:rgba(0,20,30,.7);border:1px solid rgba(0,245,255,.25);border-radius:12px;padding:10px 14px;color:#00f5ff;font-size:13px;outline:none;font-family:monospace}
input:focus,select:focus{border-color:#00f5ff;box-shadow:0 0 12px rgba(0,245,255,.4)}
input::placeholder{color:rgba(0,245,255,.4)}
.iv{flex:1;min-width:130px}.is{width:68px}
.btn{padding:10px 16px;border:none;border-radius:12px;font-size:11px;font-weight:700;cursor:pointer;letter-spacing:.05em;text-transform:uppercase;transition:all .15s;white-space:nowrap}
.btn:hover{opacity:.85;transform:translateY(-1px)}
.bp{background:linear-gradient(135deg,#ff00ea,#00f5ff);color:#000;box-shadow:0 0 14px rgba(255,0,234,.4)}
.bg{background:linear-gradient(135deg,#00cc7a,#00ff88);color:#000;box-shadow:0 0 14px rgba(0,255,136,.35)}
.bc{background:linear-gradient(135deg,#00b3cc,#00f5ff);color:#000;box-shadow:0 0 14px rgba(0,245,255,.35)}
.br{background:rgba(255,0,85,.1);color:#ff0055;border:1px solid rgba(255,0,85,.5);text-shadow:0 0 6px #ff0055}
.bo{background:rgba(255,204,0,.1);color:#ffcc00;border:1px solid rgba(255,204,0,.5);text-shadow:0 0 6px #ffcc00}
.bsm{padding:5px 10px;font-size:10px;border-radius:8px}
.tw{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:12px}
th{font-size:9px;font-weight:700;letter-spacing:.15em;color:#00f5ff;text-transform:uppercase;padding:8px 10px;text-align:left;border-bottom:1px solid rgba(0,245,255,.3);opacity:.8;font-family:monospace}
td{padding:10px;border-bottom:1px solid rgba(0,245,255,.08);vertical-align:middle}
tr:hover td{background:rgba(0,245,255,.05)}
.mo{font-family:monospace;font-size:11px}
.chip{display:inline-block;padding:2px 8px;border-radius:20px;font-size:9px;font-weight:700}
.cg{background:rgba(0,255,136,.1);color:#00ff88;border:1px solid rgba(0,255,136,.5);text-shadow:0 0 6px #00ff88;font-family:monospace}
.cy2{background:rgba(255,204,0,.1);color:#ffcc00;border:1px solid rgba(255,204,0,.5);text-shadow:0 0 6px #ffcc00;font-family:monospace}
.cr{background:rgba(255,0,85,.1);color:#ff0055;border:1px solid rgba(255,0,85,.5);text-shadow:0 0 6px #ff0055;font-family:monospace}
.cb{background:rgba(0,245,255,.1);color:#00f5ff;border:1px solid rgba(0,245,255,.5);text-shadow:0 0 6px #00f5ff;font-family:monospace}
.stitle{font-size:10px;font-weight:700;letter-spacing:.25em;color:#00f5ff;text-transform:uppercase;margin-bottom:10px;display:flex;align-items:center;gap:6px;text-shadow:0 0 8px #00f5ff;font-family:monospace}
.stitle::after{content:'';flex:1;height:1px;background:linear-gradient(90deg,rgba(0,245,255,.5),transparent)}
.edit-form{background:rgba(0,20,30,.7);border:1px solid rgba(0,245,255,.3);border-radius:14px;padding:12px 14px;margin-bottom:12px;box-shadow:0 0 12px rgba(0,245,255,.05)}
#watchChatAdmin{background:rgba(0,20,30,.85);border:1px solid rgba(0,245,255,.2);border-radius:10px;padding:10px;height:220px;overflow-y:auto;font-size:13px}

/* ===== LIGHT THEME ===== */
body.light{color:#1e1b4b!important;background:#f0f4f8!important}
html.light body{color:#1e1b4b!important;background:#f0f4f8!important}
body.light::before{background-image:radial-gradient(ellipse at 20% 0%,rgba(124,58,237,.28),transparent 55%),radial-gradient(ellipse at 80% 100%,rgba(8,145,178,.28),transparent 55%),radial-gradient(ellipse at 50% 50%,rgba(236,72,153,.1),transparent 60%)!important;background-size:100% 100%!important}
body.light .hdr,body.light .sec,body.light .card,body.light .stitle,body.light .device,body.light .device-card,body.light .temp-row,body.light .tc,body.light .stats .card,body.light .stats,body.light .edit-form,body.light #watchChatAdmin,body.light .wcBox,body.light .meshMap,body.light .meshRow{background:#ffffff!important;border-color:#e2e8f0!important;box-shadow:0 4px 16px rgba(15,23,42,0.08)!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
body.light .sc{background:#ffffff!important;border-color:#e2e8f0!important;box-shadow:0 4px 16px rgba(15,23,42,0.08)!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
body.light .tw{background:#ffffff!important;border-color:#e2e8f0!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
body.light .device{background:#ffffff!important;border-color:#e2e8f0!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
body.light .hdr{background:#ffffff!important;border-color:#e2e8f0!important;box-shadow:0 4px 16px rgba(124,58,237,0.12)!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
body.light .logo{background:linear-gradient(90deg,#7c3aed,#0891b2,#ec4899)!important;-webkit-background-clip:text!important;-webkit-text-fill-color:transparent!important;background-clip:text!important;font-weight:900!important;letter-spacing:.15em!important}
body.light .sublabel{color:#64748b!important;letter-spacing:.2em!important;font-weight:600!important}
body.light .badge,body.light .badge-green,body.light .badge-yellow,body.light .badge-red{background:rgba(255,255,255,.75)!important;border-color:rgba(255,255,255,.85)!important;box-shadow:0 2px 8px rgba(5,150,105,0.15)!important}
body.light .badge-green{color:#059669!important}
body.light .badge-green .dot,body.light .badge-green .dot-g{background:#22c55e!important}
body.light .tc-lbl,body.light .tc-val,body.light .temp-lbl,body.light .temp-val,body.light .stitle{color:#334155!important}
body.light .tc-val,body.light .stats .card .num,body.light .sc .sn{color:#0f172a!important;-webkit-text-fill-color:#0f172a!important}
body.light .tc-val.t-cy,body.light .stats .card .num{background:none!important;-webkit-text-fill-color:#0891b2!important;color:#0891b2!important;font-weight:900!important}
body.light .tc-val.t-or{background:none!important;-webkit-text-fill-color:#ea580c!important;color:#ea580c!important;font-weight:900!important}
body.light .tc-val.t-re{background:none!important;-webkit-text-fill-color:#dc2626!important;color:#dc2626!important;font-weight:900!important}
body.light .tc-val.np{background:none!important;-webkit-text-fill-color:#7c3aed!important;color:#7c3aed!important;font-weight:900!important}
body.light h1,body.light h2,body.light .sec h2,body.light .stitle,body.light td,body.light th,body.light .tc-lbl,body.light .chip,body.light .badge,body.light .sn,body.light .sl,body.light .mo,body.light .stitle::after{color:#334155!important}
body.light .device .info .devname{color:#0f172a!important}
body.light .device .info .mac,body.light .device .info .mfr,body.light .device .info .ip{color:#64748b!important}
body.light .device .info .band,body.light .device .info .usage,body.light .device .info .signal{color:#475569!important}
body.light .chip.cg,body.light .chip.cy,body.light .chip.cy2{background:rgba(16,185,129,0.15)!important;color:#059669!important;border-color:rgba(16,185,129,0.4)!important;font-weight:700!important}
body.light .chip.cr{background:rgba(220,38,38,0.12)!important;color:#dc2626!important;border-color:rgba(220,38,38,0.35)!important;font-weight:700!important}
body.light .chip.cb{background:rgba(8,145,178,0.15)!important;color:#0891b2!important;border-color:rgba(8,145,178,0.4)!important;font-weight:700!important}
body.light .chip.cu,body.light .chip.cd{background:rgba(139,92,246,0.15)!important;color:#6d28d9!important;border-color:rgba(139,92,246,0.4)!important}
body.light .btn{background:#ffffff!important;color:#334155!important;border:1px solid #e2e8f0!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important;box-shadow:0 2px 6px rgba(15,23,42,0.06)!important}
body.light .btn:hover{background:#f8fafc!important;box-shadow:0 4px 12px rgba(15,23,42,0.1)!important}
body.light .btn.bp,body.light .btn-primary{background:linear-gradient(135deg,#7c3aed,#0891b2)!important;color:#ffffff!important;border-color:transparent!important;box-shadow:0 4px 14px rgba(124,58,237,0.35)!important}
body.light .btn.bp:hover,body.light .btn-primary:hover{background:linear-gradient(135deg,#6d28d9,#0e7490)!important;box-shadow:0 4px 16px rgba(139,92,246,0.35)!important}
body.light .btn.br,body.light .btn-danger{background:#ffffff!important;color:#dc2626!important;border-color:rgba(239,68,68,0.3)!important}
body.light .btn.br:hover,body.light .btn-danger:hover{background:#fef2f2!important;box-shadow:0 4px 16px rgba(239,68,68,0.15)!important}
body.light .btn.bg{background:linear-gradient(135deg,#059669,#10b981)!important;color:#fff!important;border-color:transparent!important;box-shadow:0 4px 14px rgba(16,185,129,0.35)!important}
body.light .btn.bg:hover{background:#ecfdf5!important;box-shadow:0 4px 16px rgba(34,197,94,0.15)!important}
body.light .btn.bc{background:linear-gradient(135deg,#0891b2,#06b6d4)!important;color:#fff!important;border-color:transparent!important;box-shadow:0 4px 14px rgba(8,145,178,0.35)!important}
body.light .btn.bc:hover{background:#eff6ff!important;box-shadow:0 4px 16px rgba(37,99,235,0.15)!important}
body.light .btn.bo{background:#ffffff!important;color:#d97706!important;border-color:rgba(217,119,6,0.3)!important}
body.light .btn.bo:hover{background:#fffbeb!important;box-shadow:0 4px 16px rgba(217,119,6,0.15)!important}
body.light .btn.bw{background:#ffffff!important;color:#334155!important;border-color:#cbd5e1!important}
body.light .btn.bw:hover{background:#f1f5f9!important;box-shadow:0 4px 12px rgba(15,23,42,0.08)!important}
body.light .tab{background:#ffffff!important;color:#475569!important;border-color:#e2e8f0!important}
body.light .tab.on,body.light .tab.active{background:linear-gradient(135deg,#7c3aed,#0891b2)!important;color:#ffffff!important;border-color:transparent!important}
body.light input.iv,body.light input.is,body.light select.iv,body.light textarea{background:#ffffff!important;color:#0f172a!important;border-color:#cbd5e1!important}
body.light input.iv:focus,body.light input.is:focus,body.light select.iv:focus,body.light textarea:focus{border-color:#7c3aed!important;box-shadow:0 0 0 3px rgba(124,58,237,0.15)!important}
body.light table th{background:#f8fafc!important;color:#64748b!important}
body.light td{color:#334155!important;border-color:#f1f5f9!important}
body.light tr:hover td{background:rgba(124,58,237,0.04)!important}
body.light #pinnedMsgBox{background:rgba(34,197,94,0.08)!important;border-color:#22c55e!important;color:#15803d!important}
body.light .card::before{background:linear-gradient(90deg,#7c3aed,#0891b2,#22c55e)!important;opacity:0.4!important}
body.light #wcFab{background:linear-gradient(135deg,#7c3aed,#0891b2)!important;color:#fff!important}
body.light .wcIcoBtn{color:#475569!important}
body.light .temp-row,body.light .tc,body.light .stats .card{border-color:#e2e8f0!important}
body.light .mb,body.light #meshRow .mb{background:#ffffff!important;border-color:#e2e8f0!important;color:#334155!important}

/* Theme toggle button (visible on mobile) */
.theme-btn{background:rgba(139,92,246,0.4)!important;border:1px solid rgba(167,139,250,0.7)!important;border-radius:24px;padding:8px 14px!important;cursor:pointer;color:#f1f5f9!important;font-size:0.75rem!important;font-weight:700!important;display:inline-flex!important;align-items:center!important;gap:6px!important;font-family:monospace;transition:all .2s;white-space:nowrap;flex-shrink:0;box-shadow:0 2px 8px rgba(139,92,246,0.3);margin-left:8px;min-width:72px;justify-content:center}
.theme-btn:hover{background:rgba(139,92,246,0.6)!important;border-color:rgba(167,139,250,0.9)!important;transform:translateY(-1px);box-shadow:0 4px 12px rgba(139,92,246,0.5)!important}
body.light .theme-btn{background:rgba(139,92,246,0.15)!important;color:#7c3aed!important;border-color:rgba(139,92,246,0.5)!important;box-shadow:0 2px 8px rgba(139,92,246,0.15)!important}
body.light .theme-btn:hover{background:rgba(139,92,246,0.28)!important;box-shadow:0 4px 12px rgba(139,92,246,0.25)!important}
.theme-btn span{line-height:1}
.hdr{gap:8px;flex-wrap:wrap}
@media(max-width:640px){.hdr{flex-wrap:wrap;gap:6px;padding:12px 14px}.theme-btn{padding:6px 12px!important;font-size:0.7rem!important;min-width:60px}}
</style>
</head>
<body><script>try{if(localStorage.getItem("jaatAdminTheme")==="light"){document.body.classList.add("light");document.documentElement.classList.add("light");}}catch(e){}</script>
<div class="hdr">
  <div><div class="logo">Nexora WiFi ADMIN</div><div class="sublabel">HOTSPOT CONTROL PANEL</div></div>
  <span class="badge $BDGC"><span class="dot $DOTC"></span>$NDS_STATUS</span>
  <button class="theme-btn" onclick="toggleTheme()" type="button"><span id="themeIcon">🌙</span><span id="themeText">Dark</span></button>
</div>
<div class="temp-row">
  <div class="tc"><div class="tc-lbl">5GHz R0</div><div class="tc-val t-cy">$TEMP_5G0</div></div>
  <div class="tc"><div class="tc-lbl">2.4GHz</div><div class="tc-val t-or">$TEMP_5G1</div></div>
  <div class="tc"><div class="tc-lbl">5GHz R2 (Off)</div><div class="tc-val t-re">$TEMP_2G</div></div>
</div>
<div class="temp-row">
  <div class="tc"><div class="tc-lbl">📡 Node 5G R0</div><div class="tc-val $NT0_CLS" id="ntA">$NT0.0°C</div></div>
  <div class="tc"><div class="tc-lbl">📡 Node 2.4GHz</div><div class="tc-val $NT1_CLS" id="ntB">$NT1.0°C</div></div>
  <div class="tc"><div class="tc-lbl">📡 Node R2 (Off)</div><div class="tc-val t-cy">N/A</div></div>
</div>
</div>
<div class="temp-row">
  <div style="grid-column:1/-1;width:100%">
<style>
#meshRow{display:flex;align-items:center;justify-content:center;overflow-x:auto;padding:6px 2px}
.mb{flex:0 0 auto;width:96px;text-align:center;background:rgba(0,20,30,.7);border:1px solid rgba(0,245,255,.3);border-radius:12px;padding:7px 5px;cursor:pointer;box-shadow:0 0 8px rgba(0,245,255,.1)}
.mb .l{font-size:.6rem;color:#94a3b8;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.mb .v{font-size:.85rem;font-weight:800;margin:2px 0;white-space:nowrap}
.mb .s{font-size:.5rem;color:#64748b;white-space:nowrap}
.mlink{flex:0 0 auto;width:36px;display:flex;flex-direction:column;align-items:center;gap:2px}
.mline{width:100%;height:3px;border-radius:2px;background-size:22px 3px;animation:mmdash 1s linear infinite}
@keyframes mmdash{to{background-position:-22px 0}}
</style>
<div id="meshRow"></div>
<div id="meshMeta" style="font-size:.58rem;color:#64748b;text-align:center;line-height:1.3;padding:2px 0">Loading...</div>
</div>
</div><div class="stats">
  <div class="sc"><div class="sn np">$total_v</div><div class="sl">Total Keys</div></div>
  <div class="sc"><div class="sn ng">$free_v</div><div class="sl">Free</div></div>
  <div class="sc"><div class="sn ny">$locked_v</div><div class="sl">Locked</div></div>
  <div class="sc"><div class="sn nc">$trusted_m</div><div class="sl">Trusted MACs</div></div>
  <div class="sc"><div class="sn ng" id="onCount">$ONLINE</div><div class="sl">Online Now</div></div>
  <div class="sc"><div class="sn nr">$STALE_COUNT</div><div class="sl">Stale</div></div>
</div>
HEADER
# ---------- Name edit form ----------
if echo "$QUERY_STRING" | grep -q "editname="; then
    EDIT_MAC=$(echo "$QUERY_STRING" | sed -n 's/.*editname=\([^&]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
    CURRENT_NAME=$(get_name "$EDIT_MAC")
    if [ -z "$CURRENT_NAME" ] && [ -f /tmp/dhcp.leases ]; then
        CURRENT_NAME=$(grep -i "$EDIT_MAC" /tmp/dhcp.leases | awk '{print $4}' | head -1)
    fi
    [ -z "$CURRENT_NAME" ] && CURRENT_NAME="$EDIT_MAC"
    echo "<div class='edit-form'>"
    echo "<div class='stitle' style='margin-bottom:8px'>✏️ Set Name for $EDIT_MAC</div>"
    echo "<form method='post' style='display:flex; gap:10px; align-items:center;'>"
    echo "<input type='hidden' name='action' value='setname'>"
    echo "<input type='hidden' name='mac' value='$EDIT_MAC'>"
    echo "<input class='iv' type='text' name='name' value='$CURRENT_NAME' placeholder='Enter device/user name'>"
    echo "<button class='btn bp' type='submit'>Save</button>"
    echo "<a href='admin.sh?pass=$ADMIN_PASS' class='btn' style='background:#334155;color:#e2e8f0;'>Cancel</a>"
    echo "</form></div>"
fi
# ---------- Top action bar ----------
echo "<div class='sec'>"
echo "<div class='stitle'>📊 Network Totals</div>"
echo "<div class='temp-row' id='network-totals'>"
echo "<div class='tc'><div class='tc-lbl'>⬇️ Download</div><div class='tc-val t-cy' id='total-down'>--</div></div>"
echo "<div class='tc'><div class='tc-lbl'>⬆️ Upload</div><div class='tc-val t-or' id='total-up'>--</div></div>"
echo "<div class='tc'><div class='tc-lbl'>📊 Total Data</div><div class='tc-val np' id='total-data'>--</div></div>"
echo "</div></div>"
echo "</div>"
echo "</div>"
# ---------- Tabs: Devices / Keys / Generator / Custom Time ----------
echo "<div class='sec'>"
echo "<div class='tabs'>"
echo "<button class='tab on' onclick=\"sw('dev',this)\">📶 Devices</button>"
echo "<button class='tab' onclick=\"sw('keys',this)\">🔑 Keys</button>"
echo "<button class='tab' onclick=\"sw('gen',this)\">⚡ Generator</button>"
echo "<button class='tab' onclick=\"sw('custom',this)\">⏱️ Custom Time</button>"
echo "</div>"
# Devices tab
echo "<div id='t-dev' class='tc2 on'>"
echo "<div class='stitle'>🟢 Authenticated</div>"
if [ -n "$auth_entries" ]; then echo "$auth_entries"; else echo "<p style='color:#64748b;font-size:12px;'>No authenticated devices at the moment.</p>"; fi
echo "<div class='stitle' style='margin-top:14px'>🟡 Pre-auth / Blocked</div>"
if [ -n "$blocked_entries" ]; then echo "$blocked_entries"; else echo "<p style='color:#64748b;font-size:12px;'>All connected devices are authenticated.</p>"; fi
echo "</div>"
# Keys tab
echo "<div id='t-keys' class='tc2'>"
echo "<div class='stitle'>Add Voucher</div>"
echo "<form method='post' class='fr'><input type='hidden' name='action' value='addvoucher'><input class='iv' type='text' name='key' placeholder='Enter voucher code' required><button type='submit' class='btn bp'>+ Add</button></form>"
echo "<div class='stitle' style='margin-top:16px'>All Voucher Keys <button id='toggleBtn' class='btn bc bsm' type='button' onclick='toggleVouchers()' style='margin-left:8px'>🔽 Show</button></div>"
echo "<div id='voucherTable' class='tw' style='display:none'><table><tr><th>Key</th><th>Status</th><th>Used by MAC</th><th>Action</th></tr>"
while read -r line; do
    if echo "$line" | grep -q "LOCKED-"; then
        vkey=$(echo "$line" | awk '{print $1}')
        vmac=$(echo "$line" | sed -n 's/.*LOCKED-\([0-9a-fA-F:]*\)-.*/\1/p')
        echo "<tr><td class='mo'>$vkey</td><td><span class='chip cb'>Locked</span></td><td class='mo'>$vmac</td><td><form method='post' style='display:inline;margin:0'><input type='hidden' name='action' value='delmac'><input type='hidden' name='mac' value='$vmac'><button class='btn br bsm' type='submit'>Delete</button></form></td></tr>"
    else
        echo "<tr><td class='mo'>$line</td><td><span class='chip cg'>Free</span></td><td>—</td><td></td></tr>"
    fi
done < "$VOUCHER_FILE"
echo "</table></div>"
echo "<div class='stitle' style='margin-top:16px'>⏳ Trusted MACs & Remaining Days</div>"
echo "<div class='tw'><table><tr><th>Name</th><th>MAC</th><th>Voucher</th><th>Days Left</th><th>Remove</th></tr>"
NOW=$(date +%s)
grep "LOCKED-" "$VOUCHER_FILE" | while read -r line; do
    tkey=$(echo "$line" | awk '{print $1}')
    tmac=$(echo "$line" | sed -n 's/.*LOCKED-\([0-9a-fA-F:]*\)-.*/\1/p')
    start=$(echo "$line" | sed -n 's/.*LOCKED-[^-]*-\([0-9]*\).*/\1/p')
    expire=$(echo "$line" | sed -n 's/.*-EXP-\([0-9]*\)$/\1/p')
    [ -z "$expire" ] && expire=$((start + 2592000))
    remaining=$(( (expire - NOW) / 86400 ))
    spinprize=""
    case "$tkey" in
      Nexora-1H-*) spinprize="1 Ghanta" ;;
      Nexora-2H-*) spinprize="2 Ghante" ;;
      Nexora-3H-*) spinprize="3 Ghante" ;;
    esac
    devname=$(get_name "$tmac")
    phone=$(grep "|${tmac}|" "/etc/nodogsplash/requests.txt" 2>/dev/null | tail -1 | cut -d"|" -f2)
    if [ -n "$spinprize" ]; then
        NAMECELL="&#127920; Spin $spinprize"
    elif [ -n "$devname" ] && [ -n "$phone" ]; then
        NAMECELL="$devname<br><span style='color:#64748b;font-size:.7rem'>$phone</span>"
    elif [ -n "$devname" ]; then
        NAMECELL="$devname"
    elif [ -n "$phone" ]; then
        NAMECELL="$phone"
    else
        NAMECELL="-"
    fi
    if [ -n "$spinprize" ]; then
        SLEFT=$((expire - NOW))
        if [ "$SLEFT" -le 0 ]; then TIMECELL="Expired"; else
        SHH=$((SLEFT / 3600)); SMM=$(((SLEFT % 3600) / 60))
        if [ "$SHH" -gt 0 ]; then TIMECELL="${SHH}h ${SMM}m"; else TIMECELL="${SMM}m"; fi
        fi
        [ -n "$spinprize" ] && [ "$SLEFT" -gt 0 ] && TIMECELL="<span class='spinT' data-exp='${expire}'>${TIMECELL}</span>"
    else
        TIMECELL="${remaining}d"
    fi
    [ -z "$devname" ] && devname="-"
    echo "<tr><td>$NAMECELL</td><td class='mo'>$tmac</td><td class='mo'>$tkey</td><td><span class='chip cy2'>$TIMECELL</span></td><td style='display:flex;gap:6px;flex-wrap:wrap'><a href='admin.sh?pass=$ADMIN_PASS&editname=$tmac' class='btn bc bsm' style='text-decoration:none'>Rename</a><form method='post' style='margin:0'><input type='hidden' name='action' value='delmac'><input type='hidden' name='mac' value='$tmac'><button class='btn br bsm' type='submit'>Remove</button></form></td></tr>"
done
echo "</table></div>"
echo "</div>"
# Generator tab
echo "<div id='t-gen' class='tc2'>"
echo "<div class='stitle'>Generate Voucher Keys</div>"
echo "<form method='post' class='fr'><input type='hidden' name='action' value='genkeys'><span style='font-size:13px;color:#64748b'>Kitni keys:</span><input class='is' type='number' name='keycount' value='5' min='1' max='50'><button type='submit' class='btn bg'>⚡ Generate</button></form>"
echo "</div>"
# Custom Time tab
echo "<div id='t-custom' class='tc2'>"
echo "<div class='stitle'>Custom Time Access</div>"
echo "<form method='post' class='fr'>"
echo "<input type='hidden' name='action' value='customtime'>"
echo "<input class='iv' type='text' name='custommac' placeholder='MAC Address'>"
echo "<input class='is' type='number' name='customval' value='1' min='1' max='9999'>"
echo "<select name='customunit'><option value='m'>Minutes</option><option value='h'>Hours</option><option value='d' selected>Days</option></select>"
echo "<input class='iv' type='text' name='customname' placeholder='Name optional'>"
echo "<button type='submit' class='btn bp'>✅ Give Access</button>"
echo "</form></div>"
echo "</div>"
# ---------- Network Totals ----------
echo "<div class='acts'>"
echo "<form method='post' style='margin:0' onsubmit=\"return confirm('Restart NoDogSplash?')\"><input type='hidden' name='action' value='restart_nds'><button class='btn bc' type='submit'>&#128260; Restart NDS</button></form>"
echo "<form method='post' style='margin:0' onsubmit=\"return confirm('Stop NoDogSplash? Hotspot access will be blocked.')\"><input type='hidden' name='action' value='stop_nds'><button class='btn bo' type='submit'>⏹️ Stop NDS</button></form>"
echo "<form method='post' style='margin:0' onsubmit=\"return confirm('Disable Hotspot interface? Internet on hotspot will go down completely.')\"><input type='hidden' name='action' value='disable_hotspot'><button class='btn br' type='submit'>📴 Disable Hotspot</button></form>"
echo "<form method='post' style='margin:0' onsubmit=\"return confirm('Reboot the router?')\"><input type='hidden' name='action' value='reboot'><button class='btn br' type='submit'>⏻ Reboot</button></form>"
echo "<a href='admin.sh?pass=$ADMIN_PASS' style='text-decoration:none'><button class='btn bp' type='button'>🔁 Refresh</button></a>"
echo "<a href='/vidmgr.html' target='_blank' style='text-decoration:none'><button class='btn bp' type='button'>&#127916; Video Manager</button></a>"
echo "<a href='/cgi-bin/announce.sh?pass=$ADMIN_PASS' target='_blank' style='text-decoration:none'><button class='btn bp' type='button'>📢 Announcement</button></a>"
echo "<a href='/mesh_map.html' target='_blank' style='text-decoration:none'><button class='btn bp' type='button'>&#128506; Mesh Map</button></a>"
echo "</div>"
# ---------- Watch Chat ----------
echo "<div class='sec'>"
echo "<div class='stitle'>💬 Watch Chat (Live)</div>"
echo "<div id='pinnedMsgBox' style='display:none;background:rgba(34,197,94,0.1);border:1px solid #22c55e;border-radius:8px;padding:8px 12px;margin-bottom:8px;font-size:12px;color:#22c55e;'>📌 <span id='pinnedMsgText'></span> <button onclick=\"unpinMsg()\" style='float:right;background:none;border:none;color:#ef4444;cursor:pointer;'>✕</button></div>"
echo "<div id='watchChatAdmin'></div>"
echo "<div style='display:flex;gap:8px;margin-top:10px;'>"
echo "<input class='iv' type='text' id='adminChatMsg' placeholder='Reply likhein...' onkeypress='if(event.key===\"Enter\")sendAdminChatMsg();'>"
echo "<button type='button' onclick='sendAdminChatMsg()' class='btn bg'>Bhejein</button>"
echo "</div></div>"
# ---------- WiFi Chat Bubble ----------
echo "<script>var WCPASS='$ADMIN_PASS';</script>"
echo "<style>"
echo "#wcFab{position:fixed;right:18px;bottom:18px;z-index:99998;width:58px;height:58px;border-radius:50%;border:none;background:linear-gradient(135deg,#8b5cf6,#6366f1);color:#fff;font-size:26px;cursor:pointer;box-shadow:0 4px 16px rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center}"
echo "#wcBadge{position:absolute;top:-5px;right:-5px;background:#ef4444;color:#fff;font-size:11px;font-weight:800;min-width:21px;height:21px;border-radius:11px;display:none;align-items:center;justify-content:center;padding:0 5px;border:2px solid #0b1220}"
echo "#wcPop{display:none;position:fixed;right:16px;bottom:86px;z-index:99999;width:330px;max-width:calc(100vw - 24px);height:430px;max-height:72vh;background:#0b1220;border:1px solid #334155;border-radius:14px;flex-direction:column;overflow:hidden;box-shadow:0 10px 34px rgba(0,0,0,.65)}"
echo "#wcPop.open{display:flex}"
echo ".wcHead{display:flex;justify-content:space-between;align-items:center;padding:10px 12px;background:#111a2e;border-bottom:1px solid #1e293b;color:#e2e8f0;font-weight:700;font-size:14px}"
echo ".wcIcoBtn{background:none;border:none;color:#94a3b8;font-size:15px;cursor:pointer;padding:2px 4px;margin-left:4px}"
echo "#wifiChatAdmin{flex:1;overflow-y:auto;padding:10px}"
echo ".wcInputRow{display:flex;gap:8px;padding:10px;border-top:1px solid #1e293b;background:#111a2e}"
echo "@keyframes wcPulse{0%{box-shadow:0 0 0 0 rgba(239,68,68,.7)}70%{box-shadow:0 0 0 12px rgba(239,68,68,0)}100%{box-shadow:0 0 0 0 rgba(239,68,68,0)}}"
echo "#wcFab.hasUnread{animation:wcPulse 2s infinite}"
echo "#wcPop{width:360px!important;height:540px!important;max-height:80vh!important;border-radius:18px!important}"
echo "#wifiChatAdmin{padding:12px!important;min-height:0;-webkit-overflow-scrolling:touch;overscroll-behavior:contain}"
echo ".wcInputRow .iv{border-radius:20px!important}"
echo ".wcInputRow .btn{border-radius:20px!important}"
echo "</style>"
echo "<button type='button' id='wcFab' onclick='toggleWifiChat()'>💬<span id='wcBadge'></span></button>"
echo "<div id='wcPop'>"
echo "<div class='wcHead'><span>💬 WiFi Chat</span><span><button type='button' onclick='clearWifiChat()' class='wcIcoBtn' title='Clear Chat'>🗑</button><button type='button' onclick='toggleWifiChat()' class='wcIcoBtn' title='Close'>✕</button></span></div>"
echo "<div id='wifiChatAdmin'></div>"
echo "<div class='wcInputRow'>"
echo "<input class='iv' type='text' id='wifiChatMsg' placeholder='Admin reply likhein...' onkeypress='if(event.key===\"Enter\")sendWifiChatMsg();'>"
echo "<button type='button' onclick='sendWifiChatMsg()' class='btn bg'>Bhejein</button>"
echo "</div></div>"
cat << 'FOOTER'
<script>
setInterval(function(){
  var els=document.querySelectorAll('.spinT');
  for(var i=0;i<els.length;i++){
    var l=parseInt(els[i].getAttribute('data-exp'),10)-Math.floor(Date.now()/1000);
    if(l<=0){els[i].textContent='Expired';continue;}
    var h=Math.floor(l/3600),m=Math.floor((l%3600)/60);
    els[i].textContent=h>0?(h+'h '+m+'m'):(m+'m');
  }
},30000);
function toggleVouchers(){
  var x=document.getElementById("voucherTable");var btn=document.getElementById("toggleBtn");
  if(x.style.display==="none"){x.style.display="block";btn.innerText="🔼 Hide";}else{x.style.display="none";btn.innerText="🔽 Show";}
}
function sw(n,el){
  document.querySelectorAll('.tc2').forEach(t=>t.classList.remove('on'));
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('on'));
  document.getElementById('t-'+n).classList.add('on');
  el.classList.add('on');
}
var pinnedMsg=localStorage.getItem("nexoraPinnedMsg")||"";
function renderPinned(){if(pinnedMsg){document.getElementById("pinnedMsgBox").style.display="block";document.getElementById("pinnedMsgText").textContent=pinnedMsg;}else{document.getElementById("pinnedMsgBox").style.display="none";}}
function pinMsg(t){pinnedMsg=t;localStorage.setItem("nexoraPinnedMsg",t);renderPinned();}
function unpinMsg(){pinnedMsg="";localStorage.removeItem("nexoraPinnedMsg");renderPinned();}
function loadAdminChat(){fetch("/cgi-bin/watch_chat.sh?action=get&t="+Date.now()).then(function(r){return r.text();}).then(function(t){
var lines=t.split(String.fromCharCode(10)).filter(function(x){return x.trim();});
var html="";
for(var i=0;i<lines.length;i++){
var line=lines[i];
var isAdmin=line.indexOf("Admin:")!==-1;
var esc=line.replace(/</g,"&lt;").replace(/>/g,"&gt;");
if(isAdmin){
html+="<div style=\"background:rgba(34,197,94,0.12);border-left:3px solid #22c55e;border-radius:6px;padding:6px 10px;margin-bottom:6px;color:#22c55e;font-weight:600;\">"+esc+"</div>";
}else{
html+="<div style=\"padding:6px 10px;margin-bottom:6px;color:#e2e8f0;cursor:pointer;\" title=\"Click to pin\" onclick='pinMsg(this.textContent)'>"+esc+"</div>";
}
}
document.getElementById("watchChatAdmin").innerHTML=html;
var b=document.getElementById("watchChatAdmin");b.scrollTop=b.scrollHeight;
});}
function sendAdminChatMsg(){var inp=document.getElementById("adminChatMsg");var msg=inp.value.trim();if(!msg)return;fetch("/cgi-bin/admin_chat_reply.sh?msg="+encodeURIComponent(msg)).then(function(){inp.value="";loadAdminChat();});}
renderPinned();loadAdminChat();setInterval(loadAdminChat,4000);
var WCPASS=window.WCPASS||"CHANGE_ME_ADMIN_PASS";
var wcOpen=false,wcLastRead=0,wcInit=false;
function wcCountUsers(lines){var c=0;for(var i=0;i<lines.length;i++){if(lines[i].trim()&&lines[i].indexOf("[ADMIN]")===-1)c++;}return c;}
function wcColor(x){var cs=["#38bdf8","#fbbf24","#34d399","#f87171","#a78bfa","#f472b6","#22d3ee","#a3e635"];var h=0;for(var i=0;i<x.length;i++){h=((h<<5)-h+x.charCodeAt(i))|0}return cs[Math.abs(h)%cs.length]}
function wcE(x){return x.replace(/</g,"&lt;").replace(/>/g,"&gt;")}
function loadWifiChat(){fetch("/cgi-bin/wifi_chat_admin.sh?action=load&pass="+encodeURIComponent(WCPASS)+"&t="+Date.now()).then(function(r){return r.text();}).then(function(t){
if(t.trim()==="DENIED")return;
var lines=t.split(String.fromCharCode(10)).filter(function(x){return x.trim();});
var html="";
for(var i=0;i<lines.length;i++){
var line=lines[i];
var isAdmin=line.indexOf("[ADMIN]")!==-1;
if(isAdmin){
html+="<div style=\"background:rgba(34,197,94,0.12);border-left:3px solid #22c55e;border-radius:6px;padding:6px 10px;margin-bottom:6px;color:#22c55e;font-weight:600;\">"+wcE(line)+"</div>";
}else{
var pm=line.match(/^\[([^\]]+)\]\s+(.*?)\s+\[([^\]]+)\]:\s(.*)$/);
if(pm){
var uc=wcColor(pm[3]);
html+="<div style=\"border-left:3px solid "+uc+";background:rgba(255,255,255,0.04);border-radius:6px;padding:6px 10px;margin-bottom:6px;color:#e2e8f0;cursor:pointer;\" title=\"Click to pin\" onclick='pinMsg(this.textContent)'>";
html+="<b style=\"color:"+uc+"\">"+wcE(pm[2])+"</b> <span style=\"color:#64748b;font-size:10px\">";
html+=wcE(pm[1])+" \u2022 "+wcE(pm[3])+"</span>";
var vv="";
if(pm[4].indexOf("VOICE:")===0){
var vf=pm[4].substring(6);
vv='<audio controls preload="none"';
vv+=' style="width:100%;max-width:240px"';
vv+=' src="/cgi-bin/audio.sh?f=';
vv+=encodeURIComponent(vf)+'"></audio>';
vv="<div>"+vv+"</div>";
}
html+="<div>"+(vv?vv:wcE(pm[4]))+"</div></div>";
}else{
html+="<div style=\"padding:6px 10px;margin-bottom:6px;color:#e2e8f0;cursor:pointer;\" title=\"Click to pin\" onclick='pinMsg(this.textContent)'>"+wcE(line);
html+="</div>";
}
}
}
var b=document.getElementById("wifiChatAdmin");if(!b)return;
var atB=b.scrollTop+b.clientHeight>=b.scrollHeight-40;
b.innerHTML=html||"<div style='color:#64748b;font-size:12px;text-align:center;padding:20px;'>Koi message nahi</div>";
if(wcOpen&&atB)b.scrollTop=b.scrollHeight;
var total=wcCountUsers(lines);
if(!wcInit){wcLastRead=total;wcInit=true;}
if(wcOpen)wcLastRead=total;
var unread=total-wcLastRead;if(unread<0)unread=0;
var badge=document.getElementById("wcBadge"),fab=document.getElementById("wcFab");
if(unread>0){badge.style.display="flex";badge.textContent=(unread>99?"99+":unread);fab.classList.add("hasUnread");}
else{badge.style.display="none";fab.classList.remove("hasUnread");}
});}
function toggleWifiChat(){wcOpen=!wcOpen;var p=document.getElementById("wcPop");p.classList.toggle("open",wcOpen);if(wcOpen){loadWifiChat();setTimeout(function(){var b=document.getElementById("wifiChatAdmin");if(b)b.scrollTop=b.scrollHeight;},250);}else{loadWifiChat();}}
function sendWifiChatMsg(){var inp=document.getElementById("wifiChatMsg");var msg=inp.value.trim();if(!msg)return;fetch("/cgi-bin/wifi_chat_admin.sh?action=reply&pass="+encodeURIComponent(WCPASS)+"&msg="+encodeURIComponent(msg)).then(function(){inp.value="";loadWifiChat();});}

function clearWifiChat(){if(!confirm("WiFi chat poora delete kar dein?"))return;fetch("/cgi-bin/wifi_chat_admin.sh?action=clear&pass="+encodeURIComponent(WCPASS)+"&t="+Date.now()).then(function(){wcLastRead=0;loadWifiChat();});}
var WC_ADM_LAST="",WC_ADM_FIRST=true;
function loadWifiChat(){fetch("/cgi-bin/wifi_chat_admin.sh?action=load&pass="+encodeURIComponent(WCPASS)+"&t="+Date.now()).then(function(r){return r.text();}).then(function(t){
if(t.trim()==="DENIED")return;
fetch("/cgi-bin/wifi_chat_seenlist.sh?pass="+encodeURIComponent(WCPASS)+"&t="+Date.now()).then(function(r){return r.text();}).then(function(s){s=s.trim();wcDraw(t,s==="DENIED"?"":s);}).catch(function(){wcDraw(t,"");});
}).catch(function(){});}
function wcDraw(t,seen){
var lines=t.split(String.fromCharCode(10)).filter(function(x){return x.trim();});
var it=[],ai=-1,i;
for(i=0;i<lines.length;i++){
var pm=lines[i].match(/^\[([^\]]+)\]\s+(.*?)\s+\[([^\]]+)\]:\s(.*)$/);
if(pm){it.push({tm:pm[1],nm:pm[2],id:pm[3],tx:pm[4],ad:pm[3]==="ADMIN"});if(pm[3]==="ADMIN")ai=it.length-1;}
else it.push({raw:lines[i]});
}
var html="";
for(i=0;i<it.length;i++){
var x=it[i];
if(x.raw!==undefined){html+='<div style="padding:6px 10px;margin-bottom:6px;color:#94a3b8;font-size:12px">'+wcE(x.raw)+'</div>';continue;}
var body;
if(x.tx.indexOf("VOICE:")===0){body='<audio controls preload="none" style="width:100%;max-width:230px" src="/cgi-bin/audio.sh?f='+encodeURIComponent(x.tx.substring(6))+'"></audio>';}
else{body=wcE(x.tx);}
if(x.ad){
html+='<div style="display:flex;justify-content:flex-end;margin-bottom:8px"><div style="max-width:82%;background:#1d4ed8;color:#fff;border-radius:16px 16px 4px 16px;padding:8px 12px;font-size:13px;line-height:1.4;overflow-wrap:anywhere">';
html+='<div style="font-size:11px;font-weight:700;opacity:.85;margin-bottom:2px">'+wcE(x.nm)+'</div>'+body;
html+='<div style="font-size:10px;opacity:.7;text-align:right;margin-top:3px">'+wcE(x.tm)+'</div></div></div>';
if(i===ai)html+='<div style="text-align:right;font-size:10px;color:#60a5fa;margin:-4px 4px 10px 0">'+(seen?'\u2713\u2713 Seen by '+wcE(seen):'\u2713 Sent')+'</div>';
}else{
var uc=wcColor(x.id);
html+='<div style="display:flex;gap:8px;align-items:flex-end;margin-bottom:8px"><div style="width:30px;height:30px;border-radius:50%;background:'+uc+';color:#0b1220;font-weight:800;font-size:13px;display:flex;align-items:center;justify-content:center;flex:none">'+wcE((x.nm.trim().charAt(0)||"?").toUpperCase())+'</div>';
html+='<div style="max-width:78%;background:#1e293b;color:#e2e8f0;border-radius:16px 16px 16px 4px;padding:8px 12px;font-size:13px;line-height:1.4;overflow-wrap:anywhere;cursor:pointer" title="Click to pin" onclick="pinMsg(this.textContent)">';
html+='<div style="font-size:11px;font-weight:700;color:'+uc+';margin-bottom:2px">'+wcE(x.nm)+' <span style="color:#64748b;font-weight:400">\u2022 '+wcE(x.id)+'</span></div>'+body;
html+='<div style="font-size:10px;color:#64748b;text-align:right;margin-top:3px">'+wcE(x.tm)+'</div></div></div>';
}
}
var b=document.getElementById("wifiChatAdmin");if(!b)return;
var key=html+"|"+seen;
if(key!==WC_ADM_LAST){
var atB=WC_ADM_FIRST||(b.scrollTop+b.clientHeight>=b.scrollHeight-40);
WC_ADM_LAST=key;
b.innerHTML=html||"<div style='color:#64748b;font-size:12px;text-align:center;padding:20px;'>Koi message nahi</div>";
if(atB)b.scrollTop=b.scrollHeight;
WC_ADM_FIRST=false;
}
var total=wcCountUsers(lines);
if(!wcInit){wcLastRead=total;wcInit=true;}
if(wcOpen)wcLastRead=total;
var unread=total-wcLastRead;if(unread<0)unread=0;
var badge=document.getElementById("wcBadge"),fab=document.getElementById("wcFab");
if(unread>0){badge.style.display="flex";badge.textContent=(unread>99?"99+":unread);fab.classList.add("hasUnread");}
else{badge.style.display="none";fab.classList.remove("hasUnread");}
}
loadWifiChat();setInterval(loadWifiChat,4000);

var MM_D=null;
function mmC(x){var d=document.createElement("div");d.textContent=x;return d.innerHTML}
function mmCol(sig,tq){
if(sig&&sig!==""){var v=parseInt(sig,10);
if(v>=-60)return "#22c55e";
if(v>=-72)return "#f59e0b";
return "#ef4444";}
if(tq>=204)return "#22c55e";
if(tq>=140)return "#f59e0b";
return "#ef4444";}
function mmSm(m){var p=m.split(":");return p[4]+":"+p[5]}
function mmLoad(){fetch("/cgi-bin/mesh_status.sh?t="+Date.now())
.then(function(r){return r.text()})
.then(function(t){var d;
try{d=JSON.parse(t)}catch(e){return}
MM_D=d;mmRender();}).catch(function(){})}
function mmRender(){
var row=document.getElementById("meshRow");if(!row)return;
var meta=document.getElementById("meshMeta");
if(!MM_D)return;
if(!MM_D.nodes.length){row.innerHTML="";
if(meta)meta.innerHTML="";return;}
var SELF=MM_D.self.mac;
var kids={},i,nd;
for(i=0;i<MM_D.nodes.length;i++){nd=MM_D.nodes[i];
var p=(nd.nh===nd.mac)?SELF:nd.nh;
if(!kids[p])kids[p]=[];
kids[p].push(nd);}
var left=[],right=[];
function walk(mac,side){
var arr=kids[mac]||[];
for(var k=0;k<arr.length;k++){
if(side)right.push(arr[k]);else left.push(arr[k]);
walk(arr[k].mac,side);}}
var top=kids[SELF]||[];
for(i=0;i<top.length;i++){
var sd=(i%2===1);
if(sd)right.push(top[i]);else left.push(top[i]);
walk(top[i].mac,sd);}
function q(nd){return nd.sig?nd.sig+' dBm':
Math.round(nd.tq*100/255)+'%';}
function mbox(nd){
var c=mmCol(nd.sig,nd.tq);
var via=(nd.via==='Main')?'↔ Main':'via '+nd.via;
var h='<div class="mb" onclick="window.open(';
h+="'/mesh_map.html','_blank')\">";
h+='<div class="l">📡 '+mmC(nd.name)+'</div>';
h+='<div class="v" style="color:'+c+'">'+mmC(q(nd));
h+='</div><div class="s">'+mmC(mmSm(nd.mac));
h+=' • '+mmC(via)+'</div></div>';
return h;}
function mainbox(){
var h='<div class="mb" style="border-color:#22c55e">';
h+='<div class="l" style="color:#22c55e">🏠 Main</div>';
h+='<div class="v" style="color:#22c55e">';
h+=mmC(MM_D.self.ssid||'mesh')+'</div>';
h+='<div class="s">'+mmC(mmSm(SELF))+'</div></div>';
return h;}
function mlink(nd){
var c=mmCol(nd.sig,nd.tq);
var h='<div class="mlink"><div style="font-size:.5rem;';
h+='color:'+c+'">'+mmC(q(nd))+'</div>';
h+='<div class="mline" style="background-image:';
h+='repeating-linear-gradient(90deg,'+c;
h+=' 0 6px,transparent 6px 11px)"></div></div>';
return h;}
var h='',L=left.slice().reverse();
for(i=0;i<L.length;i++){
if(i>0)h+=mlink(L[i]);
h+=mbox(L[i]);}
if(L.length)h+=mlink(L[L.length-1]);
h+=mainbox();
for(i=0;i<right.length;i++){
h+=mlink(right[i]);
h+=mbox(right[i]);}
row.innerHTML=h;
var extra='';
for(i=0;i<MM_D.nodes.length;i++){nd=MM_D.nodes[i];
var c=mmCol(nd.sig,nd.tq);
extra+=' • <span style="color:'+c+'">';
extra+=mmC(nd.name)+' '+mmC(q(nd))+'</span>';}
if(meta)meta.innerHTML='Nodes: '
+MM_D.nodes.length+extra;
}
mmLoad();setInterval(mmLoad,10000);
/*ntApiPoll*/
setInterval(function(){
fetch("/cgi-bin/node_temp_api.sh?t="+Date.now()).then(function(r){return r.json()}).then(function(d){
var a=document.getElementById("ntA"),b=document.getElementById("ntB");if(!a||!b)return;
a.className="tc-val "+d.a_c;a.textContent=d.a+".0\u00b0C";
b.className="tc-val "+d.b_c;b.textContent=d.b+".0\u00b0C";
}).catch(function(){})},60000);
var onLast=0;
function onPoll(){
fetch("/cgi-bin/online_count.sh?t="+Date.now(),{cache:"no-store"})
.then(function(r){return r.text()})
.then(function(t){
var n=parseInt(t,10)||0;
var el=document.getElementById("onCount");if(!el)return;
if(n===0&&onLast>0){return;} /* 0 ko ek poll ke liye rok do */
el.innerText=n;onLast=n;
}).catch(function(){});
}
onPoll();var onSmooth=setInterval(onPoll,1500);

var onT=null; /*replaced*/
window.addEventListener("resize",function(){mmRender()});
</script>
<script>
function toggleTheme(){
  var light = document.body.classList.contains('light') || document.documentElement.classList.contains('light');
  if(light){
    document.body.classList.remove('light');
    document.documentElement.classList.remove('light');
    try{localStorage.setItem('jaatAdminTheme','dark');}catch(e){}
  }else{
    document.body.classList.add('light');
    document.documentElement.classList.add('light');
    try{localStorage.setItem('jaatAdminTheme','light');}catch(e){}
  }
  var i=document.getElementById('themeIcon');var t=document.getElementById('themeText');
  var nowLight = document.body.classList.contains('light');
  if(i) i.textContent = nowLight ? '☀️' : '🌙';
  if(t) t.textContent = nowLight ? 'Light' : 'Dark';
}
</script>
</body><script src="/signal.js?v=$(date +%s)"></script></html>
FOOTER
