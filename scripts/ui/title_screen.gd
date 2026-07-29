class_name TitleScreen
extends Cabinet
## Attract screen: logo, menu, hi-score and the result of the last run.

signal start_pressed()
signal ranking_pressed()
signal quit_pressed()

const ITEMS := ["START GAME", "RANKING", "QUIT"]

var _sel := 0
var _item_labels: Array[Label] = []
var _prompt: Label
var _time := 0.0
var _ready_input := 0.25


func _ready() -> void:
	build(0)

	label("G D S H M U P", 150.0, 72, Cfg.UI_ACCENT)
	label("D A N M A K U   A R C A D E", 236.0, 24, Cfg.UI_TEXT)

	var rule := Rule.new()
	rule.position = Vector2(Cfg.FIELD_W * 0.22, 284.0)
	rule.size = Vector2(Cfg.FIELD_W * 0.56, 3.0)
	content.add_child(rule)

	# Top three, so the attract screen always shows something to beat.
	var y := 314.0
	for i in mini(3, GS.scores.size()):
		var e: Dictionary = GS.scores[i]
		label("%d.  %s   %s" % [i + 1, String(e.get("name", "---")),
			Cfg.fmt_score(int(e.get("score", 0)))], y, 24,
			Cfg.UI_GOLD if i == 0 else Cfg.UI_DIM)
		y += 32.0

	if GS.last_run_score > 0:
		var res := "ALL CLEAR" if GS.last_run_cleared \
			else "REACHED STAGE %d" % (GS.last_run_stage + 1)
		label("LAST RUN   %s   -   %s"
			% [Cfg.fmt_score(GS.last_run_score), res], y + 12.0, 19, Cfg.UI_DIM)

	for i in ITEMS.size():
		_item_labels.append(label(ITEMS[i], 520.0 + i * 60.0, 38, Cfg.UI_TEXT))

	_prompt = label("", 720.0, 22, Cfg.UI_DIM)
	_prompt.text = "W / S  CHOOSE       J / ENTER  CONFIRM"

	label("MOVE  WASD / ARROWS / STICK", Cfg.FIELD_H - 170.0, 16, Cfg.UI_DIM)
	label("J  SHOT      K  LASER      SPACE  BOMB",
		Cfg.FIELD_H - 140.0, 16, Cfg.UI_DIM)
	label("HOLD LASER FOR PRECISION MOVEMENT",
		Cfg.FIELD_H - 110.0, 16, Cfg.UI_DIM)
	label("F11  FULLSCREEN     ESC  PAUSE", Cfg.FIELD_H - 78.0, 14, Cfg.UI_DIM)

	_refresh()


func _process(dt: float) -> void:
	super._process(dt)
	_time += dt
	if _ready_input > 0.0:
		_ready_input -= dt
		return

	if Input.is_action_just_pressed("p_up") or Input.is_action_just_pressed("ui_up"):
		_sel = posmod(_sel - 1, ITEMS.size())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_down") or Input.is_action_just_pressed("ui_down"):
		_sel = posmod(_sel + 1, ITEMS.size())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_start"):
		AU.play("menu_select")
		match _sel:
			0:
				start_pressed.emit()
			1:
				ranking_pressed.emit()
			_:
				quit_pressed.emit()

	# Pulse the highlighted entry.
	var k := 0.72 + 0.28 * absf(sin(_time * 4.5))
	for i in _item_labels.size():
		if i == _sel:
			_item_labels[i].modulate = Color(1, 1, 1, k)


func _refresh() -> void:
	for i in _item_labels.size():
		var on := i == _sel
		_item_labels[i].text = ("> %s <" % ITEMS[i]) if on else ITEMS[i]
		_item_labels[i].add_theme_color_override("font_color",
			Cfg.UI_ACCENT if on else Cfg.UI_DIM)
		_item_labels[i].modulate = Color(1, 1, 1, 1)


class Rule:
	extends Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Cfg.UI_ACCENT.r,
			Cfg.UI_ACCENT.g, Cfg.UI_ACCENT.b, 0.55))
