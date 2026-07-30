class_name Terrain
extends Node2D
## Endlessly scrolling ground built from the 256px terrain tiles.
##
## A ring buffer of tile rows is recycled as the world scrolls, so the node
## count stays fixed. Tile choice comes from layered noise, which gives each
## stage coherent regions (water channels, rock outcrops) instead of static.

const TILE := 90.0                        ## 810 / 9 columns.
const COLS := 9
const ROWS := 14                          ## Enough to cover 1080px plus slack.

## The ground is scenery, never a read. Everything is pushed dark and low
## contrast so bullets and ships stay legible on top of it.
const BRIGHTNESS := 0.46

## Per-stage palettes: noise thresholds are walked top-down until one matches.
const PALETTES := [
	{
		"name": "VERDANT COAST",
		"tint": Color(0.66, 0.86, 0.76),
		"bands": [
			[-1.00, "water"], [-0.30, "sand"], [-0.16, "grass"],
			[0.32, "dirt"], [0.58, "stone"],
		],
		"decor": ["wood", "stone"],
		"speed": 132.0,
	},
	{
		"name": "SCORCHED FLATS",
		"tint": Color(0.98, 0.80, 0.58),
		"bands": [
			[-1.00, "stone"], [-0.44, "cobble"], [-0.18, "sand"],
			[0.38, "dirt"], [0.64, "swamp"],
		],
		"decor": ["cobble", "stone"],
		"speed": 168.0,
	},
	{
		"name": "GLACIER CORE",
		"tint": Color(0.70, 0.82, 1.0),
		"bands": [
			[-1.00, "water"], [-0.32, "snow"], [0.16, "stone"],
			[0.46, "cobble"], [0.70, "wood"],
		],
		"decor": ["stone", "wood"],
		"speed": 208.0,
	},
	# Stages 4 and 5 leave the ground behind. There is no space art in the
	# asset pack, so `space` swaps the tile grid for a procedural starfield and
	# nebula, and reuses rock tiles as tumbling debris silhouettes.
	{
		"name": "ORBITAL DEBRIS",
		"tint": Color(0.62, 0.72, 1.0),
		"space": true,
		"nebula": [Color(0.10, 0.16, 0.40), Color(0.24, 0.12, 0.38)],
		"bands": [],
		"decor": ["stone", "cobble"],
		"speed": 236.0,
	},
	{
		"name": "VOID CORE",
		"tint": Color(1.0, 0.68, 0.80),
		"space": true,
		"nebula": [Color(0.30, 0.05, 0.18), Color(0.12, 0.04, 0.26)],
		"bands": [],
		"decor": ["stone", "wood"],
		"speed": 272.0,
	},
]

## Starfield layers used in space mode: [count, speed multiplier, radius, alpha].
const STAR_LAYERS := [
	[70, 0.35, 1.0, 0.40],
	[46, 0.70, 1.6, 0.62],
	[26, 1.25, 2.4, 0.90],
]

var speed := 132.0

var _tiles: Array[Sprite2D] = []
var _row_id: PackedInt32Array = PackedInt32Array()
var _scroll := 0.0
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _palette: Dictionary = PALETTES[0]
var _decor: Array[Sprite2D] = []
var _decor_y: PackedFloat32Array = PackedFloat32Array()
var _space := false
var _stars: Array[Vector3] = []      ## x, y, layer index.
var _star_spin: PackedFloat32Array = PackedFloat32Array()
var _decor_spin: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	z_index = Cfg.Z_TERRAIN
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.075
	_noise.fractal_octaves = 3
	_detail.noise_type = FastNoiseLite.TYPE_VALUE
	_detail.frequency = 0.85

	var s := TILE / Art.FRAME
	for i in ROWS * COLS:
		var t := Sprite2D.new()
		t.centered = true
		t.scale = Vector2(s, s)
		add_child(t)
		_tiles.append(t)
	_row_id.resize(ROWS)
	for i in ROWS:
		_row_id[i] = -99999

	# Sparse silhouettes scrolling faster, for a hint of parallax depth.
	for i in 10:
		var d := Sprite2D.new()
		d.centered = true
		d.z_index = 1
		d.modulate = Color(0, 0, 0, 0.16)
		add_child(d)
		_decor.append(d)
		_decor_y.append(0.0)
		_decor_spin.append(0.0)


func set_stage(index: int, seed_value: int) -> void:
	_palette = PALETTES[clampi(index, 0, PALETTES.size() - 1)]
	speed = _palette.speed
	_space = bool(_palette.get("space", false))
	for t in _tiles:
		t.visible = not _space
	if _space:
		_seed_stars()
	_noise.seed = seed_value
	_detail.seed = seed_value * 7 + 13
	for i in ROWS:
		_row_id[i] = -99999
	var decor_pool: Array = _palette.decor
	for i in _decor.size():
		var d := _decor[i]
		d.texture = Art.TERRAIN[decor_pool[i % decor_pool.size()]]
		var sc := randf_range(0.18, 0.38)
		d.scale = Vector2(sc, sc * randf_range(0.6, 1.4))
		d.position.x = randf_range(0.0, Cfg.FIELD_W)
		_decor_y[i] = randf_range(-Cfg.FIELD_H, Cfg.FIELD_H)
		d.rotation = 0.0
		# Debris tumbles; ground silhouettes stay level.
		_decor_spin[i] = randf_range(-0.8, 0.8) if _space else 0.0
		d.modulate = Color(0.26, 0.28, 0.38, 0.62) if _space \
			else Color(0, 0, 0, 0.16)


