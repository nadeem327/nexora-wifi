#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
echo "Content-Type: application/javascript; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo ""
CLIENT_IP="$REMOTE_ADDR"
CLIENT_MAC=$(ip neigh show | grep -i "$CLIENT_IP" | awk '{print $5}' | tr '[:upper:]' '[:lower:]')
CACHE_FILE="/tmp/wifi_signal_cache.txt"
sh /www/cgi-bin/signal_api.sh >/dev/null 2>&1
SIGNAL=0
BAND=""
if [ -n "$CLIENT_MAC" ] && [ -f "$CACHE_FILE" ]; then
  LINE=$(grep -i "^$CLIENT_MAC " "$CACHE_FILE" | tail -1)
  if [ -n "$LINE" ]; then
    RAW=$(echo "$LINE" | awk '{print $2}')
    case "$RAW" in
      -[0-9]*) SIGNAL=$RAW ;;
    esac
    BAND=$(echo "$LINE" | awk '{print $3}')
  fi
fi
BARS=0
LABEL="Searching"
if [ "$SIGNAL" -ne 0 ] 2>/dev/null; then
  if   [ "$SIGNAL" -ge -55 ]; then BARS=5; LABEL="Superb"
  elif [ "$SIGNAL" -ge -65 ]; then BARS=4; LABEL="Strong"
  elif [ "$SIGNAL" -ge -72 ]; then BARS=3; LABEL="Active"
  elif [ "$SIGNAL" -ge -78 ]; then BARS=2; LABEL="Connected"
  else BARS=1; LABEL="Available"
  fi
fi
case "$BAND" in
  Node-5GHz) BAND_ONLY="5GHz"; VIA_NODE="true" ;;
  Node-2.4GHz) BAND_ONLY="2.4GHz"; VIA_NODE="true" ;;
  5GHz) BAND_ONLY="5GHz"; VIA_NODE="false" ;;
  2.4GHz) BAND_ONLY="2.4GHz"; VIA_NODE="false" ;;
  *) BAND_ONLY=""; VIA_NODE="false" ;;
esac
if [ -n "$BAND_ONLY" ]; then
  TITLE="$LABEL Signal . $BAND_ONLY"
else
  TITLE="$LABEL Signal"
fi
MESH_SIG=$(iwinfo phy0-mesh0 info 2>/dev/null | grep -oE 'Signal: -?[0-9]+ dBm' | grep -oE -- '-[0-9]+')
if [ -n "$MESH_SIG" ]; then
  MESH_JS="$MESH_SIG"
else
  MESH_JS="null"
fi
cat << JSEOF
(function(){
  var bars = $BARS;
  var viaNode = $VIA_NODE;
  var meshSignal = $MESH_JS;
  var card = document.getElementById('sigcard');
  if(card) card.classList.toggle('weak', bars<=2);
  for(var i=1;i<=5;i++){
    var el = document.getElementById('sb'+i);
    if(el){ if(i<=bars) el.classList.add('on'); else el.classList.remove('on'); }
  }
  var t = document.getElementById('sigTitle');
  var sub = document.getElementById('sigSub');
  if(t) t.textContent = "$TITLE";
  if(sub) sub.textContent = "$SIGNAL dBm";
  var macEl = document.getElementById('myMac');
  if(macEl) macEl.textContent = "${CLIENT_MAC:-Not Found}";
})();
JSEOF
