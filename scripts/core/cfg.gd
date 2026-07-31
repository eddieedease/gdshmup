class_name Cfg
extends RefCounted
## Global tuning constants and the playfield geometry.
##
## The game is designed for a 1920x1080 canvas. The playfield is a fixed
## 810x1080 rectangle (classic 3:4 arcade "tate" aspect); whatever is left over
## becomes the two sidebars. The project stretch aspect is "expand", so the real
## viewport is exactly 1920x1080 only on a 16:9 display - on anything taller
## (16:10 and 3:2 laptops) Godot hands us the extra height at the bottom, and on
## anything wider it hands us extra width. The field is therefore scaled and
## centred at runtime by field_rect() so it always fills the window height
## instead of leaving a dead strip under it.

const DESIGN_W := 1920.0
const DESIGN_H := 1080.0

const FIELD_W := 810.0
const FIELD_H := 1080.0

## The sidebars never shrink past this, so the HUD stays readable even on a
## window too tall for the field to fill it (see field_scale).
const MIN_SIDEBAR := 300.0

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

## Power items are chips, not whole levels: each bar costs more chips than the
## last, so full power lands around stage three of five instead of stage one.
const POWER_CHIP_COST := [2, 3, 4]

## Bombs stop dropping once you are holding this many. Stockpiling eight of them
## turned every boss into a burn-it-down formality; a hard ceiling of three keeps
## a bomb something you spend rather than something you hoard.
const MAX_BOMBS := 3

const CHAIN_TIMEOUT := 1.35

# --- Weapons -----------------------------------------------------------------
## Weapon items per stage. Two switches is enough to answer "wrong tool for this
## stage" without letting you flip modes fight by fight.
const WEAPON_DROPS_PER_STAGE := 2
## Every Nth meaningful drop in a stage also coughs up a weapon item, until the
## stage's allowance runs out. Deterministic so the pacing is the same each run.
const WEAPON_DROP_EVERY := 4
## Tracking fire is tinted toward this so the mode is readable at a glance.
## Player fire is drawn with BULLET_GAIN and clips toward white, so a pale tint
## would come out looking exactly like a vulcan bolt. This one is kept low in
## red specifically so it survives the clip as violet instead of washing out to
## the magenta hyper already owns.
## The mode's damage cut lives in the per-ship `track_*` arrays in ShipDefs.
const TRACK_TINT := Color(0.55, 0.25, 1.0)
## Missiles that can pile onto a single *ordinary* enemy in one lock volley, so
## a salvo spreads across a wave instead of deleting one popcorn ship. Bosses
## are exempt: they are the target worth emptying the whole rack into.
const LOCK_STACK_MAX := 3

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
## While hyper is up your own fire grows and accelerates. The scale also grows
## the bullet's hitbox, so hyper genuinely lands more hits rather than just
## looking louder.
const HYPER_BULLET_SCALE := 1.5
const HYPER_BULLET_SPEED := 1.35
## Shots blend toward this while hyper, so hyper fire is unmistakably yours.
const HYPER_TINT := Color(1.0, 0.55, 0.95)

## First threshold is deliberately low enough to land around the stage 2 boss;
## the stage 2 and 4 bosses also drop a 1UP outright (BossDefs.drop_extend).
const EXTEND_SCORES := [800_000, 2_500_000, 6_000_000, 11_000_000, 18_000_000]

# --- Palette -----------------------------------------------------------------

const UI_BG := Color(0.043, 0.047, 0.078)
const UI_PANEL := Color(0.071, 0.078, 0.125)
const UI_LINE := Color(0.243, 0.290, 0.451)
const UI_TEXT := Color(0.851, 0.886, 1.0)
const UI_DIM := Color(0.443, 0.490, 0.639)
const UI_ACCENT := Color(0.361, 0.878, 1.0)
const UI_WARN := Color(1.0, 0.352, 0.451)
const UI_GOLD := Color(1.0, 0.796, 0.278)

## Enemy bullet palette. Deliberately free of yellow, gold and orange: those
## are the pickup colours (see Item.COLORS), and a warm bullet in a crowded
## field reads as "fly into me". Everything here is cool or magenta, well clear
## of anything collectable.
const BULLET_COLORS := {
	"pink": Color(1.0, 0.42, 0.78),
	"blue": Color(0.42, 0.72, 1.0),
	"cyan": Color(0.40, 1.0, 0.95),
	"green": Color(0.52, 1.0, 0.58),
	"violet": Color(0.74, 0.52, 1.0),
	"red": Color(1.0, 0.34, 0.40),
	"ember": Color(1.0, 0.30, 0.52),
	"teal": Color(0.30, 0.90, 0.80),
	"indigo": Color(0.55, 0.55, 1.0),
	"white": Color(1.0, 1.0, 1.0),
}

## Bullets are drawn brighter than their nominal colour so they separate from
## the terrain even in a dense curtain.
const BULLET_GAIN := 1.22

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


## Chips needed to climb out of `power` (1-based) into the next level.
static func chip_cost(power: int) -> int:
	var bar: int = clampi((power - 1) / POWER_PER_BAR, 0, POWER_CHIP_COST.size() - 1)
	return POWER_CHIP_COST[bar]


## Total chips required to go from power 1 to full, for reference/tuning.
static func chips_to_max() -> int:
	var total := 0
	for lvl in range(1, MAX_POWER):
		total += chip_cost(lvl)
	return total


static func color_of(name: String) -> Color:
	return BULLET_COLORS.get(name, Color.WHITE)


## Uniform scale that makes the 810x1080 field fill the viewport height, backed
## off if that would squeeze the sidebars past MIN_SIDEBAR.
static func field_scale(viewport_size: Vector2) -> float:
	var fit_h := viewport_size.y / FIELD_H
	var fit_w := (viewport_size.x - MIN_SIDEBAR * 2.0) / FIELD_W
	return maxf(minf(fit_h, fit_w), 0.25)


## The playfield in viewport coordinates: scaled to the window height and
## centred. Everything that must line up with gameplay derives from this.
static func field_rect(viewport_size: Vector2) -> Rect2:
	var s := field_scale(viewport_size)
	var sz := Vector2(FIELD_W, FIELD_H) * s
	return Rect2(Vector2(floor((viewport_size.x - sz.x) * 0.5),
		floor((viewport_size.y - sz.y) * 0.5)), sz)


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
