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
const BANDS := [
	[0.55, 0.5, 1.0, 0.10],
	[1.05, 1.0, 1.5, 0.16],
	[1.9, 1.9, 2.0, 0.22],
]

const COUNT := 150

## Base fall speed, kept in step with the terrain so the layers agree.
var speed := 120.0
var tint := Color(0.85, 0.93, 1.0)
var foreground := false

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
		_len[i] = randf_range(9.0, 26.0)


## Streaks cluster toward the edges, leaving the middle of the field - where
## bullets have to stay readable - comparatively clear.
func _spawn_x() -> float:
	var side := 1.0 if randf() < 0.5 else -1.0
	return Cfg.FIELD_W * (0.5 + 0.5 * side * pow(randf(), 0.55))


func _process(dt: float) -> void:
	for i in COUNT:
		var band: Array = BANDS[_band[i]]
		_y[i] += speed * float(band[0]) * dt
		if _y[i] > Cfg.FIELD_H + 40.0:
			_y[i] = randf_range(-140.0, -20.0)
			_x[i] = randf_range(0.0, Cfg.FIELD_W)
			_len[i] = randf_range(9.0, 26.0)
	queue_redraw()


func _draw() -> void:
	# Faster travel stretches every streak, so acceleration is visible.
	var stretch: float = clampf(speed / 110.0, 0.6, 2.4)
	for i in COUNT:
		var band: Array = BANDS[_band[i]]
		var l: float = _len[i] * float(band[1]) * stretch
		var a: float = float(band[3]) * (0.45 if foreground else 1.0)
		draw_line(
			Vector2(_x[i], _y[i]), Vector2(_x[i], _y[i] + l),
			Color(tint.r, tint.g, tint.b, a), float(band[2]), false)
