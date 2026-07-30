class_name Hud
extends CanvasLayer
## Cabinet furniture: the two opaque sidebars plus the in-field overlays.
##
## The sidebars double as a mask - they are drawn over the playfield's edges, so
## anything that spills outside the 810px column is hidden without needing a
## SubViewport.

const PAD := 26.0

var field_x := 0.0
var view_size := Vector2(1920, 1080)

var _root: Control
var _left: PanelBox
var _right: PanelBox
var _overlay: FieldOverlay
var _sparks: ChargeSparks
var _font: Font

# Left column.
var _l_hi: Label
var _l_score: Label
var _l_chain: Label
var _l_chain_sub: Label
var _chain_bar: Bar
var _l_stage: Label
var _l_stage_name: Label
var _l_keys: Label

# Right column.
var _l_ship_code: Label
var _l_ship_name: Label
var _ship_icon: Sprite2D
var _power_bar: Segments
var _lives: IconRow
var _bombs: IconRow
var _hyper_bar: Bar
var _l_hyper: Label
var _l_graze: Label
var _l_bullets: Label

var _t := 0.0
var _alert := 0.0


func _ready() -> void:
	layer = 2
	_font = PixelFont.get_font()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_left = PanelBox.new()
	_left.side = -1
	_root.add_child(_left)
	_right = PanelBox.new()
	_right.side = 1
	_root.add_child(_right)

	_overlay = FieldOverlay.new()
	_root.add_child(_overlay)

	_sparks = ChargeSparks.new()
	_sparks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_sparks)

	_build_left()
	_build_right()

	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(dt: float) -> void:
	_t += dt
	_overlay.tick(dt)
	_sparks.tick(dt)
	if _alert > 0.0 or _left.alert > 0.0:
		_left.alert = _alert
		_right.alert = _alert
		_left.pulse = _t
		_right.pulse = _t
		_left.queue_redraw()
		_right.queue_redraw()


# --- Construction ------------------------------------------------------------