## Scatters a fresh starfield across the field plus one screen of lead-in.
func _seed_stars() -> void:
	_stars.clear()
	_star_spin.resize(0)
	for layer in STAR_LAYERS.size():
		var count := int(STAR_LAYERS[layer][0])
		for i in count:
			_stars.append(Vector3(
				randf_range(0.0, Cfg.FIELD_W),
				randf_range(-Cfg.FIELD_H, Cfg.FIELD_H),
				float(layer)))
			_star_spin.append(randf())


func _process(dt: float) -> void:
	_scroll += speed * dt
	if _space:
		_step_stars(dt)
	else:
		_refresh()
	var dspeed := speed * 1.65
	for i in _decor.size():
		_decor_y[i] += dspeed * dt
		if _decor_y[i] > Cfg.FIELD_H + 200.0:
			_decor_y[i] = randf_range(-600.0, -200.0)
			_decor[i].position.x = randf_range(0.0, Cfg.FIELD_W)
		_decor[i].position.y = _decor_y[i]
		if _decor_spin[i] != 0.0:
			_decor[i].rotation += _decor_spin[i] * dt


func _step_stars(dt: float) -> void:
	for i in _stars.size():
		var st := _stars[i]
		st.y += speed * float(STAR_LAYERS[int(st.z)][1]) * dt
		if st.y > Cfg.FIELD_H + 8.0:
			st.y = randf_range(-40.0, -4.0)
			st.x = randf_range(0.0, Cfg.FIELD_W)
		_stars[i] = st
	queue_redraw()


## Space mode paints itself: soft nebula bands, then parallax stars over them.
func _draw() -> void:
	if not _space:
		return
	var neb: Array = _palette.get("nebula", [Color(0.1, 0.12, 0.3)])
	for i in 7:
		var t := float(i) / 6.0
		var col: Color = (neb[0] as Color).lerp(neb[neb.size() - 1], t)
		col.a = 0.30 - 0.03 * i
		# Wide soft bands drifting with the scroll.
		var y := fmod(_scroll * 0.25 + i * 210.0, Cfg.FIELD_H + 420.0) - 210.0
		draw_rect(Rect2(Vector2(-40.0, y), Vector2(Cfg.FIELD_W + 80.0, 150.0)), col)

	var tint: Color = _palette.tint
	for i in _stars.size():
		var st := _stars[i]
		var layer: Array = STAR_LAYERS[int(st.z)]
		var twinkle: float = 0.65 + 0.35 * sin(
			(_scroll * 0.02) + _star_spin[i] * TAU)
		draw_circle(Vector2(st.x, st.y), float(layer[2]),
			Color(tint.r, tint.g, tint.b, float(layer[3]) * twinkle))


## The ship flies north, so the ground has to travel *down* the screen: tile Y
## increases with `_scroll`, and the world row index counts backwards as new
## ground arrives over the top edge.
func _refresh() -> void:
	var first := floori((-_scroll - TILE) / TILE)
	for k in ROWS:
		var r := first + k
		var slot := posmod(r, ROWS)
		if _row_id[slot] != r:
			_row_id[slot] = r
			_fill_row(slot, r)
		var y := float(r) * TILE + _scroll + TILE * 0.5
		for c in COLS:
			_tiles[slot * COLS + c].position = Vector2(TILE * (c + 0.5), y)


func _fill_row(slot: int, world_row: int) -> void:
	var tint: Color = _palette.tint
	var bands: Array = _palette.bands
	if bands.is_empty():
		return   # Space palettes have no tiles to fill.
	for c in COLS:
		var t := _tiles[slot * COLS + c]
		# Negative row index so the world reads as scrolling toward the player.
		var n := _noise.get_noise_2d(float(c) * 1.0, float(-world_row) * 1.0)
		var name: String = bands[0][1]
		for b in bands:
			if n >= float(b[0]):
				name = String(b[1])
		t.texture = Art.TERRAIN[name]
		var shade := BRIGHTNESS * (1.0
			+ _detail.get_noise_2d(c * 3.0, -world_row * 3.0) * 0.22)
		t.modulate = Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
		t.flip_h = absi(world_row * 7 + c * 3) % 2 == 0
		t.flip_v = absi(world_row * 5 + c) % 3 == 0


func stage_name() -> String:
	return String(_palette.name)


func stage_tint() -> Color:
	return _palette.tint
