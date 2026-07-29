class_name ShipSelect
extends Cabinet
## Pick one of the three hulls. Shows the stat spread and, more importantly,
## what each of the two fire modes actually does.

signal confirmed(index: int)
signal cancelled()

var _sel := 0
var _sprites: Array[Sprite2D] = []
var _name: Label
var _code: Label
var _tag: Label
var _blurb: Label
var _shot_line: Label
var _laser_line: Label
var _stats: StatBlock
var _time := 0.0
var _ready_input := 0.25


func _ready() -> void:
	build(1)
	_sel = GS.ship_index

	label("SELECT YOUR SHIP", 96.0, 46, Cfg.UI_ACCENT)

	for i in ShipDefs.count():
		var ship := ShipDefs.get_ship(i)
		var s := Sprite2D.new()
		s.centered = true
		Art.apply_ship(s, Art.PLAYER_SHIPS[ship.tex])
		s.position = Vector2(Cfg.FIELD_W * (0.2 + 0.3 * i), 300.0)
		s.z_index = Cfg.Z_PLAYER
		field.add_child(s)
		_sprites.append(s)

	_code = label("", 400.0, 20, Cfg.UI_DIM)
	_name = label("", 430.0, 56, Cfg.UI_TEXT)
	_tag = label("", 498.0, 22, Cfg.UI_ACCENT)

	_stats = StatBlock.new()
	_stats.position = Vector2(Cfg.FIELD_W * 0.28, 552.0)
	_stats.size = Vector2(Cfg.FIELD_W * 0.44, 130.0)
	content.add_child(_stats)

	_blurb = label("", 700.0, 21, Cfg.UI_TEXT)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.size = Vector2(Cfg.FIELD_W, 70.0)

	_shot_line = label("", 800.0, 20, Cfg.UI_TEXT)
	_laser_line = label("", 834.0, 20, Cfg.UI_TEXT)

	label("A / D  or  ARROWS  to choose      J / ENTER  confirm      ESC  back",
		Cfg.FIELD_H - 140.0, 20, Cfg.UI_DIM)
	label("SHOT keeps you fast. LASER halves your speed but concentrates damage.",
		Cfg.FIELD_H - 104.0, 17, Cfg.UI_DIM)

	_refresh()


func _process(dt: float) -> void:
	super._process(dt)
	_time += dt

	for i in _sprites.size():
		var s := _sprites[i]
		var on := i == _sel
		var target := 0.44 if on else 0.28
		s.scale = s.scale.lerp(Vector2.ONE * target, clampf(dt * 10.0, 0, 1))
		s.frame = 2 + (int(_time * 14.0) % 2)
		s.modulate = Color(1, 1, 1, 1.0) if on else Color(0.55, 0.6, 0.72, 0.75)
		s.position.y = 300.0 + (sin(_time * 2.4 + i) * 10.0 if on else 0.0)

	if _ready_input > 0.0:
		_ready_input -= dt
		return

	if Input.is_action_just_pressed("p_left") or Input.is_action_just_pressed("ui_left"):
		_sel = posmod(_sel - 1, ShipDefs.count())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_right") or Input.is_action_just_pressed("ui_right"):
		_sel = posmod(_sel + 1, ShipDefs.count())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_start"):
		AU.play("menu_select")
		GS.ship_index = _sel
		confirmed.emit(_sel)
	elif Input.is_action_just_pressed("p_back"):
		cancelled.emit()


func _refresh() -> void:
	var ship := ShipDefs.get_ship(_sel)
	_code.text = String(ship.code)
	_name.text = String(ship.name)
	_name.add_theme_color_override("font_color", ship.color)
	_tag.text = String(ship.tag)
	_blurb.text = String(ship.blurb)

	var n: Array = ship.shot_n
	_shot_line.text = "J  SHOT    %d-way spread  -  %d px/s hull speed" \
		% [int(n[n.size() - 1]), int(ship.speed_shot)]
	var lw: Array = ship.laser_width
	_laser_line.text = "K  LASER   %d px beam  -  %d px/s focused speed" \
		% [int(lw[lw.size() - 1]), int(ship.speed_laser)]

	_stats.stats = ship.stats
	_stats.col = ship.color
	_stats.queue_redraw()


class StatBlock:
	extends Control
	var stats: Dictionary = {}
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var y := 0.0
		for k in stats:
			draw_string(f, Vector2(0, y + 18), String(k),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Cfg.UI_DIM)
			var v := int(stats[k])
			for i in 5:
				var r := Rect2(Vector2(150.0 + i * 34.0, y + 2), Vector2(28, 18))
				draw_rect(r, col if i < v else Color(1, 1, 1, 0.10))
				draw_rect(r, Color(1, 1, 1, 0.20), false, 1.0)
			y += 34.0
