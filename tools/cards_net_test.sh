#!/bin/bash
# 超規卡 over a real connection: a host and a client process on this machine.
#   tools/cards_net_test.sh [path/to/godot] [port]
GODOT=${1:-godot}
PORT=${2:-24689}
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tests/cards_net_test.gd -- host "$PORT" > /tmp/cards_net_host_$PORT.log 2>&1 &
HOST=$!
sleep 1.5
"$GODOT" --headless --path . --script res://tests/cards_net_test.gd -- client "$PORT" > /tmp/cards_net_client_$PORT.log 2>&1
CLIENT=$?
wait $HOST
HOST_STATUS=$?
grep -hE "^  (ok|FAIL)|TESTS" /tmp/cards_net_host_$PORT.log /tmp/cards_net_client_$PORT.log
[ $HOST_STATUS -eq 0 ] && [ $CLIENT -eq 0 ]
