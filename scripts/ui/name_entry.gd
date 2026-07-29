class_name NameEntry
extends Cabinet
## Arcade initials entry, shown when a run places in the ranking table.
##
## Up/down cycles the character, left/right moves the cursor, shot confirms.
## A countdown auto-submits so an abandoned cabinet never sits here forever.

signal submitted(initials: String)

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- "
const SLOTS := 3
const TIME_LIMIT := 25.0
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.09

var rank := 0
var score := 0

var _idx: PackedInt32Array = PackedInt32Array()
var _cursor := 0
var _time_left := TIME_LIMIT
var _anim := 0.0
var _ready_input := 0.3
var _hold := 0.0
var _held_dir := 0
var _slots: SlotStrip
var _timer_label: Label


func _ready() -> void:
	build(2)
	_idx.resize(SLOTS)
	for i in SLOTS:
		_idx[i] = 0

	label("RANKING IN", 120.0, 54, Cfg.UI_GOLD)
	label("%s  PLACE" % _ordinal(rank + 1), 196.0, 30, Cfg.UI_ACCENT)
	label(Cfg.fmt_score(score), 250.0, 46, Cfg.UI_TEXT)
	label("ENTER YOUR INITIALS", 372.0, 24, Cfg.UI_DIM)

	_slots = SlotStrip.new()
	_slots.position = Vector2(0, 430.0)
	_slots.size = Vector2(Cfg.FIELD_W, 150.0)
	content.add_child(_slots)

	label("W / S  change letter      A / D  move      J  confirm",
		Cfg.FIELD_H - 200.0, 20, Cfg.UI_DIM)
	_timer_label = label("", Cfg.FIELD_H - 150.0, 26, Cfg.UI_WARN)
	_refresh()


func _process(dt: float) -> void:
	super._process(dt)
	_anim += dt
	_slots.blink = _anim
	_slots.queue_redraw()

	if _ready_input > 0.0:
		_ready_input -= dt
		return

	_time_left -= dt
	_timer_label.text = "TIME  %d" % maxi(ceili(_time_left), 0)
	if _time_left <= 0.0:
		_submit()
		return

	_handle_repeat(dt)

	if Input.is_action_just_pressed("p_left"):
		_move_cursor(-1)
	if Input.is_action_just_pressed("p_right"):
		_move_cursor(1)
	if Input.is_action_just_pressed("p_shot") \
			or Input.is_action_just_pressed("p_start"):
		AU.play("menu_select")
		if _cursor >= SLOTS - 1:
			_submit()
		else:
			_move_cursor(1)
	# Bomb doubles as backspace, so a mistake is fixable without a mouse.
	if Input.is_action_just_pressed("p_bomb") or Input.is_action_just_pressed("p_back"):
		_move_cursor(-1)


## Up/down auto-repeats when held, so scrolling to "Z" is not 26 taps.
func _handle_repeat(dt: float) -> void:
	var dir := 0
	if Input.is_action_pressed("p_up"):
		dir = 1
	elif Input.is_action_pressed("p_down"):
		dir = -1

	if dir == 0:
		_held_dir = 0
		_hold = 0.0
		return
	if dir != _held_dir:
		_held_dir = dir
		_hold = -REPEAT_DELAY
		_cycle(dir)
		return
	_hold += dt
	if _hold >= REPEAT_RATE:
		_hold = 0.0
		_cycle(dir)


func _cycle(dir: int) -> void:
	_idx[_cursor] = posmod(_idx[_cursor] + dir, CHARS.length())
	AU.play("menu_move")
	_refresh()


func _move_cursor(dir: int) -> void:
	_cursor = clampi(_cursor + dir, 0, SLOTS - 1)
	AU.play("menu_move")
	_refresh()


func _refresh() -> void:
	_slots.chars = _text()
	_slots.cursor = _cursor
	_slots.queue_redraw()


func _text() -> String:
	var out := ""
	for i in SLOTS:
		out += CHARS[_idx[i]]
	return out


func _submit() -> void:
	set_process(false)
	AU.play("menu_select")
	submitted.emit(_text().strip_edges())


func _ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "ST"
			2: suffix = "ND"
			3: suffix = "RD"
	return "%d%s" % [n, suffix]


class SlotStrip:
	extends Control
	var chars := "AAA"
	var cursor := 0
	var blink := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var box := Vector2(96.0, 116.0)
		var gap := 26.0
		var total := box.x * chars.length() + gap * (chars.length() - 1)
		var x := (size.x - total) * 0.5

		for i in chars.length():
			var r := Rect2(Vector2(x, 0), box)
			var on := i == cursor
			draw_rect(r, Color(1, 1, 1, 0.06 if not on else 0.13))
			draw_rect(r, Cfg.UI_ACCENT if on else Cfg.UI_LINE, false, 2.0)

			var ch := chars[i]
			var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
			draw_string(f, Vector2(x + (box.x - w) * 0.5, 86.0), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 72,
				Cfg.UI_TEXT if not on else Cfg.UI_GOLD)

			if on:
				# Caret plus arrows, hinting that up/down changes the letter.
				var a: float = 0.35 + 0.65 * absf(sin(blink * 5.0))
				draw_rect(Rect2(Vector2(x, box.y + 8.0), Vector2(box.x, 4.0)),
					Color(Cfg.UI_GOLD.r, Cfg.UI_GOLD.g, Cfg.UI_GOLD.b, a))
				_caret(Vector2(x + box.x * 0.5, -16.0), -1.0, a)
				_caret(Vector2(x + box.x * 0.5, box.y + 34.0), 1.0, a)
			x += box.x + gap

	func _caret(at: Vector2, dir: float, a: float) -> void:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, 9 * dir), at + Vector2(-11, -5 * dir),
			at + Vector2(11, -5 * dir),
		]), Color(Cfg.UI_ACCENT.r, Cfg.UI_ACCENT.g, Cfg.UI_ACCENT.b, a))