func _label(parent: Control, text: String, size: int, col: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_left() -> void:
	_label(_left, "STRESS", 30, Cfg.UI_ACCENT).name = "Logo"
	_label(_left, "RELIEVER", 30, Cfg.UI_ACCENT).name = "Logo2"
	_label(_left, "HI-SCORE", 15, Cfg.UI_DIM).name = "HiCap"
	_l_hi = _label(_left, "0", 28, Cfg.UI_GOLD)
	_label(_left, "SCORE", 15, Cfg.UI_DIM).name = "ScoreCap"
	_l_score = _label(_left, "0", 38, Cfg.UI_TEXT)

	_label(_left, "CHAIN", 15, Cfg.UI_DIM).name = "ChainCap"
	_l_chain = _label(_left, "0", 46, Cfg.UI_ACCENT)
	_l_chain_sub = _label(_left, "HITS", 14, Cfg.UI_DIM)
	_chain_bar = Bar.new()
	_chain_bar.col = Cfg.UI_ACCENT
	_left.add_child(_chain_bar)

	_label(_left, "STAGE", 15, Cfg.UI_DIM).name = "StageCap"
	_l_stage = _label(_left, "1 / 3", 26, Cfg.UI_TEXT)
	_l_stage_name = _label(_left, "", 16, Cfg.UI_DIM)

	_l_keys = _label(_left, "", 14, Cfg.UI_DIM)
	_l_keys.text = "WASD  MOVE\nJ  SHOT\nK  LASER\nSPACE  BOMB\nESC  PAUSE"


func _build_right() -> void:
	_label(_right, "SHIP", 15, Cfg.UI_DIM).name = "ShipCap"
	_l_ship_code = _label(_right, "TYPE-A", 18, Cfg.UI_DIM)
	_l_ship_name = _label(_right, "HORNET", 30, Cfg.UI_TEXT)

	_ship_icon = Sprite2D.new()
	_ship_icon.centered = true
	_right.add_child(_ship_icon)

	_label(_right, "POWER", 15, Cfg.UI_DIM).name = "PowCap"
	_power_bar = Segments.new()
	_right.add_child(_power_bar)

	_label(_right, "SHIPS", 15, Cfg.UI_DIM).name = "LifeCap"
	_lives = IconRow.new()
	_lives.col = Cfg.UI_ACCENT
	_right.add_child(_lives)

	_label(_right, "BOMBS", 15, Cfg.UI_DIM).name = "BombCap"
	_bombs = IconRow.new()
	_bombs.col = Cfg.UI_WARN
	_bombs.shape_circle = true
	_right.add_child(_bombs)

	_label(_right, "HYPER", 15, Cfg.UI_DIM).name = "HyperCap"
	_hyper_bar = Bar.new()
	_hyper_bar.col = Color(1.0, 0.45, 0.85)
	_right.add_child(_hyper_bar)
	_l_hyper = _label(_right, "", 20, Color(1.0, 0.45, 0.85))

	_label(_right, "GRAZE", 15, Cfg.UI_DIM).name = "GrazeCap"
	_l_graze = _label(_right, "0", 26, Cfg.UI_GOLD)
	_l_bullets = _label(_right, "", 13, Cfg.UI_DIM)


# --- Layout ------------------------------------------------------------------

func _layout() -> void:
	view_size = get_viewport().get_visible_rect().size
	field_x = Cfg.field_x(view_size)
	var right_x := field_x + Cfg.FIELD_W
	var h := view_size.y

	_left.position = Vector2.ZERO
	_left.size = Vector2(field_x, h)
	_right.position = Vector2(right_x, 0)
	_right.size = Vector2(maxf(view_size.x - right_x, 0.0), h)
	_overlay.position = Vector2(field_x, 0)
	_overlay.size = Vector2(Cfg.FIELD_W, h)
	_left.queue_redraw()
	_right.queue_redraw()
	_overlay.queue_redraw()

	var w := field_x - PAD * 2.0
	_stack(_left, w, [
		["Logo", 34.0], ["Logo2", 42.0], ["HiCap", 26.0], [_l_hi, 40.0],
		["ScoreCap", 26.0], [_l_score, 58.0],
		["ChainCap", 26.0], [_l_chain, 54.0], [_l_chain_sub, 24.0],
		[_chain_bar, 22.0],
		["StageCap", 26.0], [_l_stage, 34.0], [_l_stage_name, 40.0],
	], 46.0)
	_l_keys.position = Vector2(PAD, h - 150.0)
	_l_keys.size = Vector2(w, 130.0)

	var rw := _right.size.x - PAD * 2.0
	_stack(_right, rw, [
		["ShipCap", 26.0], [_l_ship_code, 26.0], [_l_ship_name, 46.0],
	], 46.0)
	_ship_icon.position = Vector2(PAD + rw * 0.5, 250.0)
	_ship_icon.scale = Vector2.ONE * 0.30
	_stack(_right, rw, [
		["PowCap", 26.0], [_power_bar, 40.0],
		["LifeCap", 26.0], [_lives, 42.0],
		["BombCap", 26.0], [_bombs, 42.0],
		["HyperCap", 26.0], [_hyper_bar, 24.0], [_l_hyper, 30.0],
		["GrazeCap", 26.0], [_l_graze, 38.0], [_l_bullets, 26.0],
	], 320.0)

	# Must come after the stack above: that is what gives _hyper_bar its
	# position. Computing it earlier aimed every spark at the panel's corner.
	_sparks.target = _right.position + _hyper_bar.position \
		+ Vector2(_hyper_bar.size.x * 0.5, 12.0)


## Positions a vertical stack of children, each entry [node_or_name, height].
func _stack(parent: Control, w: float, items: Array, y0: float) -> void:
	var y := y0
	for it in items:
		var node: Control
		if it[0] is String:
			node = parent.get_node_or_null(NodePath(it[0]))
		else:
			node = it[0]
		if node == null:
			continue
		node.position = Vector2(PAD, y)
		node.size = Vector2(w, it[1])
		y += float(it[1])


# --- Public updates ----------------------------------------------------------

func set_scores(score: int, hi: int) -> void:
	_l_score.text = Cfg.fmt_score(score)
	_l_hi.text = Cfg.fmt_score(hi)


func set_chain(hits: int, frac: float, multiplier: float) -> void:
	_l_chain.text = str(hits)
	_l_chain_sub.text = "HITS   x%.1f" % multiplier
	_chain_bar.value = frac
	_chain_bar.queue_redraw()
	var hot: float = clampf(float(hits) / 120.0, 0.0, 1.0)
	_l_chain.add_theme_color_override("font_color",
		Cfg.UI_ACCENT.lerp(Cfg.UI_GOLD, hot))


func set_stage(index: int, total: int, name: String) -> void:
	_l_stage.text = "%d / %d" % [index + 1, total]
	_l_stage_name.text = name


func set_ship(ship: Dictionary) -> void:
	_l_ship_code.text = String(ship.code)
	_l_ship_name.text = String(ship.name)
	_l_ship_name.add_theme_color_override("font_color", ship.color)
	Art.apply_ship(_ship_icon, Art.PLAYER_SHIPS[ship.tex])
	_ship_icon.frame = 2


## `hyper` is 0..1 charge; `hyper_active` swaps the meter to a countdown.
## Progress toward the next power level (chips banked), 0..1.
func set_power_progress(frac: float) -> void:
	_power_bar.progress = frac
	_power_bar.queue_redraw()


func set_hyper(charge: float, hyper_active: bool) -> void:
	_hyper_bar.value = charge
	_hyper_bar.col = Color(1.0, 0.85, 0.35) if hyper_active \
		else Color(1.0, 0.45, 0.85)
	_hyper_bar.queue_redraw()
	if hyper_active:
		_l_hyper.text = "** HYPER **"
		_l_hyper.modulate.a = 0.55 + 0.45 * absf(sin(_t * 12.0))
	elif charge >= 1.0:
		_l_hyper.text = "READY"
		_l_hyper.modulate.a = 1.0
	else:
		_l_hyper.text = "%d%%" % int(charge * 100.0)
		_l_hyper.modulate.a = 1.0


func set_status(power: int, lives: int, bombs: int, graze: int,
		bullet_count: int) -> void:
	_power_bar.value = power
	_power_bar.queue_redraw()
	_lives.count = lives
	_lives.queue_redraw()
	_bombs.count = bombs
	_bombs.queue_redraw()
	_l_graze.text = Cfg.fmt_score(graze)
	_l_bullets.text = "%d BULLETS" % bullet_count


## Emits a mote that drifts from `from` (screen space) into the hyper meter.
## Purely cosmetic: it visualises where the charge from a kill went.
func charge_spark(from: Vector2, tint: Color = Color(1.0, 0.5, 0.9)) -> void:
	_sparks.emit_spark(from, tint)


func banner(title: String, subtitle: String, duration: float) -> void:
	_overlay.show_banner(title, subtitle, duration)


func warning() -> void:
	_overlay.show_warning()


func set_boss(boss: Boss) -> void:
	_overlay.boss = boss


func set_message(text: String, sub: String = "") -> void:
	_overlay.message = text
	_overlay.message_sub = sub
	_overlay.queue_redraw()


## Boss alert dressing, 0 = off. Drives the pulsing sidebars and the red
## vignette; the game raises it as the boss loses health.
## Shows the hyper callout for as long as hyper is up.
func set_hyper_active(active: bool) -> void:
	_overlay.hyper = active


func set_alert(level: float) -> void:
	_alert = clampf(level, 0.0, 1.0)
	_overlay.alert = _alert


## Full-field white flash, used for bombs and boss deaths.
func flash(amount: float) -> void:
	_overlay.flash = maxf(_overlay.flash, amount)


# --- Nested drawing widgets --------------------------------------------------

class PanelBox:
	extends Control
	var side := -1  ## -1 = left panel, +1 = right panel.
	## Boss alert level. Above zero the panel goes red and starts scrolling
	## hazard stripes toward the playfield, which reads from the corner of the
	## eye without stealing attention from the bullets.
	var alert := 0.0
	var pulse := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var throb: float = 0.5 + 0.5 * sin(pulse * (3.0 + 5.0 * alert))
		var hot: float = alert * throb
		var accent: Color = Cfg.UI_ACCENT.lerp(Cfg.UI_WARN, clampf(alert, 0.0, 1.0))

		draw_rect(Rect2(Vector2.ZERO, size),
			Cfg.UI_BG.lerp(Color(0.16, 0.03, 0.06), hot * 0.55))
		# Inner plate, inset from the outer edge.
		var inset := 14.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)),
			Cfg.UI_PANEL.lerp(Color(0.20, 0.05, 0.08), hot * 0.45))
		# Bright rule along the playfield edge.
		var ex := size.x - 2.0 if side < 0 else 0.0
		draw_rect(Rect2(Vector2(ex, 0), Vector2(2.0 + 3.0 * hot, size.y)), accent)
		var gx := size.x - 8.0 if side < 0 else 2.0
		draw_rect(Rect2(Vector2(gx, 0), Vector2(6.0, size.y)),
			Color(accent.r, accent.g, accent.b, 0.12 + 0.35 * hot))

		if alert > 0.01:
			_hazard_stripes(accent, hot)
			return

		# Ladder ticks for a bit of cabinet texture.
		var y := 30.0
		while y < size.y - 30.0:
			var tx := size.x - 26.0 if side < 0 else 14.0
			draw_rect(Rect2(Vector2(tx, y), Vector2(10.0, 2.0)),
				Color(Cfg.UI_LINE.r, Cfg.UI_LINE.g, Cfg.UI_LINE.b, 0.5))
			y += 40.0

	## Diagonal chevrons scrolling upward along the playfield edge.
	func _hazard_stripes(accent: Color, hot: float) -> void:
		var band := 26.0
		var x := size.x - 34.0 if side < 0 else 14.0
		var scroll := fmod(pulse * 90.0, band * 2.0)
		var y := -band * 2.0 + scroll
		while y < size.y + band:
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y), Vector2(x + 20.0, y - 10.0),
				Vector2(x + 20.0, y + band - 10.0), Vector2(x, y + band),
			]), Color(accent.r, accent.g, accent.b, 0.12 + 0.30 * hot))
			y += band * 2.0

