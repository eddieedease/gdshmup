class_name SpeedDust
extends Node2D
## Parallax streaks blowing past the ship to sell forward motion.
##
## Drawn directly rather than spawned as nodes: a few hundred short lines in one
## _draw call is far cheaper than a particle system, and lets each band pick its
## own speed, length and opacity so the depth cue actually reads.
##
## Bands are ordered far -> near. A separate instance with `foreground = true`
## can be layered in front of the action for the closest, fastest motes.

## [speed multiplier, length multiplier, width, alpha]
## Long, thin and fast. Uniform-alpha dashes read as falling rain; these are
## drawn as tapered quads with a bright head and a tail that fades to nothing,
## which is what makes them read as motion blur instead of weather.
const BANDS := [
	[0.9, 1.5, 1.0, 0.13],
	[1.7, 2.6, 1.6, 0.20],
	[3.0, 4.2, 2.2, 0.28],
]

const COUNT := 110

## Base fall speed, kept in step with the terrain so the layers agree.
var speed := 120.0
var tint := Color(0.85, 0.93, 1.0)
var foreground := false
## Multiplier applied to both travel speed and streak length; ramped during
## stage transitions to stretch the field into a warp.
var warp := 1.0

var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()
var _band: PackedInt32Array = PackedInt32Array()
var _len: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	z_index = (Cfg.Z_FX + 4) if foreground else (Cfg.Z_DECOR + 5)
	_x.resize(COUNT)
	_y.resize(COUNT)
	_band.resize(COUNT)
	_len.resize(COUNT)
	for i in COUNT:
		_band[i] = i % BANDS.size()
		_x[i] = _spawn_x()
		_y[i] = randf_range(-Cfg.FIELD_H, Cfg.FIELD_H)
		_len[i] = randf_range(26.0, 64.0)


## Streaks cluster toward the edges, leaving the middle of the field - where
## bullets have to stay readable - comparatively clear.
func _spawn_x() -> float:
	var side := 1.0 if randf() < 0.5 else -1.0
	return Cfg.FIELD_W * (0.5 + 0.5 * side * pow(randf(), 0.55))


func _process(dt: float) -> void:
	for i in COUNT:
		var band: Array = BANDS[_band[i]]
		_y[i] += speed * float(band[0]) * warp * dt
		if _y[i] > Cfg.FIELD_H + 40.0:
			_y[i] = randf_range(-140.0, -20.0)
			_x[i] = randf_range(0.0, Cfg.FIELD_W)
			_len[i] = randf_range(26.0, 64.0)
	queue_redraw()


func _draw() -> void:
	# Faster travel stretches every streak, so acceleration is visible.
	var stretch: float = clampf(speed / 110.0, 0.6, 2.4) * warp
	var pts := PackedVector2Array()
	pts.resize(4)
	var cols := PackedColorArray()
	cols.resize(4)

	for i in COUNT:
		var band: Array = BANDS[_band[i]]
		var l: float = _len[i] * float(band[1]) * stretch
		var a: float = float(band[3]) * (0.45 if foreground else 1.0)
		var hw: float = float(band[2]) * 0.5
		var x := _x[i]
		var y := _y[i]

		# Travelling downward, so the head is the lower end. The tail vertices
		# are fully transparent, giving a free gradient with no shader.
		pts[0] = Vector2(x - hw * 0.35, y)
		pts[1] = Vector2(x + hw * 0.35, y)
		pts[2] = Vector2(x + hw, y + l)
		pts[3] = Vector2(x - hw, y + l)
		cols[0] = Color(tint.r, tint.g, tint.b, 0.0)
		cols[1] = cols[0]
		cols[2] = Color(tint.r, tint.g, tint.b, a)
		cols[3] = cols[2]
		draw_polygon(pts, cols)
