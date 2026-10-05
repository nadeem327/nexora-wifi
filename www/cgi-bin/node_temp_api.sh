#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
A="--"; A_C="t-cy"; B="--"; B_C="t-cy"
if [ -f /tmp/node_temp.txt ]; then
  V=$(cat /tmp/node_temp.txt | tail -1)
  A=$(echo "$V" | cut -d'|' -f2)
  B=$(echo "$V" | cut -d'|' -f3)
  [ "$A" != "down" ] && [ -n "$A" ] && {
    [ "$A" -ge 70 ] 2>/dev/null && A_C="t-re" || { [ "$A" -ge 60 ] 2>/dev/null && A_C="t-or"; }
    B="${B:-$A}"
    [ "$B" -ge 70 ] 2>/dev/null && B_C="t-re" || { [ "$B" -ge 60 ] 2>/dev/null && B_C="t-or"; }
  }
fi
printf '{"a":"%s","a_c":"%s","b":"%s","b_c":"%s","raw":"%s"}\n' "$A" "$A_C" "$B" "$B_C" "$(echo "$V" | cut -d'|' -f1 2>/dev/null)"