class Bar:
	extends Control
	var value := 0.0
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := 10.0
		var r := Rect2(Vector2(0, 4), Vector2(size.x, h))
		draw_rect(r, Color(1, 1, 1, 0.08))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value, 0, 1), h)), col)
		draw_rect(r, Color(col.r, col.g, col.b, 0.35), false, 1.0)

## Power meter: MAX_POWER segments split into POWER_BARS groups, so at a glance
## you can see both which bar you are on and how far through it you are.
class Segments:
	extends Control
	var value := 1
	var total := Cfg.MAX_POWER
	## Fill of the *next* segment, so banked chips are visible before a level.
	var progress := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var per := Cfg.POWER_PER_BAR
		var bars := Cfg.POWER_BARS
		var gap := 3.0
		var bar_gap := 13.0
		var w := (size.x - gap * (per - 1) * bars - bar_gap * (bars - 1)) \
			/ float(total)
		var x := 0.0
		for i in total:
			var r := Rect2(Vector2(x, 4), Vector2(w, 18))
			if i < value:
				# Each bar has its own colour so the tier is unmistakable.
				var tier := i / per
				var col: Color = [Cfg.UI_ACCENT, Cfg.UI_GOLD,
					Color(1.0, 0.45, 0.75)][mini(tier, 2)]
				draw_rect(r, col)
			else:
				draw_rect(r, Color(1, 1, 1, 0.09))
				if i == value and progress > 0.0:
					draw_rect(Rect2(r.position,
						Vector2(r.size.x * progress, r.size.y)),
						Color(1, 1, 1, 0.30))
			draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)
			x += w + (bar_gap if (i + 1) % per == 0 else gap)

