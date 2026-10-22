class_name InputSetup
## Registers the game's input actions at startup (so the project file stays readable).

const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "dash": [KEY_Q],
	"reload": [KEY_R], "fire_mode": [KEY_B], "bench": [KEY_TAB], "copy_gun": [KEY_F],
	"respawn": [KEY_ENTER], "help": [KEY_F1], "info_colors": [KEY_F2], "bot_toggle": [KEY_F3],
	"pause": [KEY_ESCAPE], "move_debug": [KEY_F4], "camera_fx": [KEY_F5], "tick_rate": [KEY_F7],
	"route_reset": [KEY_T],
}
const MOUSE := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}


static func register() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
