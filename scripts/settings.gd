class_name Settings
## The player's settings, kept in user://settings.cfg: mouse sensitivity, field of view,
## V-Sync, the FPS counter. Key bindings live in the same file (InputSetup) and so does the
## camera effects level (CameraFx).

const FILE := "user://settings.cfg"

static var sens := 1.0          # × the base mouse sensitivity
static var fov := 100.0         # horizontal-ish degrees (Godot's vertical FOV keeps aspect)
static var vsync := false       # off by default: V-Sync adds frames of input delay
static var show_fps := true
static var look := 2            # Faultprint.LOOKS: 0 original, 1 soft, 2 dark print
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		sens = float(cfg.get_value("game", "sens", sens))
		fov = float(cfg.get_value("game", "fov", fov))
		vsync = bool(cfg.get_value("game", "vsync", vsync))
		show_fps = bool(cfg.get_value("game", "show_fps", show_fps))
		look = clampi(int(cfg.get_value("game", "look", look)), 0, 2)
	CameraFx.load_settings()
	apply_display()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("game", "sens", sens)
	cfg.set_value("game", "fov", fov)
	cfg.set_value("game", "vsync", vsync)
	cfg.set_value("game", "show_fps", show_fps)
	cfg.set_value("game", "look", look)
	cfg.save(FILE)


static func apply_display() -> void:
	Faultprint.set_look(look)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
