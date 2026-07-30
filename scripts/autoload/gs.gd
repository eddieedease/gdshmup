extends Node
## Global game state, persistence and input map construction.
##
## The input map is built in code rather than stored in project.godot so the
## bindings live next to the game logic and stay readable/diffable.

const SAVE_PATH := "user://gdshmup.save"
const TABLE_SIZE := 8

## Seeded so a fresh install still has something to beat, the way a cabinet
## ships with factory scores.
const DEFAULT_TABLE := [
	{"name": "ACE", "score": 1_000_000, "stage": 2, "ship": 0, "cleared": true, "loop": 0},
	{"name": "GDS", "score": 780_000, "stage": 2, "ship": 1, "cleared": false, "loop": 0},
	{"name": "ZAP", "score": 620_000, "stage": 2, "ship": 2, "cleared": false, "loop": 0},
	{"name": "NEO", "score": 480_000, "stage": 1, "ship": 0, "cleared": false, "loop": 0},
	{"name": "VIC", "score": 350_000, "stage": 1, "ship": 1, "cleared": false, "loop": 0},
	{"name": "RAY", "score": 240_000, "stage": 1, "ship": 2, "cleared": false, "loop": 0},
	{"name": "SHM", "score": 150_000, "stage": 0, "ship": 0, "cleared": false, "loop": 0},
	{"name": "CAV", "score": 80_000, "stage": 0, "ship": 1, "cleared": false, "loop": 0},
]

## Play modes. Arcade is the authored five-stage run on one credit; Endless
## loops those stages forever and lets you continue, at the cost of your score.
## Each keeps its own ranking table - they are not comparable achievements.
enum Mode { ARCADE, ENDLESS }

const MODE_KEYS := ["arcade", "endless"]
const MODE_NAMES := ["ARCADE", "ENDLESS"]

var mode: int = Mode.ARCADE

## mode key -> ranking table, each sorted descending and capped at TABLE_SIZE.
var tables: Dictionary = {}
## Mirrors scores[0] so the HUD and title can read it directly.
var hi_score: int = 1_000_000
var ship_index: int = 0
var start_level: int = 0
## Mixer levels, 0..1, adjustable from the pause menu.
var music_volume: float = 0.75
var sfx_volume: float = 0.85
## Dev switch (`--boss`): skip the waves and fight only the stage bosses.
var boss_rush: bool = false

## Set by the game scene when a run ends, read by the title screen.
var last_run_score: int = 0
var last_run_stage: int = 0
var last_run_cleared: bool = false
var last_run_ship: int = 0
## Endless only: how many times the stage list was looped.
var last_run_loop: int = 0
## Rank just earned, or -1 when the run did not place.
var last_run_rank: int = -1


## Screenshot support: F12 saves to user://, or `--shot=PATH --shot-at=FRAME`
## grabs one automatically (handy for capturing stills without a human at the
## keyboard).
var _shot_path := ""
var _shot_at := -1
var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_input_map()
	for key in MODE_KEYS:
		tables[key] = DEFAULT_TABLE.duplicate(true)
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


func mode_key(m: int = -1) -> String:
	return MODE_KEYS[clampi(m if m >= 0 else mode, 0, MODE_KEYS.size() - 1)]


func mode_name(m: int = -1) -> String:
	return MODE_NAMES[clampi(m if m >= 0 else mode, 0, MODE_NAMES.size() - 1)]


## The ranking table for a mode (defaults to the current one).
func table(m: int = -1) -> Array:
	return tables[mode_key(m)]


## Kept for the HUD and title, which only ever care about the active mode.
var scores: Array:
	get:
		return table()


## True when `score` is good enough to earn a place in the current table.
func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var t := table()
	return t.size() < TABLE_SIZE or score > int(t[-1].score)


## The rank `score` would take. Used to show "2ND PLACE" during initials entry,
## before the entry actually exists.
## A tie ranks *below* the existing entry, so the earlier run keeps its spot.
func provisional_rank(score: int) -> int:
	var t := table()
	for i in t.size():
		if score > int(t[i].score):
			return i
	return t.size()


## Inserts a run and returns its rank (0-based), or -1 if it did not place.
func insert_score(name: String, score: int, stage: int, ship: int,
		cleared: bool) -> int:
	if not qualifies(score):
		return -1
	var clean := name.strip_edges().substr(0, 3).to_upper()
	var entry := {
		"name": clean if clean != "" else "AAA",
		"score": score, "stage": stage, "ship": ship, "cleared": cleared,
		"loop": last_run_loop,
	}
	var t := table()
	var rank := provisional_rank(score)
	t.insert(rank, entry)
	if t.size() > TABLE_SIZE:
		t.resize(TABLE_SIZE)
	_sync_hi()
	_save()
	return rank


## Switching modes re-points hi_score at that mode's table.
func set_mode(m: int) -> void:
	mode = clampi(m, 0, MODE_KEYS.size() - 1)
	_sync_hi()
	_save()


## Persists settings changed from the pause menu.
func save_settings() -> void:
	_save()


func _sync_hi() -> void:
	var t := table()
	hi_score = int(t[0].score) if not t.is_empty() else 0


# --- Persistence -------------------------------------------------------------

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"tables": tables, "ship": ship_index, "mode": mode,
		"music": music_volume, "sfx": sfx_volume,
	}))
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
		ship_index = clampi(int(data.get("ship", 0)), 0, 2)
		music_volume = clampf(float(data.get("music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(data.get("sfx", sfx_volume)), 0.0, 1.0)
		mode = clampi(int(data.get("mode", Mode.ARCADE)), 0, MODE_KEYS.size() - 1)

		var raw_tables: Variant = data.get("tables", null)
		if raw_tables is Dictionary:
			for key in MODE_KEYS:
				if raw_tables.has(key):
					tables[key] = _parse_table(raw_tables[key])
		elif data.get("scores", null) is Array:
			# Migrate a single-table save: it was all arcade play.
			tables["arcade"] = _parse_table(data.scores)
		elif data.has("hi_score"):
			# Migrate from before the ranking table existed at all.
			var old := int(data.hi_score)
			if old > int(tables["arcade"][0].score):
				tables["arcade"][0] = {"name": "YOU", "score": old, "stage": 0,
					"ship": 0, "cleared": false, "loop": 0}
	_sync_hi()


func _parse_table(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return DEFAULT_TABLE.duplicate(true)
	for e in raw:
		if e is Dictionary and e.has("score"):
			out.append({
				"name": String(e.get("name", "AAA")),
				"score": int(e.get("score", 0)),
				"stage": int(e.get("stage", 0)),
				"ship": int(e.get("ship", 0)),
				"cleared": bool(e.get("cleared", false)),
				"loop": int(e.get("loop", 0)),
			})
	if out.is_empty():
		return DEFAULT_TABLE.duplicate(true)
	out.sort_custom(func(a, b): return a.score > b.score)
	if out.size() > TABLE_SIZE:
		out.resize(TABLE_SIZE)
	return out


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
