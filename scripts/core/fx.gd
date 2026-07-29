class_name FxLayer
extends Node2D
## Pooled one-shot visual effects: hit sparks, muzzle flashes, explosions,
## shockwave rings and floating score popups.

const SPARK_POOL := 220
const RING_POOL := 40
const POPUP_POOL := 40

class OneShot:
	extends Sprite2D
	var age := 0.0
	var dur := 0.3
	var fps := 16.0
	var frames := 4
	var vel := Vector2.ZERO
	var drag := 0.0
	var grow := 0.0
	var fade := true
	var busy := false

	func run(dt: float) -> bool:
		age += dt
		if age >= dur:
			return false
		var t := age / dur
		frame = mini(frames - 1, int(age * fps))
		if vel != Vector2.ZERO:
			position += vel * dt
			vel = vel.lerp(Vector2.ZERO, clampf(drag * dt, 0.0, 1.0))
		if grow != 0.0:
			scale += Vector2.ONE * grow * dt
		if fade:
			modulate.a = 1.0 - t * t
		return true

class Ring:
	extends Node2D
	var age := 0.0
	var dur := 0.45
	var r0 := 10.0
	var r1 := 120.0
	var col := Color.WHITE
	var width := 5.0
	var busy := false

	func _draw() -> void:
		var t: float = clampf(age / dur, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - t, 2.4)
		var c := col
		c.a = (1.0 - t) * 0.9
		draw_arc(Vector2.ZERO, lerpf(r0, r1, e), 0.0, TAU, 48, c,
			width * (1.0 - t * 0.7), true)

	func run(dt: float) -> bool:
		age += dt
		queue_redraw()
		return age < dur

class ScorePopup:
	extends Label
	var age := 0.0
	var dur := 0.9
	var busy := false

	func run(dt: float) -> bool:
		age += dt
		position.y -= 46.0 * dt
		modulate.a = clampf(1.0 - (age / dur), 0.0, 1.0)
		return age < dur

var _sparks: Array[OneShot] = []
var _rings: Array[Ring] = []
var _popups: Array[ScorePopup] = []
var _font: Font


func _ready() -> void:
	z_index = Cfg.Z_FX
	_font = PixelFont.get_font()
	for i in SPARK_POOL:
		var s := OneShot.new()
		s.visible = false
		s.centered = true
		add_child(s)
		_sparks.append(s)
	for i in RING_POOL:
		var r := Ring.new()
		r.visible = false
		add_child(r)
		_rings.append(r)
	for i in POPUP_POOL:
		var p := ScorePopup.new()
		p.visible = false
		p.add_theme_font_override("font", _font)
		p.add_theme_font_size_override("font_size", 22)
		p.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		p.add_theme_constant_override("outline_size", 5)
		add_child(p)
		_popups.append(p)


func _process(dt: float) -> void:
	for s in _sparks:
		if s.busy and not s.run(dt):
			s.busy = false
			s.visible = false
	for r in _rings:
		if r.busy and not r.run(dt):
			r.busy = false
			r.visible = false
	for p in _popups:
		if p.busy and not p.run(dt):
			p.busy = false
			p.visible = false


func _take_spark() -> OneShot:
	for s in _sparks:
		if not s.busy:
			return s
	return null


func _take_ring() -> Ring:
	for r in _rings:
		if not r.busy:
			return r
	return null


## Small flash where a bullet connects.
func spark(pos: Vector2, col: Color = Color.WHITE, size: float = 0.16) -> void:
	var s := _take_spark()
	if s == null:
		return
	s.frames = Art.apply_sheet(s, "hitspark", true)
	s.fps = 26.0
	s.dur = 0.16
	s.age = 0.0
	s.position = pos
	s.rotation = randf() * TAU
	s.scale = Vector2.ONE * size
	s.modulate = col
	s.vel = Vector2.ZERO
	s.grow = 0.0
	s.busy = true
	s.visible = true


## Muzzle flash oriented along a heading.
func muzzle(pos: Vector2, heading: float, col: Color = Color.WHITE,
		size: float = 0.16) -> void:
	var s := _take_spark()
	if s == null:
		return
	s.frames = Art.apply_sheet(s, "muzzle", true)
	s.fps = 34.0
	s.dur = 0.09
	s.age = 0.0
	s.position = pos
	s.rotation = heading + PI * 0.5
	s.scale = Vector2.ONE * size
	s.modulate = col
	s.vel = Vector2.ZERO
	s.grow = 0.0
	s.busy = true
	s.visible = true


## Expanding ring. Used for explosions, bombs and boss deaths.
func shockwave(pos: Vector2, r1: float, col: Color = Color.WHITE,
		dur: float = 0.45, width: float = 6.0) -> void:
	var r := _take_ring()
	if r == null:
		return
	r.position = pos
	r.age = 0.0
	r.dur = dur
	r.r0 = r1 * 0.12
	r.r1 = r1
	r.col = col
	r.width = width
	r.busy = true
	r.visible = true


## Full explosion: core flash, shrapnel sparks and a shockwave.
func explode(pos: Vector2, size: float = 1.0, col: Color = Color(1, 0.72, 0.3)) -> void:
	var core := _take_spark()
	if core:
		core.frames = Art.apply_sheet(core, "hitspark", true)
		core.fps = 15.0
		core.dur = 0.30
		core.age = 0.0
		core.position = pos
		core.rotation = randf() * TAU
		core.scale = Vector2.ONE * 0.22 * size
		core.modulate = Color(1, 1, 1, 1)
		core.vel = Vector2.ZERO
		core.grow = 0.35 * size
		core.busy = true
		core.visible = true

	var shards := clampi(int(4 + size * 4.0), 4, 16)
	for i in shards:
		var s := _take_spark()
		if s == null:
			break
		s.frames = Art.apply_sheet(s, "hitspark", true)
		s.fps = randf_range(12.0, 20.0)
		s.dur = randf_range(0.28, 0.55)
		s.age = 0.0
		s.position = pos
		s.rotation = randf() * TAU
		s.scale = Vector2.ONE * randf_range(0.07, 0.15) * size
		s.modulate = col
		var a := randf() * TAU
		s.vel = Vector2.from_angle(a) * randf_range(90.0, 300.0) * size
		s.drag = 3.2
		s.grow = 0.0
		s.busy = true
		s.visible = true

	shockwave(pos, 70.0 * size, col.lightened(0.35), 0.42, 5.0 * size)


func popup(pos: Vector2, text: String, col: Color = Cfg.UI_GOLD,
		size: int = 22) -> void:
	for p in _popups:
		if p.busy:
			continue
		p.text = text
		p.add_theme_font_size_override("font_size", size)
		p.add_theme_color_override("font_color", col)
		p.reset_size()
		p.position = pos - Vector2(p.size.x * 0.5, p.size.y * 0.5)
		p.age = 0.0
		p.dur = 0.9
		p.modulate = Color(1, 1, 1, 1)
		p.busy = true
		p.visible = true
		return
