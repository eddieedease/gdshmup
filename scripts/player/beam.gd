class_name Beam
extends Node2D
## A vertical laser column drawn by tiling laserbeam.png upward.
##
## The sheet is a single row of four 256px frames, so setting a region taller
## than one frame with repeat enabled wraps the frame vertically into a
## seamless beam of any length. A wider, dimmer copy sits behind the core to
## give the beam a glow instead of a hard edge.

const FRAME := 256.0
const FRAMES := 4
const FPS := 18.0
const GLOW_SCALE := 2.4

var width := 24.0
var length := 0.0

var _core: Sprite2D
var _glow: Sprite2D
var _t := 0.0
var _frame := 0


func _ready() -> void:
	visible = false


func _make_sprite(w_mul: float, alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tintable(Art.LASERBEAM)
	s.centered = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.set_meta("w_mul", w_mul)
	s.set_meta("alpha", alpha)
	add_child(s)
	return s


func configure(w: float, col: Color) -> void:
	width = w
	if _glow == null:
		_glow = _make_sprite(GLOW_SCALE, 0.30)
		_core = _make_sprite(1.0, 1.0)
	_glow.modulate = Color(col.r, col.g, col.b, col.a * 0.30)
	_core.modulate = col


## Points the beam upward from the owner, `len` pixels long.
func set_length(len: float) -> void:
	length = maxf(len, 0.0)
	if _core == null:
		return
	for s in [_glow, _core]:
		var w: float = width * float(s.get_meta("w_mul"))
		var sc := w / FRAME
		s.scale = Vector2(sc, sc)
		s.region_rect = Rect2(_frame * FRAME, 0.0, FRAME,
			length / maxf(sc, 0.0001))
		s.position = Vector2(0.0, -length * 0.5)


func _process(dt: float) -> void:
	if not visible or _core == null:
		return
	_t += dt
	var f := int(_t * FPS) % FRAMES
	if f != _frame:
		_frame = f
		_glow.region_rect.position.x = _frame * FRAME
		_core.region_rect.position.x = _frame * FRAME
