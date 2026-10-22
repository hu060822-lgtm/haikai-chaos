class_name InputSetup
## Registers the game's input actions at startup (so the project file stays readable), and
## keeps the player's own bindings: any action listed in BINDABLE can be rebound in the
## settings menu (Esc); the choice is saved in user://settings.cfg.

const KEYS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "dash": [KEY_Q],
	"reload": [KEY_R], "fire_mode": [KEY_B], "bench": [KEY_TAB], "copy_gun": [KEY_F],
	"respawn": [KEY_ENTER], "help": [KEY_F1], "info_colors": [KEY_F2], "bot_toggle": [KEY_F3],
	"pause": [KEY_ESCAPE], "move_debug": [KEY_F4], "camera_fx": [KEY_F5], "tick_rate": [KEY_F7],
	"route_reset": [KEY_T],
}
const MOUSE := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}

## What the settings menu offers, in this order, with its name.
const BINDABLE := [
	["move_forward", "前進"], ["move_back", "後退"], ["move_left", "左移"], ["move_right", "右移"],
	["jump", "跳 / 蹬牆跳"], ["crouch", "蹲 / 滑鏟"], ["sprint", "衝刺跑"], ["dash", "衝刺閃避"],
	["fire", "開火"], ["aim", "瞄準"], ["reload", "換彈"], ["fire_mode", "射擊模式"],
	["bench", "改槍工作台"], ["copy_gun", "複製對手的槍"], ["route_reset", "回到路線起點"],
	["move_debug", "移動除錯面板"], ["camera_fx", "鏡頭效果"], ["help", "操作說明"],
]

static var _registered := false


static func register() -> void:
	if _registered:
		return
	_registered = true
	_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(Settings.FILE) == OK and cfg.has_section("keys"):
		for action in cfg.get_section_keys("keys"):
			if not InputMap.has_action(action):
				continue
			var events: Array = []
			for code in cfg.get_value("keys", action, []):
				var ev := decode(code)
				if ev:
					events.append(ev)
			if not events.is_empty():
				InputMap.action_erase_events(action)
				for ev in events:
					InputMap.action_add_event(action, ev)


static func _defaults() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)


## Bind `action` to this one key or mouse button only (and take it off any other action).
static func rebind(action: String, ev: InputEvent) -> void:
	for other in InputMap.get_actions():
		if other != action and not String(other).begins_with("ui_"):
			for old in InputMap.action_get_events(other):
				if encode(old) == encode(ev):
					InputMap.action_erase_event(other, old)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	save()


static func reset() -> void:
	_defaults()
	var cfg := ConfigFile.new()
	cfg.load(Settings.FILE)
	if cfg.has_section("keys"):
		cfg.erase_section("keys")
	cfg.save(Settings.FILE)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Settings.FILE)
	for pair in BINDABLE:
		cfg.set_value("keys", pair[0], InputMap.action_get_events(pair[0]).map(encode))
	cfg.save(Settings.FILE)


static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "k%d" % (k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	if ev is InputEventMouseButton:
		return "m%d" % (ev as InputEventMouseButton).button_index
	return ""


static func decode(code: String) -> InputEvent:
	if code.begins_with("k"):
		var k := InputEventKey.new()
		k.physical_keycode = int(code.substr(1)) as Key
		return k
	if code.begins_with("m"):
		var m := InputEventMouseButton.new()
		m.button_index = int(code.substr(1)) as MouseButton
		return m
	return null


## What's bound to `action`, for the menu: "W", "Ctrl / C", "滑鼠左鍵".
static func describe(action: String) -> String:
	var names := []
	for ev in InputMap.action_get_events(action):
		names.append(event_name(ev))
	return " / ".join(names) if not names.is_empty() else "（未設定）"


static func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if DisplayServer.get_name() != "headless" else code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "滑鼠左鍵"
			MOUSE_BUTTON_RIGHT: return "滑鼠右鍵"
			MOUSE_BUTTON_MIDDLE: return "滑鼠中鍵"
			MOUSE_BUTTON_XBUTTON1: return "滑鼠側鍵 1"
			MOUSE_BUTTON_XBUTTON2: return "滑鼠側鍵 2"
			MOUSE_BUTTON_WHEEL_UP: return "滾輪上"
			MOUSE_BUTTON_WHEEL_DOWN: return "滾輪下"
		return "滑鼠 %d" % (ev as InputEventMouseButton).button_index
	return "?"
