extends SceneTree
## Writes the balance report (Balance.report) with every match log on this machine.
##   godot --headless --path . --script res://tools/balance.gd -- [out.md]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://balance_report.md"
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(Balance.report(MatchLog.load_all()))
	f.close()
	print("balance report: ", ProjectSettings.globalize_path(out))
	quit()
