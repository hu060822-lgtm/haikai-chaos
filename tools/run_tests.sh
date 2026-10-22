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
for hz in 60 120 240; do
	run --fixed-fps $hz --path . --script res://tests/movement_feel_test.gd -- $hz
	run --fixed-fps $hz --path . --script res://tests/route_test.gd -- $hz
done
echo "ALL: $([ $status -eq 0 ] && echo PASS || echo FAILED)"
exit $status
