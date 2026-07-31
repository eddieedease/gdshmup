class_name Item
extends Node2D
## A collectible dropped by destroyed enemies.
##
## Items are drawn procedurally (there is no pickup art in assets/) as a rotating
## gem with a letter. They pop outward, settle into a downward drift, and are
## magnetised to the player when close — or from anywhere while a bomb is active.

enum Kind { POWER, BOMB, EXTEND, STAR, BIG_STAR, WEAPON }

const LABELS := {
	Kind.POWER: "P",
	Kind.BOMB: "B",
	Kind.EXTEND: "1UP",
	Kind.STAR: "",
	Kind.BIG_STAR: "",
	Kind.WEAPON: "W",
}
const COLORS := {
	Kind.POWER: Color(1.0, 0.45, 0.25),
	Kind.BOMB: Color(0.45, 0.75, 1.0),
	Kind.EXTEND: Color(0.45, 1.0, 0.55),
	Kind.STAR: Color(1.0, 0.85, 0.35),
	Kind.BIG_STAR: Color(1.0, 0.65, 0.9),
	# Deliberately close to Cfg.TRACK_TINT: the pickup and the fire it grants
	# are the same colour, which is the whole hint.
	Kind.WEAPON: Color(0.66, 0.42, 1.0),
}
const SIZES := {
	Kind.POWER: 15.0,
	Kind.BOMB: 15.0,
	Kind.EXTEND: 18.0,
	Kind.STAR: 5.5,
	Kind.BIG_STAR: 8.5,
	Kind.WEAPON: 17.0,
}

var kind: int = Kind.POWER
var vel := Vector2.ZERO
var alive := true
var magnet := false
var age := 0.0
var value := 0

var _radius := 15.0
var _col := Color.WHITE
var _font: Font


func setup(k: int, pos: Vector2, launch: Vector2) -> void:
	kind = k
	position = pos
	vel = launch
	_radius = SIZES[k]
	_col = COLORS[k]
	_font = PixelFont.get_font()
	z_index = Cfg.Z_ITEM
	value = 500 if k == Kind.STAR else (5000 if k == Kind.BIG_STAR else 0)


func step(dt: float, player_pos: Vector2, magnet_all: bool) -> void:
	age += dt
	if magnet_all:
		magnet = true
	elif not magnet and position.distance_squared_to(player_pos) < 150.0 * 150.0:
		magnet = true

	if magnet:
		var to := (player_pos - position)
		var d := to.length()
		vel = vel.lerp(to.normalized() * 900.0, clampf(dt * 9.0, 0.0, 1.0))
		if d < 24.0:
			alive = false
	else:
		# Pop out, slow down, then fall.
		vel.x = move_toward(vel.x, 0.0, 340.0 * dt)
		vel.y = move_toward(vel.y, 130.0, 620.0 * dt)
		position.x = clampf(position.x + vel.x * dt, 12.0, Cfg.FIELD_W - 12.0)
		position.y += vel.y * dt
		queue_redraw()
		if position.y > Cfg.FIELD_H + 60.0:
			alive = false
		return

	position += vel * dt
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(age * 8.0) * 0.08
	var r := _radius * pulse
	if kind == Kind.STAR or kind == Kind.BIG_STAR:
		# Kept small and softly lit: these appear in bulk on every kill, so a
		# bright halo each read as an explosion of its own.
		var glow := _col
		glow.a = 0.18
		draw_circle(Vector2.ZERO, r * 1.5, glow)
		draw_circle(Vector2.ZERO, r, Color(_col.r, _col.g, _col.b, 0.85))
		draw_circle(Vector2.ZERO, r * 0.4, Color(1, 1, 1, 0.75))
		return

	var pts := PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0),
	])
	var glow2 := _col
	glow2.a = 0.28
	draw_circle(Vector2.ZERO, r * 1.9, glow2)
	draw_colored_polygon(pts, _col)
	draw_polyline(PackedVector2Array([
		pts[0], pts[1], pts[2], pts[3], pts[0],
	]), Color(1, 1, 1, 0.85), 2.0)

	var label: String = LABELS[kind]
	if label != "":
		var fs := 15 if kind != Kind.EXTEND else 12
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(-w * 0.5, fs * 0.38), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.06, 0.04, 0.02))
