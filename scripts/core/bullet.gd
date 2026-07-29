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

## The bullet hangs motionless for `delay` seconds after spawning, a staple of
## danmaku telegraphing.
var delay := 0.0

## Lateral sine oscillation, perpendicular to `dir`.
var wave_amp := 0.0
var wave_freq := 0.0
var wave_phase := 0.0

var radius := 7.0
var life := 24.0
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


func reset() -> void:
	alive = true
	accel = 0.0
	speed_min = -4000.0
	speed_max = 4000.0
	ang_vel = 0.0
	homing = 0.0
	homing_time = 0.0
	delay = 0.0
	wave_amp = 0.0
	wave_freq = 0.0
	wave_phase = 0.0
	radius = 7.0
	life = 24.0
	age = 0.0
	damage = 0
	pierce = 0
	spin = 0.0
	face_dir = true
	grazed = false
	scored = false
	modulate = Color.WHITE
	rotation = 0.0
	if not hits.is_empty():
		hits.clear()
	visible = true


func kill() -> void:
	alive = false
	visible = false


## Integrates one frame. Returns false when the bullet should be recycled.
func step(dt: float, target: Vector2) -> bool:
	age += dt
	if age > life:
		return false

	if frames > 1:
		frame = int(age * anim_fps) % frames

	if delay > 0.0:
		delay -= dt
		# Pulse while held so the player can read the incoming shot.
		var k := 0.65 + 0.35 * sin(age * 22.0)
		modulate.a = k
		if face_dir:
			rotation = dir + ART_OFFSET
		return true
	elif modulate.a < 1.0:
		modulate.a = minf(1.0, modulate.a + dt * 6.0)

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
