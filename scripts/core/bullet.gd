class_name Bullet
extends Sprite2D
## A single pooled projectile.
##
## Bullets are plain Sprite2D nodes moved by BulletManager rather than physics
## bodies: a bullet-hell stage can hold well over a thousand of them and manual
## integration plus a distance check is both faster and far more predictable
## than the physics server.

## Sprite art points "up" (-Y), so a bullet travelling along `dir` needs its
## rotation offset by a quarter turn.
const ART_OFFSET := PI * 0.5

## Every bullet breathes: scale and brightness oscillate so projectiles read as
## live energy and stay visible against the scrolling ground.
## Curving patterns can orbit inside the playfield indefinitely, so bullets
## time out rather than relying on leaving the screen. The last stretch fades
## so they dissolve instead of blinking out.
const DEFAULT_LIFE := 10.0
const FADE_OUT := 0.7

const PULSE_RATE := 9.5
const PULSE_SCALE := 0.13
const PULSE_BRIGHT := 0.26

var alive := false

var dir := 0.0          ## Heading in radians.
var speed := 0.0
var accel := 0.0        ## Applied to speed each second.
var speed_min := -4000.0
var speed_max := 4000.0
var ang_vel := 0.0      ## Constant turn rate, for curving bullets.

## Homing steers `dir` toward the target at this rate (rad/s) while
## `homing_time` remains.
var homing := 0.0
var homing_time := 0.0
## A specific enemy to chase, overriding the manager's "nearest thing" target.
## Lock-on missiles set this so a salvo stays on the targets it was fired at
## instead of all re-converging on whatever drifts closest.
var seek: Node2D = null

## The bullet hangs motionless for `delay` seconds after spawning, a staple of
## danmaku telegraphing.
var delay := 0.0

## Lateral sine oscillation, perpendicular to `dir`.
var wave_amp := 0.0
var wave_freq := 0.0
var wave_phase := 0.0

var radius := 7.0
var life := DEFAULT_LIFE
var age := 0.0

## Player bullets only.
var damage := 0
var pierce := 0
var hits: Array = []

var spin := 0.0         ## Sprite spin for non-directional art (rad/s).
var face_dir := true    ## Rotate the sprite to match `dir`.
var anim_fps := 12.0
var frames := 1
var grazed := false
var scored := false     ## Marks bullets already converted by a bomb.

## Scatter bullets: after `split_after` seconds the manager replaces this bullet
## with the volley described by `split_spec`. A whole new class of threat for the
## cost of two fields.
var split_after := 0.0
var split_spec: Dictionary = {}

## Pulse state. `base_scale`/`base_color` are the values the pulse modulates
## around, set once at spawn.
var base_scale := Vector2.ONE
var base_color := Color.WHITE
var pulse_phase := 0.0

## Fading streak drawn behind fast bullets. 0 disables it.
var trail_len := 0.0
## Degrees of hue rotation per second. Non-zero gives a shifting "prism" bullet.
var hue_cycle := 0.0


func reset() -> void:
	alive = true
	accel = 0.0
	speed_min = -4000.0
	speed_max = 4000.0
	ang_vel = 0.0
	homing = 0.0
	homing_time = 0.0
	seek = null
	delay = 0.0
	wave_amp = 0.0
	wave_freq = 0.0
	wave_phase = 0.0
	radius = 7.0
	life = DEFAULT_LIFE
	age = 0.0
	damage = 0
	pierce = 0
	spin = 0.0
	face_dir = true
	grazed = false
	scored = false
	split_after = 0.0
	trail_len = 0.0
	hue_cycle = 0.0
	if not split_spec.is_empty():
		split_spec = {}
	modulate = Color.WHITE
	rotation = 0.0
	# Random phase: a synchronised pulse across hundreds of bullets reads as a
	# strobe, while staggered phases read as a shimmering swarm.
	pulse_phase = randf() * TAU
	if not hits.is_empty():
		hits.clear()
	visible = true


func kill() -> void:
	alive = false
	visible = false


## Breathing scale and brightness applied every frame, so a bullet stays
## legible against busy terrain even when it is not moving relative to the eye.
func _apply_pulse(alpha: float) -> void:
	var k := sin(age * PULSE_RATE + pulse_phase)
	scale = base_scale * (1.0 + PULSE_SCALE * k)
	# BULLET_GAIN lifts the whole palette above the background; values over 1
	# clip toward white on the brightest pixels, which is exactly the hot-core
	# look a bullet wants.
	var b := (1.0 + PULSE_BRIGHT * k) * Cfg.BULLET_GAIN
	var c := base_color
	if hue_cycle != 0.0:
		c = Color.from_hsv(fmod(c.h + age * hue_cycle / 360.0, 1.0),
			maxf(c.s, 0.75), c.v, c.a)
	modulate = Color(c.r * b, c.g * b, c.b * b, c.a * alpha)


## Integrates one frame. Returns false when the bullet should be recycled.
func step(dt: float, target: Vector2) -> bool:
	age += dt
	if age > life:
		return false

	if frames > 1:
		frame = int(age * anim_fps) % frames

	if delay > 0.0:
		delay -= dt
		# Flash harder while held, so the player can read the incoming shot.
		_apply_pulse(0.55 + 0.45 * sin(age * 22.0))
		if face_dir:
			rotation = dir + ART_OFFSET
		return true

	var left := life - age
	_apply_pulse(1.0 if left > FADE_OUT else maxf(left / FADE_OUT, 0.0))

	if homing_time > 0.0 and homing > 0.0:
		homing_time -= dt
		var want := (target - position).angle()
		dir += clampf(angle_difference(dir, want), -homing * dt, homing * dt)

	if ang_vel != 0.0:
		dir += ang_vel * dt
	if accel != 0.0:
		speed = clampf(speed + accel * dt, speed_min, speed_max)

	var step_vec := Vector2.from_angle(dir) * speed * dt
	if wave_amp != 0.0:
		var prev := sin(wave_phase + (age - dt) * wave_freq)
		var curr := sin(wave_phase + age * wave_freq)
		step_vec += Vector2.from_angle(dir + PI * 0.5) * (curr - prev) * wave_amp
	position += step_vec

	if face_dir:
		rotation = dir + ART_OFFSET
	elif spin != 0.0:
		rotation += spin * dt

	return Cfg.in_field(position, Cfg.CULL_MARGIN)
