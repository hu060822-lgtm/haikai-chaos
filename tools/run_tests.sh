#!/bin/bash
# Runs every automated test: the original movement/shooting checks, then the feel checks
# and the three lab routes at 60, 120 and 240 physics ticks per second.
#   tools/run_tests.sh [path/to/godot]
GODOT=${1:-godot}
cd "$(dirname "$0")/.."
status=0
run() {
	"$GODOT" --headless "$@" 2>&1 | grep -E "^  (ok|FAIL)|TESTS|^ROUTE |^    [0-9]|^physics" || true
	[ "${PIPESTATUS[0]}" -eq 0 ] || status=1
}
run --path . --script res://tests/movement_test.gd
run --path . --script res://tests/gun_test.gd
run --path . --script res://tests/chaos2_test.gd
run --path . --script res://tests/rounds_test.gd -- 24694
for hz in 60 120 240; do
	run --fixed-fps $hz --path . --script res://tests/movement_feel_test.gd -- $hz
	run --fixed-fps $hz --path . --script res://tests/route_test.gd -- $hz
done
# Netplay: a host and a client process, then a host alone with live bots.
"$(dirname "$0")/net_test.sh" "$GODOT" 24687 || status=1
run --path . --script res://tests/net_test.gd -- solo 24690
# The relay server (C4): its protocol test, then the same host + client match through it.
if command -v node > /dev/null && [ -d relay/node_modules ]; then
	(cd relay && node test.js) | grep -E "^  (ok|FAIL)|TESTS" || status=1
	"$(dirname "$0")/net_test.sh" "$GODOT" 24692 relay | grep -E "TESTS|FAIL" || status=1
else
	echo "relay tests skipped (need node and npm install in relay/)"
fi
echo "ALL: $([ $status -eq 0 ] && echo PASS || echo FAILED)"
exit $status
