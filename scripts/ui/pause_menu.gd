class_name PauseMenu
extends CanvasLayer
## In-run pause screen with the audio mixer.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps working while the rest of the tree
## is frozen. Volume changes apply live, so you can hear what you are setting.

signal resume_requested()
signal quit_requested()

enum Row { RESUME, MUSIC, SFX, QUIT }

const ROWS := [
	{"id": Row.RESUME, "label": "RESUME", "slider": false},
	{"id": Row.MUSIC, "label": "MUSIC", "slider": true},
	{"id": Row.SFX, "label": "SOUND FX", "slider": true},
	{"id": Row.QUIT, "label": "QUIT TO TITLE", "slider": false},
]
const STEP := 0.1
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.07

var _panel: MenuPanel
var _sel := 0
var _t := 0.0
var _hold := 0.0
var _held_dir := 0
var _open_guard := 0.0


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = MenuPanel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_panel.field = Cfg.field_rect(vs)
	_panel.view = vs
	_panel.queue_redraw()


func open() -> void:
	visible = true
	_sel = 0
	_t = 0.0
	# Swallow the keypress that opened the menu so it does not also select.
	_open_guard = 0.18
	_refresh()


func close() -> void:
	visible = false
	GS.save_settings()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	_panel.blink = _t
	_panel.queue_redraw()

	if _open_guard > 0.0:
		_open_guard -= dt
		return

	if Input.is_action_just_pressed("p_down") or Input.is_action_just_pressed("ui_down"):
		_sel = posmod(_sel + 1, ROWS.size())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_up") or Input.is_action_just_pressed("ui_up"):
		_sel = posmod(_sel - 1, ROWS.size())
		AU.play("menu_move")
		_refresh()

	_handle_slider(dt)

	if Input.is_action_just_pressed("p_start") or Input.is_action_just_pressed("p_shot"):
		match int(ROWS[_sel].id):
			Row.RESUME:
				AU.play("menu_select")
				resume_requested.emit()
			Row.QUIT:
				AU.play("menu_select")
				quit_requested.emit()
			_:
				pass
	elif Input.is_action_just_pressed("p_pause"):
		resume_requested.emit()


## Left/right adjusts the highlighted slider, with auto-repeat when held.
func _handle_slider(dt: float) -> void:
	if not bool(ROWS[_sel].slider):
		_held_dir = 0
		return
	var dir := 0
	if Input.is_action_pressed("p_right"):
		dir = 1
	elif Input.is_action_pressed("p_left"):
		dir = -1

	if dir == 0:
		_held_dir = 0
		_hold = 0.0
		return
	if dir != _held_dir:
		_held_dir = dir
		_hold = -REPEAT_DELAY
		_nudge(dir)
		return
	_hold += dt
	if _hold >= REPEAT_RATE:
		_hold = 0.0
		_nudge(dir)


func _nudge(dir: int) -> void:
	var id := int(ROWS[_sel].id)
	if id == Row.MUSIC:
		GS.music_volume = clampf(
			snappedf(GS.music_volume + dir * STEP, STEP), 0.0, 1.0)
	else:
		GS.sfx_volume = clampf(
			snappedf(GS.sfx_volume + dir * STEP, STEP), 0.0, 1.0)
	AU.apply_volumes()
	# Audible feedback on the channel being changed.
	AU.play("menu_move" if id == Row.MUSIC else "item")
	_refresh()


func _refresh() -> void:
	_panel.sel = _sel
	_panel.music = GS.music_volume
	_panel.sfx = GS.sfx_volume
	_panel.queue_redraw()


class MenuPanel:
	extends Control
	var field := Rect2(555, 0, Cfg.FIELD_W, Cfg.FIELD_H)
	var view := Vector2(1920, 1080)
	var sel := 0
	var music := 0.75
	var sfx := 0.85
	var blink := 0.0

	func _draw() -> void:
		var f := PixelFont.get_font()
		# Dim the whole cabinet, not just the playfield.
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.02, 0.04, 0.72))

		var w := 560.0
		var h := 430.0
		var box := Rect2(field.get_center() - Vector2(w, h) * 0.5, Vector2(w, h))
		draw_rect(box, Cfg.UI_PANEL)
		draw_rect(box, Cfg.UI_ACCENT, false, 3.0)

		_centre(f, "PAUSED", box.position.y + 62.0, 44, Cfg.UI_ACCENT, box)

		var y := box.position.y + 130.0
		for i in ROWS.size():
			var row: Dictionary = ROWS[i]
			var on := i == sel
			var col := Cfg.UI_GOLD if on else Cfg.UI_TEXT
			var lx := box.position.x + 52.0

			if on:
				var a: float = 0.4 + 0.6 * absf(sin(blink * 5.0))
				draw_rect(Rect2(Vector2(box.position.x + 20.0, y - 22.0),
					Vector2(w - 40.0, 46.0)),
					Color(Cfg.UI_GOLD.r, Cfg.UI_GOLD.g, Cfg.UI_GOLD.b, 0.14 * a))
				draw_string(f, Vector2(lx - 28.0, y + 8.0), ">",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Cfg.UI_GOLD)

			draw_string(f, Vector2(lx, y + 8.0), String(row.label),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)

			if bool(row.slider):
				var v: float = music if int(row.id) == Row.MUSIC else sfx
				_slider(Vector2(box.position.x + 280.0, y - 6.0), 190.0, v, col, f)
			y += 66.0

		_centre(f, "W / S  SELECT     A / D  ADJUST",
			box.position.y + h - 58.0, 16, Cfg.UI_DIM, box)
		_centre(f, "J  CONFIRM     ESC  RESUME",
			box.position.y + h - 34.0, 16, Cfg.UI_DIM, box)

	## Ten segments: readable at a glance and matches the 0.1 step size.
	func _slider(at: Vector2, width: float, value: float, col: Color,
			f: Font) -> void:
		var segs := 10
		var gap := 3.0
		var sw := (width - gap * (segs - 1)) / segs
		var lit := int(round(value * segs))
		for i in segs:
			var r := Rect2(at + Vector2(i * (sw + gap), 0), Vector2(sw, 20.0))
			draw_rect(r, col if i < lit else Color(1, 1, 1, 0.12))
		var pct := "%d" % roundi(value * 100.0)
		draw_string(f, at + Vector2(width + 16.0, 17.0), pct,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)

	func _centre(f: Font, text: String, y: float, s: int, col: Color,
			box: Rect2) -> void:
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		draw_string(f, Vector2(box.position.x + (box.size.x - tw) * 0.5, y),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
