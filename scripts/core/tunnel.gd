class_name Tunnel
extends Node2D
## Stage-transition tunnel: rings rushing outward from a vanishing point with
## radial streaks between them, so moving from one stage to the next reads as
## flying through something rather than the ground abruptly changing.
##
## Drawn procedurally at Z_FX so it sits over the playfield but under the HUD.
## `intensity` is driven by Game; at 0 it costs a single early return.

const RINGS := 16
const SPOKES := 28
const VANISH := Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.42)
const REACH := 1500.0    ## Ring radius at which a ring has left the screen.

## 0 = off, 1 = full tunnel. Ramped up and down across the transition.
var intensity := 0.0
var tint := Color(0.6, 0.8, 1.0)

var _t := 0.0


func _ready() -> void:
	z_index = Cfg.Z_FX + 2


func _process(dt: float) -> void:
	if intensity <= 0.001:
		return
	# Rushes faster as the effect peaks, which is what sells acceleration.
	_t += dt * (0.7 + 1.5 * intensity)
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.001:
		return

	# Rings. The squared easing bunches them near the vanishing point and
	# stretches them apart as they pass, exactly like passing through a bore.
	for i in RINGS:
		var k := fmod(_t * 0.55 + float(i) / RINGS, 1.0)
		var r: float = pow(k, 2.3) * REACH
		if r < 6.0:
			continue
		var a: float = (1.0 - k) * 0.55 * intensity
		draw_arc(VANISH, r, 0.0, TAU, 48,
			Color(tint.r, tint.g, tint.b, a), 2.0 + 10.0 * k, true)

	# Streaks between the rings, radiating from the same point.
	var pts := PackedVector2Array()
	pts.resize(4)
	var cols := PackedColorArray()
	cols.resize(4)
	for i in SPOKES:
		var ang := TAU * float(i) / SPOKES + _t * 0.12
		var k := fmod(_t * 0.8 + float(i) * 0.137, 1.0)
		var r0: float = pow(k, 2.0) * REACH
		var r1: float = r0 + 90.0 + 420.0 * k
		var dir := Vector2.from_angle(ang)
		var side := Vector2.from_angle(ang + PI * 0.5) * (2.0 + 9.0 * k)
		var a: float = (1.0 - k) * 0.40 * intensity
		pts[0] = VANISH + dir * r0 + side * 0.25
		pts[1] = VANISH + dir * r0 - side * 0.25
		pts[2] = VANISH + dir * r1 - side
		pts[3] = VANISH + dir * r1 + side
		cols[0] = Color(tint.r, tint.g, tint.b, 0.0)
		cols[1] = cols[0]
		cols[2] = Color(tint.r, tint.g, tint.b, a)
		cols[3] = cols[2]
		draw_polygon(pts, cols)

	# Bright core at the vanishing point, so the eye has somewhere to go.
	draw_circle(VANISH, 26.0 * intensity,
		Color(tint.r, tint.g, tint.b, 0.30 * intensity))
	draw_circle(VANISH, 11.0 * intensity, Color(1, 1, 1, 0.55 * intensity))
