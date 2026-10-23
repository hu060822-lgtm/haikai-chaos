extends SceneTree
## The cursor (C9 fix): after the Esc menu (and rebinding a key in it) the mouse comes back
## wherever there is something to click: the lobby, the death screen, the results. Only
## play captures it. Needs a real window (the headless display has no mouse modes):
##   xvfb-run godot --path . --script res://tests/mouse_test.gd

var main: Main
var failures := 0


func _init() -> void:
	InputSetup.register()
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(3)
	await _test_lobby()
	await _test_play()
	await _test_death_in_menu()
	await _test_results()
	InputSetup.reset()
	print("MOUSE TESTS: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		await frames(2)


func visible_mouse() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_VISIBLE


func _test_lobby() -> void:
	NetSession.active = true   # the lobby closes itself without a room
	main._open_lobby()
	await frames(2)
	check(visible_mouse(), "lobby: cursor visible")
	await key(KEY_ESCAPE)
	check(main.settings_menu.visible and visible_mouse(), "lobby: Esc opens the menu, cursor visible")
	# Rebind a key the way the menu does (click the button, press the key), then leave with Esc.
	main.settings_menu._waiting = "reload"
	await key(KEY_K)
	check(InputSetup.describe("reload") == "K", "lobby: reload rebound to K")
	await key(KEY_ESCAPE)
	check(not main.settings_menu.visible, "lobby: Esc closes the menu")
	check(visible_mouse(), "lobby: cursor still visible after the menu")
	check(not main.player.input_enabled, "lobby: the hidden player doesn't take input")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	Input.parse_input_event(click)
	await frames(2)
	check(visible_mouse(), "lobby: clicking doesn't hide the cursor")
	main.lobby.visible = false
	NetSession.active = false


func _test_play() -> void:
	main._start()
	await frames(2)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and main.player.input_enabled, "play: cursor captured")
	await key(KEY_ESCAPE)
	check(main.settings_menu.visible and visible_mouse(), "play: Esc menu shows the cursor")
	await key(KEY_ESCAPE)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and main.player.input_enabled, "play: closing the menu resumes play")


func _test_death_in_menu() -> void:
	await key(KEY_ESCAPE)
	main.player.alive = false
	main._on_player_died({})
	await key(KEY_ESCAPE)
	check(visible_mouse(), "died with the menu open: cursor visible after it closes")
	check(not main.player.input_enabled, "died with the menu open: no input while dead")
	# A respawn while the menu is open waits for it to close.
	await key(KEY_ESCAPE)
	main.player.alive = true
	main.death.hide_death()
	main.resume_play()
	check(visible_mouse() and not main.player.input_enabled, "respawn under the menu: cursor stays")
	await key(KEY_ESCAPE)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and main.player.input_enabled, "menu closed: play resumes")


func _test_results() -> void:
	# What show_results leaves behind (without a team match to fill it).
	main.results = Control.new()
	main.player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(visible_mouse(), "results: cursor visible after the menu")
	check(not main.player.input_enabled, "results: no input after the menu")
