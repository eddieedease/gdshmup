class_name OptionBit
extends Node2D
## A satellite gun that trails the ship.
##
## Bits live in playfield space (not parented to the ship) so they lag behind
## during movement. They fan out in SHOT mode and tuck in tight in LASER mode,
## which is what makes the two weapons feel spatially different.

var side := 1.0            ## -1 left, +1 right.
var offset := Vector2.ZERO ## Current target offset from the ship.
var fire_timer := 0.0

var beam: Beam
## Fraction of the main beam's dps this bit contributes; set by the ship so the
## bits always share one budget between them.
var beam_share := 0.45

var _orb: Sprite2D
var _t := 0.0


func setup(colour: Color, s: float) -> void:
	side = s
	z_index = Cfg.Z_PLAYER - 1
	beam = Beam.new()
	_orb = Sprite2D.new()
	_orb.centered = true
	Art.apply_sheet(_orb, "plasma", true)
	_orb.scale = Vector2.ONE * 0.13
	_orb.modulate = colour
	add_child(_orb)
	add_child(beam)
	beam.z_index = -1


func _process(dt: float) -> void:
	_t += dt
	if is_instance_valid(_orb):
		_orb.frame = int(_t * 14.0) % 4
		_orb.rotation = _t * 3.0


## Eases toward the ship's position plus the mode-dependent offset.
func follow(anchor: Vector2, target_offset: Vector2, dt: float) -> void:
	offset = offset.lerp(target_offset, clampf(dt * 9.0, 0.0, 1.0))
	position = position.lerp(anchor + offset, clampf(dt * 13.0, 0.0, 1.0))
