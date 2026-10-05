#!/bin/sh
echo "Content-type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Cache-Control: no-cache, no-store, must-revalidate"
echo ""

TRUSTED_FILE="/etc/nodogsplash/trusted_macs.txt"
LIVE_FILE="/etc/nodogsplash/nlbwmon_live.txt"
CACHE_FILE="/tmp/wifi_signal_cache.txt"
PARSED_FILE="/tmp/wifi_parsed.txt"

rm -f "$PARSED_FILE" /tmp/wifi_cache.tmp

# 1. Main Router Connections
for iface in phy0-ap1 phy1-ap1 wlan0 wlan1 wlan0-1 wlan1-1; do
    band="5GHz"
    [ "$iface" = "phy1-ap1" ] || [ "$iface" = "wlan1" ] || [ "$iface" = "wlan1-1" ] && band="2.4GHz"
    iwinfo "$iface" assoclist 2>/dev/null | awk -v b="$band" '{
        m=""; s=""
        for(i=1;i<=NF;i++){
            c=$i; gsub(/[\[\]\(\),;|]/,"",c)
            if(tolower(c) ~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/) m=tolower(c)
            if(s=="" && c ~ /^-[0-9]+$/) s=c
        }
        if(m!="" && s!="") print m, s, b
    }' >> "$PARSED_FILE"
done

# 2. Node Router Connections (Tagged as Node)
if [ -f "/www/wifi.txt" ] && [ -s "/www/wifi.txt" ]; then
    awk '$1=="[Node]" {
        m=""; s=""; ch=""
        for(i=1; i<=NF; i++) {
            c = $i; gsub(/[\[\]\(\),;|]/, "", c)
            if (tolower(c) ~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/) m = tolower(c)
            if (s == "" && c ~ /^-[0-9]+$/) s = c
            if (c == "Ch") { ch = $(i+1); gsub(/[^0-9]/, "", ch) }
        }
        band = (ch != "" && ch+0 <= 14) ? "2.4GHz" : "5GHz"
        if (m != "" && s != "") print m, s, "Node-" band
    }' /www/wifi.txt >> "$PARSED_FILE"
fi

# 3. Merge into Cache
touch "$CACHE_FILE"
if [ -s "$PARSED_FILE" ]; then
    cat "$PARSED_FILE" "$CACHE_FILE" | awk '!seen[tolower($1)]++' > /tmp/wifi_cache.tmp
    mv /tmp/wifi_cache.tmp "$CACHE_FILE"
    rm -f "$PARSED_FILE" /tmp/wifi_cache.tmp
fi

nlbw -c json -g mac 2>/dev/null | grep -o '\["[^"]*",[0-9]*,[0-9]*,[0-9]*,[0-9]*,[0-9]*\]' | sed -E 's/\["([^"]*)",[0-9]*,([0-9]*),[0-9]*,([0-9]*),[0-9]*\]/\1 \2 \3/' > /tmp/nlbw_lines.txt

[ -f "$LIVE_FILE" ] && TOTALS=$(awk '{d+=$2; u+=$3} END{print d+0, u+0}' "$LIVE_FILE") || TOTALS="0 0"
TOTAL_DOWN=$(echo "$TOTALS" | awk '{print $1}')
TOTAL_UP=$(echo "$TOTALS" | awk '{print $2}')
TOTAL_ALL=$(awk '{sum+=$2} END{print sum}' /etc/nodogsplash/nlbwmon_total.txt 2>/dev/null || echo 0)

echo "{"
echo "  \"server_time\": $(date +%s),"
echo "  \"uptime\": $(awk '{print $1}' /proc/uptime),"
echo "  \"totals\": {\"down\": ${TOTAL_DOWN:-0}, \"up\": ${TOTAL_UP:-0}, \"total\": ${TOTAL_ALL:-0}},"
echo '  "devices": ['

ip neigh show dev br-hotspot 2>/dev/null | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v 'fe80' | grep "lladdr" | \
awk -v trusted="$TRUSTED_FILE" -v wifi="$CACHE_FILE" -v nlbwf="/tmp/nlbw_lines.txt" -v live="$LIVE_FILE" '
BEGIN {
    while ((getline line < trusted) > 0) { gsub(/\r/,"",line); if (line!="") trustedset[tolower(line)]=1 }
    close(trusted)
    while ((getline line < wifi) > 0) {
        n = split(line, f, /[ \t]+/)
        if (n >= 2 && f[2] ~ /^-[0-9]+$/) {
            mac_key = tolower(f[1])
            sig_val[mac_key] = f[2]
            band_val[mac_key] = (n >= 3 && f[3] != "") ? f[3] : "2.4GHz"
        }
    }
    close(wifi)
    while ((getline line < nlbwf) > 0) { n = split(line, f, /[ \t]+/); if (n>=3) { rxv[tolower(f[1])]=f[2]; txv[tolower(f[1])]=f[3] } }
    close(nlbwf)
    while ((getline line < live) > 0) { n = split(line, f, /[ \t]+/); if (n>=5) { m=tolower(f[1]); ld[m]=f[2]; lu[m]=f[3]; lr[m]=f[4]; lt[m]=f[5] } }
    close(live)
    first=1
}
{
    ip=$1; mac=tolower($3); gsub(/\[|\]/,"",mac); status=$4
    sig = (mac in sig_val) ? sig_val[mac] : "--"
    bnd = (mac in band_val) ? band_val[mac] : ""
    online = (mac in trustedset) ? "true" : "false"
    rx = (mac in rxv) ? rxv[mac] : 0; tx = (mac in txv) ? txv[mac] : 0
    life_down = (mac in ld) ? ld[mac] : 0; life_up = (mac in lu) ? lu[mac] : 0
    last_rx = (mac in lr) ? lr[mac] : 0; last_tx = (mac in lt) ? lt[mac] : 0
    final_down = (rx+0 >= last_rx+0) ? (life_down + rx - last_rx) : (life_down + rx)
    final_up = (tx+0 >= last_tx+0) ? (life_up + tx - last_tx) : (life_up + tx)
    if (!first) print ","
    first=0
    printf "    {\"mac\": \"%s\", \"ip\": \"%s\", \"signal\": \"%s\", \"band\": \"%s\", \"status\": \"%s\", \"online\": %s, \"usage\": 0, \"live_down\": %d, \"live_up\": %d, \"live_total\": %d}", mac, ip, sig, bnd, status, online, final_down, final_up, (final_down + final_up)
}
'
echo ""
echo "  ]"
echo "}"
