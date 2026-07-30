class_name Cfg
extends RefCounted
## Global tuning constants and the playfield geometry.
##
## The game is designed for a 1920x1080 canvas. The playfield is a fixed
## 810x1080 rectangle (classic 3:4 arcade "tate" aspect) centred horizontally;
## whatever is left over becomes the two sidebars. Because the project stretch
## aspect is "expand", the real viewport width varies per monitor, so the
## horizontal offset is resolved at runtime by field_x().

const DESIGN_W := 1920.0
const DESIGN_H := 1080.0

const FIELD_W := 810.0
const FIELD_H := 1080.0

## Enemies/bullets are culled once they leave this margin around the field.
const CULL_MARGIN := 140.0

## How far above the field enemies may spawn without being culled immediately.
const SPAWN_Y := -120.0

const MAX_ENEMY_BULLETS := 3000
const MAX_PLAYER_BULLETS := 400

## Player hitbox radius. Tiny, as danmaku demands.
const PLAYER_HITBOX := 5.0
## Radius within which passing bullets award graze points.
const GRAZE_RADIUS := 34.0

## Three bars of four. Reaching the top of bar one used to be the whole ramp;
## bars two and three keep the run growing well past that point.
const POWER_PER_BAR := 4
const POWER_BARS := 3
const MAX_POWER := POWER_PER_BAR * POWER_BARS

const CHAIN_TIMEOUT := 1.35

# --- Hyper ------------------------------------------------------------------
## The meter fills through normal play and fires itself when it tops out.
const HYPER_TIME := 9.0
const HYPER_CHARGE_KILL := 0.010
const HYPER_CHARGE_GRAZE := 0.0015
const HYPER_CHARGE_ITEM := 0.003
## Enemy bullets inside this radius are absorbed for score while hyper is up.
const HYPER_ABSORB_RADIUS := 190.0
const HYPER_FIRE_BOOST := 0.62   ## Cooldown multiplier: lower is faster.
const HYPER_ABSORB_SCORE := 400

const EXTEND_SCORES := [2_000_000, 5_000_000, 10_000_000]

# --- Palette -----------------------------------------------------------------

const UI_BG := Color(0.043, 0.047, 0.078)
const UI_PANEL := Color(0.071, 0.078, 0.125)
const UI_LINE := Color(0.243, 0.290, 0.451)
const UI_TEXT := Color(0.851, 0.886, 1.0)
const UI_DIM := Color(0.443, 0.490, 0.639)
const UI_ACCENT := Color(0.361, 0.878, 1.0)
const UI_WARN := Color(1.0, 0.352, 0.451)
const UI_GOLD := Color(1.0, 0.796, 0.278)

const BULLET_COLORS := {
	"pink": Color(1.0, 0.42, 0.78),
	"blue": Color(0.42, 0.72, 1.0),
	"cyan": Color(0.40, 1.0, 0.95),
	"green": Color(0.52, 1.0, 0.58),
	"amber": Color(1.0, 0.78, 0.30),
	"violet": Color(0.74, 0.52, 1.0),
	"red": Color(1.0, 0.36, 0.32),
	"white": Color(1.0, 1.0, 1.0),
}

# --- Z ordering --------------------------------------------------------------

const Z_TERRAIN := -40
const Z_DECOR := -20
const Z_ITEM := 4
const Z_ENEMY := 8
const Z_PBULLET := 12
const Z_PLAYER := 16
const Z_EBULLET := 24
const Z_FX := 32
const Z_OVERLAY := 48


static func color_of(name: String) -> Color:
	return BULLET_COLORS.get(name, Color.WHITE)


## Left edge of the playfield inside the current viewport.
static func field_x(viewport_size: Vector2) -> float:
	return floor((viewport_size.x - FIELD_W) * 0.5)


## Clamps a position to the playfield with a small inset.
static func clamp_to_field(p: Vector2, inset: float) -> Vector2:
	return Vector2(
		clampf(p.x, inset, FIELD_W - inset),
		clampf(p.y, inset, FIELD_H - inset)
	)


static func in_field(p: Vector2, margin: float = CULL_MARGIN) -> bool:
	return p.x > -margin and p.x < FIELD_W + margin \
		and p.y > -margin and p.y < FIELD_H + margin


## Formats a score with thousands separators, arcade style.
static func fmt_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
