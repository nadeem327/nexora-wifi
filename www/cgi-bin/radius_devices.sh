#!/bin/sh
# Device sections for radius panel
NAMES_FILE="/etc/nodogsplash/device_names.txt"
TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
VOUCHER_FILE="/etc/nodogsplash/monthly_vouchers.txt"
ADMIN_PASS="nadeem123"

human_bytes() {
    b=$1; [ -z "$b" ] && b=0
    if [ "$b" -ge 1073741824 ]; then echo "$b" | awk "{printf \"%.1f GB\",\$1/1073741824}"
    elif [ "$b" -ge 1048576 ]; then echo "$((b/1048576)) MB"
    elif [ "$b" -ge 1024 ]; then echo "$((b/1024)) KB"
    else echo "$b B"; fi
}
get_name() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    n=$(grep -i "^$mac|" "$NAMES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2-)
    echo "${n:-$mac}"
}
get_manufacturer() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    cached=$(grep -i "^$mac|" /etc/nodogsplash/mac_manufacturers.txt 2>/dev/null | cut -d'|' -f2)
    echo "${cached:-Unknown}"
}
get_wifi_band() {
    mac=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if grep -qi "^$mac" /tmp/wifi_5g.txt 2>/dev/null; then
        echo '<span style="color:#a855f7;font-size:0.7rem;">5GHz</span>'
    elif grep -qi "^$mac" /tmp/wifi_24g.txt 2>/dev/null; then
        echo '<span style="color:#22c55e;font-size:0.7rem;">2.4GHz</span>'
    else
        echo '<span style="color:#64748b;font-size:0.7rem;">&#8212;</span>'
    fi
}

iwinfo phy0-ap1 assoclist 2>/dev/null > /tmp/wifi_5g.txt
iwinfo phy1-ap1 assoclist 2>/dev/null > /tmp/wifi_24g.txt
NLBW_ALL=$(nlbw -c json -g mac 2>/dev/null)
arp_all=$(ip neigh show dev br-hotspot 2>/dev/null | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v fe80 | grep 'REACHABLE\|STALE\|DELAY')

auth_entries=""
blocked_entries=""
seen_macs=""

if [ -n "$arp_all" ]; then
while read -r cip _ mac st; do
    echo "$seen_macs" | grep -qw "$mac" && continue
    seen_macs="$seen_macs $mac"
    devname=$(get_name "$mac")
    mfr=$(get_manufacturer "$mac")
    band=$(get_wifi_band "$mac")
    editlink="<a href='radius.sh?pass=${ADMIN_PASS}&editname=${mac}' style='color:#6366f1;font-size:11px;margin-left:4px;'>✏️</a>"
    nlbw_line=$(echo "$NLBW_ALL" | grep -o "\"$mac\",[0-9]*,[0-9]*,[0-9]*,[0-9]*,[0-9]*")
    if [ -n "$nlbw_line" ]; then
        rx_b=$(echo "$nlbw_line" | cut -d',' -f3)
        tx_b=$(echo "$nlbw_line" | cut -d',' -f5)
        down=$(human_bytes ${rx_b:-0})
        up=$(human_bytes ${tx_b:-0})
        tacc=0
        al=$(grep -i "^$mac " /etc/nodogsplash/nlbwmon_total.txt 2>/dev/null | tail -1)
        [ -n "$al" ] && tacc=$(echo "$al" | awk '{print $2}')
        thr=$(human_bytes $tacc)
        ustr="⚡ Live: ${down} down / ${up} up<br>📊 Total: $thr"
    else
        ustr="Data: 0 B"
    fi
    card_top="<div class='device'><div style='display:flex;justify-content:space-between;align-items:flex-start;'><div><div class='devname'>${devname} ${editlink}</div><div class='mac'>${mac}</div><div style='color:#64748b;font-size:.72rem;'>${mfr}</div><div style='color:#38bdf8;font-size:.75rem;'>${cip}</div><div>${band}</div></div><div style='text-align:right;font-size:.75rem;color:#94a3b8;'>${ustr}</div></div><div class='signal' data-signal='${mac}'><span style='color:#64748b'>-- dBm</span></div>"
    stbadge="<span class='arp-state status-badge status-online' data-status='${mac}'>${st}</span>"
    if grep -qi "^$mac$" "$TRUSTED_FILE" 2>/dev/null; then
        abadge="<span style='background:#22c55e20;color:#22c55e;padding:3px 10px;border-radius:20px;font-size:12px;border:1px solid #22c55e50' data-badge='${mac}'>Authenticated</span>"
        auth_entries="${auth_entries}${card_top}<div class='status-line'>${stbadge}${abadge}</div></div>"$'\n'
    else
        abadge="<span style='background:#fbbf2420;color:#fbbf24;padding:3px 10px;border-radius:20px;font-size:12px;border:1px solid #fbbf2450' data-badge='${mac}'>Blocked</span>"
        trials="<div style='margin-top:6px;'>"
        for v in "15 m 15m" "30 m 30m" "1 h 1h" "1 d 1day"; do
            val=$(echo $v | awk '{print $1}')
            unit=$(echo $v | awk '{print $2}')
            lbl=$(echo $v | awk '{print $3}')
            trials="${trials}<form method='post' style='display:inline'><input type='hidden' name='action' value='customtime'><input type='hidden' name='custommac' value='${mac}'><input type='hidden' name='customval' value='${val}'><input type='hidden' name='customunit' value='${unit}'><button type='submit' class='trial-btn'>${lbl}</button></form>"
        done
        trials="${trials}</div>"
        blocked_entries="${blocked_entries}${card_top}<div class='status-line'>${stbadge}${abadge}</div>${trials}</div>"$'\n'
    fi
done << ARPEOF
$arp_all
ARPEOF
fi

echo "<div class='device-section' id='auth-section'><h2>🟢 Authenticated Devices (Live Bandwidth)</h2>"
[ -n "$auth_entries" ] && echo "$auth_entries" || echo "<p style='color:#64748b;'>No authenticated devices.</p>"
echo "</div>"
echo "<div class='device-section' id='blocked-section'><h2>🟡 Pre-auth / Blocked Devices</h2>"
[ -n "$blocked_entries" ] && echo "$blocked_entries" || echo "<p style='color:#64748b;'>No blocked devices.</p>"
echo "</div>"
