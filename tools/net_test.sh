#!/bin/bash
# The two-process netplay test: a host and a client on this machine, each checking its side.
#   tools/net_test.sh [path/to/godot] [port] [relay]
# With "relay" the two meet through a local relay server (relay/node_server.js, needs
# node and `npm install` in relay/) instead of connecting directly.
GODOT=${1:-godot}
PORT=${2:-24687}
MODE=${3:-direct}
cd "$(dirname "$0")/.."
EXTRA=()
if [ "$MODE" = relay ]; then
	RELAY_PORT=$((PORT + 1000))
	node relay/node_server.js "$RELAY_PORT" > /tmp/net_relay.log 2>&1 &
	RELAY=$!
	sleep 0.5
	EXTRA=(--relay=ws://127.0.0.1:$RELAY_PORT)
fi
"$GODOT" --headless --path . --script res://tests/net_test.gd -- host "$PORT" "${EXTRA[@]}" > /tmp/net_host_$PORT.log 2>&1 &
HOST=$!
sleep 1.5
"$GODOT" --headless --path . --script res://tests/net_test.gd -- client "$PORT" "${EXTRA[@]}" > /tmp/net_client_$PORT.log 2>&1
CLIENT=$?
wait $HOST
HOST_STATUS=$?
[ -n "$RELAY" ] && kill $RELAY
grep -hE "^  (ok|FAIL)|TESTS" /tmp/net_host_$PORT.log /tmp/net_client_$PORT.log
[ $HOST_STATUS -eq 0 ] && [ $CLIENT -eq 0 ]
