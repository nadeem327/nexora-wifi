#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

MIF="phy0-mesh0"
SELF_MAC=$(cat /sys/class/net/$MIF/address | tr 'A-Z' 'a-z')
AUTO=/etc/mesh_nodes.auto
touch "$AUTO"

MESH_SSID=""
for sec in $(uci -q show wireless | grep '=wifi-iface' | cut -d. -f2 | cut -d= -f1); do
  if [ "$(uci -q get wireless.$sec.mode)" = "mesh" ]; then
    MESH_SSID=$(uci -q get wireless.$sec.mesh_id 2>/dev/null)
    [ -z "$MESH_SSID" ] && MESH_SSID=$(uci -q get wireless.$sec.ssid 2>/dev/null)
    break
  fi
done
[ -z "$MESH_SSID" ] && MESH_SSID=$(iw dev $MIF info 2>/dev/null | awk '/mesh id/{print $3}')

nameof(){
  m=$(echo "$1" | tr 'A-Z' 'a-z')
  if [ "$m" = "$SELF_MAC" ]; then echo "Main"; return; fi
  num=$(awk -v mac="$m" 'tolower($1)==mac{print $2; exit}' "$AUTO")
  if [ -z "$num" ]; then
    num=$(( $(awk '{if($2+0>n)n=$2} END{print n+0}' "$AUTO") + 1 ))
    echo "$m $num" >> "$AUTO"
  fi
  echo "Node-$num"
}

SIGDUMP=$(iw dev $MIF station dump 2>/dev/null)
getsig(){
 m=$(echo "$1" | tr 'A-Z' 'a-z')
 echo "$SIGDUMP" | awk -v mac="$m" '
 tolower($2)==mac{f=1;next}
 f && $1=="signal:"{print $2;exit}
 f && $1=="Station"{f=0}'
}

SELF_NAME="Main"

TMP=/tmp/mesh_nodes.txt
: > "$TMP"
batctl o 2>/dev/null | awk '$0 ~ /\*/ && length($2)==17 {print $2" "$3" "$4" "$5}' |
while read mac last tq nh; do
  tqn=$(echo "$tq" | tr -d '()')
  sig=$(getsig "$mac")
  name=$(nameof "$mac")
  nh2=$(echo "$nh" | tr 'A-Z' 'a-z')
  if [ "$nh2" = "$mac" ]; then via="Main"; else via=$(nameof "$nh"); fi
  printf '{"mac":"%s","name":"%s","tq":%s,"last":"%s","sig":"%s","nh":"%s","via":"%s"},\n' "$mac" "$name" "$tqn" "$last" "$sig" "$nh2" "$via" >> "$TMP"
done

printf '{"self":{"mac":"%s","name":"%s","ssid":"%s"},"nodes":[' "$SELF_MAC" "$SELF_NAME" "$MESH_SSID"
sed -e '$s/,$//' "$TMP" 2>/dev/null
printf ']}\n'
rm -f "$TMP"
