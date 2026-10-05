#!/bin/sh
echo "Content-type: text/plain"
echo ""
rx=$(cat /sys/class/net/br-hotspot/statistics/rx_bytes)
tx=$(cat /sys/class/net/br-hotspot/statistics/tx_bytes)
echo "$rx $tx"
