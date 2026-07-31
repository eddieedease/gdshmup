class_name Cabinet
extends Node2D
## Shared arcade-cabinet frame for the menu screens.
##
## Builds the same geometry the game uses - scrolling terrain inside an 810px
## centre column, opaque sidebars either side - so the title and ship select
## feel like part of the same machine.

var field: Node2D
var terrain: Terrain
var content: Control      ## Menu UI, sized to the playfield, drawn on top.

var _layer: CanvasLayer
var _left: Hud.PanelBox
var _right: Hud.PanelBox
var _bezel: Hud.Bezel
var _drifters: Array[Sprite2D] = []
var _drift_speed: PackedFloat32Array = PackedFloat32Array()
var _t := 0.0


func build(terrain_stage: int) -> void:
	field = Node2D.new()
	add_child(field)

	terrain = Terrain.new()
	field.add_child(terrain)
	terrain.set_stage(terrain_stage, 4242)

	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.03, 0.07, 0.45)
	wash.size = Vector2(Cfg.FIELD_W, 2000.0)
	wash.z_index = Cfg.Z_DECOR
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(wash)

	var dust := SpeedDust.new()
	dust.speed = terrain.speed * 1.7
	dust.tint = terrain.stage_tint().lightened(0.45)
	field.add_child(dust)

	# Idle traffic: a few ships drifting through the backdrop.
	for i in 5:
		var s := Sprite2D.new()
		s.centered = true
		Art.apply_ship(s, Art.ENEMIES[i % Art.ENEMIES.size()])
		s.frame = 2
		s.scale = Vector2.ONE * randf_range(0.16, 0.30)
		s.modulate = Color(1, 1, 1, 0.22)
		s.z_index = Cfg.Z_DECOR + 1
		s.position = Vector2(randf_range(60, Cfg.FIELD_W - 60),
			randf_range(-400, Cfg.FIELD_H))
		field.add_child(s)
		_drifters.append(s)
		_drift_speed.append(randf_range(110.0, 260.0))

	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)

	_left = Hud.PanelBox.new()
	_left.side = -1
	_layer.add_child(_left)
	_right = Hud.PanelBox.new()
	_right.side = 1
	_layer.add_child(_right)

	_bezel = Hud.Bezel.new()
	_layer.add_child(_bezel)

	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(content)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var rect := Cfg.field_rect(vs)
	var s := rect.size.x / Cfg.FIELD_W
	field.position = rect.position
	field.scale = Vector2.ONE * s
	_left.position = Vector2.ZERO
	_left.size = Vector2(rect.position.x, vs.y)
	_right.position = Vector2(rect.end.x, 0)
	_right.size = Vector2(maxf(vs.x - rect.end.x, 0.0), vs.y)
	_bezel.position = Vector2.ZERO
	_bezel.size = vs
	_bezel.field = rect
	# Menu content is laid out in the same 810x1080 space as the playfield.
	content.position = rect.position
	content.size = Vector2(Cfg.FIELD_W, Cfg.FIELD_H)
	content.scale = Vector2.ONE * s
	_left.queue_redraw()
	_right.queue_redraw()
	_bezel.queue_redraw()
	content.queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	for i in _drifters.size():
		var s := _drifters[i]
		s.position.y += _drift_speed[i] * dt
		s.position.x += sin(_t * 0.8 + i) * 22.0 * dt
		if s.position.y > Cfg.FIELD_H + 120.0:
			s.position = Vector2(randf_range(60, Cfg.FIELD_W - 60), -160.0)
			s.frame = 2


## Convenience for menu labels laid out inside `content`.
func label(text: String, y: float, size: int, col: Color,
		parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", PixelFont.get_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var host: Control = parent if parent != null else content
	host.add_child(l)
	l.position = Vector2(0, y)
	l.size = Vector2(Cfg.FIELD_W, size + 10)
	return l