class IconRow:
	extends Control
	var count := 3
	var col := Color.WHITE
	var shape_circle := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step := 30.0
		for i in mini(count, 8):
			var c := Vector2(14.0 + i * step, 16.0)
			if shape_circle:
				draw_circle(c, 9.0, col)
				draw_circle(c, 4.0, Color(1, 1, 1, 0.85))
			else:
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -11), c + Vector2(9, 9), c + Vector2(-9, 9),
				]), col)
		if count > 8:
			draw_string(PixelFont.get_font(), Vector2(14.0 + 8 * step, 22.0),
				"+%d" % (count - 8), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

## Motes that travel from a kill to the hyper meter. Deliberately faint and
## small - it is a hint about where charge comes from, not a fireworks display.
class ChargeSparks:
	extends Control
	const POOL := 48
	const LIFE := 0.55

	var target := Vector2(1600, 600)

	var _from: PackedVector2Array = PackedVector2Array()
	var _age: PackedFloat32Array = PackedFloat32Array()
	var _bow: PackedFloat32Array = PackedFloat32Array()
	var _col: PackedColorArray = PackedColorArray()
	var _next := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_from.resize(POOL)
		_age.resize(POOL)
		_bow.resize(POOL)
		_col.resize(POOL)
		for i in POOL:
			_age[i] = LIFE + 1.0   # Start expired.

	func emit_spark(from: Vector2, tint: Color) -> void:
		_from[_next] = from
		_age[_next] = 0.0
		# Sideways bow so a burst of sparks fans out instead of overlapping.
		_bow[_next] = randf_range(-90.0, 90.0)
		_col[_next] = tint
		_next = (_next + 1) % POOL

	func tick(dt: float) -> void:
		var busy := false
		for i in POOL:
			if _age[i] <= LIFE:
				_age[i] += dt
				busy = true
		if busy:
			queue_redraw()

	func _draw() -> void:
		for i in POOL:
			var t: float = _age[i] / LIFE
			if t >= 1.0:
				continue
			# Ease out, with a perpendicular bow that flattens on arrival.
			var e: float = 1.0 - pow(1.0 - t, 2.2)
			var p: Vector2 = _from[i].lerp(target, e)
			p += Vector2(0, -1).rotated(
				(target - _from[i]).angle()) * _bow[i] * sin(e * PI)
			var c: Color = _col[i]
			c.a = (1.0 - t) * 0.7
			draw_circle(p, lerpf(3.2, 1.2, t), c)


## Draws inside the playfield: boss health, stage banners, warnings, messages.
class FieldOverlay:
	extends Control
	var boss: Boss = null
	var message := ""
	var message_sub := ""
	var flash := 0.0
	var alert := 0.0
	var hyper := false

	var _banner_t := 0.0
	var _banner_dur := 0.0
	var _banner := ""
	var _banner_sub := ""
	var _warn_t := 0.0
	var _t := 0.0
	## Trails the real health so recent damage shows as a draining ghost bar.
	var _ghost := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_banner(title: String, sub: String, dur: float) -> void:
		_banner = title
		_banner_sub = sub
		_banner_dur = dur
		_banner_t = 0.0

	func show_warning() -> void:
		_warn_t = 2.6

	func tick(dt: float) -> void:
		_t += dt
		if _banner_t < _banner_dur:
			_banner_t += dt
		if _warn_t > 0.0:
			_warn_t -= dt
		if is_instance_valid(boss):
			var frac := boss.hp_fraction()
			if frac > _ghost:
				_ghost = frac          # New boss or new phase: snap up.
			else:
				_ghost = maxf(frac, _ghost - dt * 0.22)
		else:
			_ghost = 1.0
		if flash > 0.0:
			flash = maxf(0.0, flash - dt * 2.6)
		queue_redraw()

	func _draw() -> void:
		var f := PixelFont.get_font()
		if alert > 0.01:
			_vignette(Color(1.0, 0.15, 0.25), alert, 2.6 + 4.5 * alert)
		elif hyper:
			# Softer and slower than the boss alert, so the two never read as
			# the same warning.
			_vignette(Color(1.0, 0.35, 0.95), 0.55, 5.0)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, minf(flash, 0.75)))
		if is_instance_valid(boss) and not boss.dying:
			_draw_boss_bar(f)
		if _banner_t < _banner_dur:
			_draw_banner(f)
		if _warn_t > 0.0:
			_draw_warning(f)
		if hyper:
			_draw_hyper(f)
		if message != "":
			_draw_message(f)

	## Colour bloom creeping in from the playfield edges. Bands rather than a
	## shader so it costs nothing. Used for both the boss alert and hyper.
	func _vignette(col_base: Color, strength: float, rate: float) -> void:
		var throb: float = 0.5 + 0.5 * sin(_t * rate)
		var peak: float = strength * (0.30 + 0.70 * throb)
		var bands := 9
		var depth := 70.0 + 40.0 * strength
		for i in bands:
			var t := float(i) / float(bands - 1)
			var a: float = peak * 0.16 * (1.0 - t)
			var w := depth * (1.0 - t) / float(bands) + 3.0
			var col := Color(col_base.r, col_base.g, col_base.b, a)
			var off := depth * t / float(bands) * bands / 3.0
			draw_rect(Rect2(Vector2(off, 0), Vector2(w, size.y)), col)
			draw_rect(Rect2(Vector2(size.x - off - w, 0), Vector2(w, size.y)), col)
			draw_rect(Rect2(Vector2(0, off), Vector2(size.x, w)), col)
			draw_rect(Rect2(Vector2(0, size.y - off - w), Vector2(size.x, w)), col)

	func _draw_boss_bar(f: Font) -> void:
		var m := 34.0
		var w := size.x - m * 2.0
		var y := 26.0
		var frac := boss.hp_fraction()
		draw_rect(Rect2(Vector2(m, y), Vector2(w, 16)), Color(0, 0, 0, 0.55))
		# Ghost first, so the lit bar draws over it and the gap is the damage.
		draw_rect(Rect2(Vector2(m, y), Vector2(w * _ghost, 16)),
			Color(1.0, 0.45, 0.35, 0.75))
		var col := Cfg.UI_WARN if frac < 0.3 else Cfg.UI_GOLD
		draw_rect(Rect2(Vector2(m, y), Vector2(w * frac, 16)), col)
		draw_rect(Rect2(Vector2(m, y), Vector2(w, 16)), Color(1, 1, 1, 0.4), false, 2.0)
		# Phase dividers.
		var n := boss.phases.size()
		for i in range(1, n):
			var x := m + w * (float(i) / float(n))
			draw_rect(Rect2(Vector2(x - 1, y), Vector2(2, 16)), Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(m, y - 8), boss.boss_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Cfg.UI_TEXT)

	func _draw_banner(f: Font) -> void:
		var t := _banner_t / maxf(_banner_dur, 0.001)
		var a: float = clampf(minf(t * 5.0, (1.0 - t) * 5.0), 0.0, 1.0)
		var cy := size.y * 0.38
		if _banner != "":
			_centre(f, _banner, cy, 74, Color(1, 1, 1, a))
		if _banner_sub != "":
			_centre(f, _banner_sub, cy + 62.0, 30, Color(Cfg.UI_ACCENT.r,
				Cfg.UI_ACCENT.g, Cfg.UI_ACCENT.b, a))
		var lw := size.x * 0.34 * a
		draw_rect(Rect2(Vector2(size.x * 0.5 - lw, cy + 90.0), Vector2(lw * 2.0, 2.0)),
			Color(1, 1, 1, a * 0.7))

	func _draw_warning(f: Font) -> void:
		var blink := absf(sin(_t * 9.0))
		var a := clampf(_warn_t, 0.0, 1.0) * (0.35 + 0.65 * blink)
		var cy := size.y * 0.42
		draw_rect(Rect2(Vector2(0, cy - 54), Vector2(size.x, 108)),
			Color(0.5, 0.0, 0.1, 0.28 * a))
		_centre(f, "!! WARNING !!", cy - 8, 62, Color(1, 0.3, 0.35, a))
		_centre(f, "LARGE CRAFT APPROACHING", cy + 44, 26, Color(1, 0.85, 0.85, a))

	## Big, brief and unmistakable: hyper is the one state worth shouting about.
	func _draw_hyper(f: Font) -> void:
		var pulse: float = 0.55 + 0.45 * absf(sin(_t * 9.0))
		var cy := size.y * 0.26
		# Bands top and bottom rather than a full wash, so the field stays clear.
		var band := Color(1.0, 0.45, 0.85, 0.10 + 0.10 * pulse)
		draw_rect(Rect2(Vector2(0, cy - 62.0), Vector2(size.x, 118.0)), band)
		_centre(f, "H Y P E R !", cy, 56,
			Color(1.0, 0.70, 0.95, 0.75 + 0.25 * pulse))
		_centre(f, "KISS THE BULLETS!", cy + 42.0, 26,
			Color(1.0, 0.90, 0.98, 0.65 + 0.35 * pulse))

	func _draw_message(f: Font) -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		_centre(f, message, size.y * 0.44, 68, Cfg.UI_TEXT)
		if message_sub != "":
			_centre(f, message_sub, size.y * 0.44 + 60.0, 26, Cfg.UI_ACCENT)

	func _centre(f: Font, text: String, y: float, s: int, col: Color) -> void:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		draw_string(f, Vector2((size.x - w) * 0.5, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
