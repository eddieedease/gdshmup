class_name Art
extends RefCounted
## Central registry for every sprite sheet in assets/.
##
## All sheets use 256x256 frames laid out row-major (see the .json sidecars next
## to each .png). SHEETS records the grid so Sprite2D nodes can be configured
## from a single name instead of repeating hframes/vframes everywhere.

const FRAME := 256.0

const PLAYER_SHIPS := [
	preload("res://assets/playership/player_cyanship.png"),
	preload("res://assets/playership/player_redship.png"),
	preload("res://assets/playership/player_yellow.png"),
]

const ENEMIES := [
	preload("res://assets/enemy/enemy_1.png"),
	preload("res://assets/enemy/enemy_2.png"),
	preload("res://assets/enemy/enemy_3.png"),
	preload("res://assets/enemy/enemy_4.png"),
	preload("res://assets/enemy/enemy_5.png"),
	preload("res://assets/enemy/enemy_6.png"),
	preload("res://assets/enemy/enemy_7.png"),
	preload("res://assets/enemy/enemy_8.png"),
	preload("res://assets/enemy/enemy_9.png"),
]

const BOLT := preload("res://assets/bullets/bolt.png")
const LASER := preload("res://assets/bullets/laser.png")
const LASERBEAM := preload("res://assets/bullets/laserbeam.png")
const MISSILE := preload("res://assets/bullets/missile.png")
const PLASMA := preload("res://assets/bullets/plasma_orb.png")
const WAVEBEAM := preload("res://assets/bullets/wavebeam.png")
const SPREAD := preload("res://assets/bullets/3wayshot.png")

const ENEMY_SHOT := preload("res://assets/effects/enemey_shoot.png")
const HITSPARK := preload("res://assets/effects/hitspark.png")
const MUZZLE := preload("res://assets/effects/muzzle.png")
const SHIELD := preload("res://assets/effects/shield.png")

const TERRAIN := {
	"grass": preload("res://assets/terrain/grass.png"),
	"dirt": preload("res://assets/terrain/dirt.png"),
	"water": preload("res://assets/terrain/water.png"),
	"sand": preload("res://assets/terrain/sand.png"),
	"stone": preload("res://assets/terrain/stone.png"),
	"cobble": preload("res://assets/terrain/cobble.png"),
	"snow": preload("res://assets/terrain/snow.png"),
	"wood": preload("res://assets/terrain/wood.png"),
	"swamp": preload("res://assets/terrain/swamp.png"),
}

## name -> [texture, hframes, vframes, fps]
const SHEETS := {
	"bolt": [BOLT, 2, 1, 12.0],
	"laser": [LASER, 2, 1, 12.0],
	"laserbeam": [LASERBEAM, 4, 1, 16.0],
	"missile": [MISSILE, 4, 1, 14.0],
	"plasma": [PLASMA, 4, 1, 14.0],
	"wavebeam": [WAVEBEAM, 4, 1, 14.0],
	"spread": [SPREAD, 2, 1, 12.0],
	"enemyshot": [ENEMY_SHOT, 4, 1, 14.0],
	"hitspark": [HITSPARK, 4, 1, 16.0],
	"muzzle": [MUZZLE, 3, 1, 18.0],
	"shield": [SHIELD, 4, 1, 10.0],
}


## Cache for the desaturated copies produced by tintable().
static var _tintable: Dictionary = {}


## Returns a luminance-only copy of `tex`, normalised so its brightest pixel is
## white. The projectile art is all warm orange, which turns any `modulate` tint
## muddy (a cyan tint over orange reads as green). Stripping the hue first means
## Cfg.BULLET_COLORS come out exactly as specified while the original shading
## and outlines survive.
static func tintable(tex: Texture2D) -> Texture2D:
	var key := tex.get_rid().get_id()
	if _tintable.has(key):
		return _tintable[key]

	var img := tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	var peak := 0.0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.02:
				peak = maxf(peak, c.r * 0.36 + c.g * 0.5 + c.b * 0.14)
	var gain: float = 1.0 / maxf(peak, 0.001)

	for y in h:
		for x in w:
			var c2 := img.get_pixel(x, y)
			if c2.a <= 0.0:
				continue
			var v: float = clampf(
				(c2.r * 0.36 + c2.g * 0.5 + c2.b * 0.14) * gain, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, c2.a))

	var out := ImageTexture.create_from_image(img)
	_tintable[key] = out
	return out


## Configures a Sprite2D from a SHEETS entry. Returns the frame count.
## Pass `tint` for art that will be recoloured via `modulate`.
static func apply_sheet(spr: Sprite2D, name: String, tint: bool = false) -> int:
	var s: Array = SHEETS[name]
	spr.texture = tintable(s[0]) if tint else s[0]
	spr.hframes = s[1]
	spr.vframes = s[2]
	return int(s[1]) * int(s[2])


static func sheet_fps(name: String) -> float:
	return SHEETS[name][3]


## Ship/enemy sheets are all 2 cols x 3 rows: rows 0 and 2 are the two banked
## poses, row 1 is level, and each row holds a 2-frame thruster cycle.
static func apply_ship(spr: Sprite2D, tex: Texture2D) -> void:
	spr.texture = tex
	spr.hframes = 2
	spr.vframes = 3


## Bank row (0/1/2) for a horizontal input or velocity in [-1, 1].
##
## The .json sidecars label row 0 "bank left" and row 2 "bank right", but the
## art is the other way round - row 0 leans right. The mapping below follows the
## pixels, not the metadata.
static func bank_row(x: float) -> int:
	if x < -0.25:
		return 2
	if x > 0.25:
		return 0
	return 1
