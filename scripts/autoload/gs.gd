extends Node
## Global game state, persistence and input map construction.
##
## The input map is built in code rather than stored in project.godot so the
## bindings live next to the game logic and stay readable/diffable.

const SAVE_PATH := "user://gdshmup.save"

var hi_score: int = 1_000_000
var ship_index: int = 0
var start_level: int = 0
## Dev switch (`--boss`): skip the waves and fight only the stage bosses.
var boss_rush: bool = false

## Set by the game scene when a run ends, read by the title screen.
var last_run_score: int = 0
var last_run_stage: int = 0
var last_run_cleared: bool = false


## Screenshot support: F12 saves to user://, or `--shot=PATH --shot-at=FRAME`
## grabs one automatically (handy for capturing stills without a human at the
## keyboard).
var _shot_path := ""
var _shot_at := -1
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_input_map()
	_load()
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.split("=", true, 1)[1]
		elif arg.begins_with("--shot-at="):
			_shot_at = int(arg.split("=", true, 1)[1])


func _process(_dt: float) -> void:
	_frames += 1
	if _shot_at >= 0 and _frames >= _shot_at:
		_shot_at = -1
		await RenderingServer.frame_post_draw
		_capture(_shot_path)
		get_tree().quit()


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F12:
		_capture("user://screenshot_%d.png" % Time.get_unix_time_from_system())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_fullscreen"):
		var w := DisplayServer.window_get_mode()
		if w == DisplayServer.WINDOW_MODE_FULLSCREEN \
				or w == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func submit_score(score: int) -> void:
	if score > hi_score:
		hi_score = score
		_save()


# --- Persistence -------------------------------------------------------------

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"hi_score": hi_score, "ship": ship_index}))
	f.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		hi_score = int(data.get("hi_score", hi_score))
		ship_index = clampi(int(data.get("ship", 0)), 0, 2)


# --- Input map ---------------------------------------------------------------

func _build_input_map() -> void:
	# Movement: WASD + arrows + left stick + d-pad.
	_action("p_left", [
		_key(KEY_A), _key(KEY_LEFT),
		_axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT),
	])
	_action("p_right", [
		_key(KEY_D), _key(KEY_RIGHT),
		_axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT),
	])
	_action("p_up", [
		_key(KEY_W), _key(KEY_UP),
		_axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP),
	])
	_action("p_down", [
		_key(KEY_S), _key(KEY_DOWN),
		_axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN),
	])

	# J = rapid shot (fast movement). K = focused laser (slow movement).
	_action("p_shot", [_key(KEY_J), _btn(JOY_BUTTON_A), _btn(JOY_BUTTON_X)])
	_action("p_laser", [_key(KEY_K), _btn(JOY_BUTTON_B), _btn(JOY_BUTTON_Y)])
	_action("p_bomb", [
		_key(KEY_SPACE), _key(KEY_L),
		_btn(JOY_BUTTON_RIGHT_SHOULDER), _btn(JOY_BUTTON_LEFT_SHOULDER),
	])

	_action("p_start", [
		_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _key(KEY_J),
		_btn(JOY_BUTTON_START), _btn(JOY_BUTTON_A),
	])
	_action("p_back", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_B), _btn(JOY_BUTTON_BACK)])
	_action("p_pause", [_key(KEY_ESCAPE), _key(KEY_P), _btn(JOY_BUTTON_START)])
	_action("toggle_fullscreen", [_key(KEY_F11)])

	# Menu navigation shares the movement bindings.
	_augment("ui_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_augment("ui_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_augment("ui_up", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_augment("ui_down", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])


func _action(name: String, events: Array, deadzone: float = 0.35) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, deadzone)
	for e in events:
		InputMap.action_add_event(name, e)


func _augment(name: String, events: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.35)
	for e in events:
		InputMap.action_add_event(name, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _btn(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e
