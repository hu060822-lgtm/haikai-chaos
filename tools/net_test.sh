#!/bin/bash
# The two-process netplay test: a host and a client on this machine, each checking its side.
#   tools/net_test.sh [path/to/godot] [port]
GODOT=${1:-godot}
PORT=${2:-24687}
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tests/net_test.gd -- host "$PORT" > /tmp/net_host.log 2>&1 &
HOST=$!
sleep 1.5
"$GODOT" --headless --path . --script res://tests/net_test.gd -- client "$PORT" > /tmp/net_client.log 2>&1
CLIENT=$?
wait $HOST
HOST_STATUS=$?
grep -hE "^  (ok|FAIL)|TESTS" /tmp/net_host.log /tmp/net_client.log
[ $HOST_STATUS -eq 0 ] && [ $CLIENT -eq 0 ]
