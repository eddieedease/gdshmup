class_name BossDefs
extends RefCounted
## Stage bosses. Each phase swaps both the flight path and the whole attack set,
## so a fight reads as three (or four) distinct duels rather than one long one.

const CENTRE := Vector2(Cfg.FIELD_W * 0.5, 250.0)


static func get_boss(stage: int) -> Dictionary:
	match stage:
		0:
			return _arbiter()
		1:
			return _colossus()
		2:
			return _omega()
		3:
			return _harbinger()
		_:
			return _singularity()


# --- Stage 1: ARBITER --------------------------------------------------------

static func _arbiter() -> Dictionary:
	return {
		"name": "ARBITER",
		"tex": 6,
		"scale": 0.95,
		"radius": 74.0,
		"score": 120_000,
		"anchor": CENTRE,
		# Tuned as a first boss: roughly half the health of the later two, and
		# every phase kept under ~25 bullets/sec. The sway frequencies are low
		# so a laser can actually stay on the hull instead of chasing it.
		"phases": [
			{
				"hp": 2500,
				"move": {"type": "sway", "centre": CENTRE, "amp_x": 190.0,
					"amp_y": 40.0, "freq_x": 0.62, "freq_y": 1.0},
				"attacks": [
					{"pattern": "ring", "n": 12, "speed": 180.0, "rot": 15.0,
						"style": "small", "color": "blue", "aim": false,
						"start": 1.2, "interval": 1.5},
					{"pattern": "aimed", "n": 3, "spread": 22.0, "speed": 290.0,
						"style": "needle", "color": "white",
						"start": 2.4, "interval": 2.2, "burst": 2, "burst_gap": 0.14},
				],
			},
			{
				"hp": 3000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 230.0),
					"amp_x": 230.0, "amp_y": 55.0, "freq_x": 0.9, "freq_y": 1.5},
				"attacks": [
					{"pattern": "dual_spiral", "n": 2, "speed": 185.0, "rot": 11.0,
						"style": "tiny", "color": "violet", "flash": false,
						"start": 1.0, "interval": 0.18},
					{"pattern": "wall", "n": 13, "gap": 4, "speed": 195.0,
						"style": "small", "color": "ember",
						"start": 2.6, "interval": 3.4, "oy": -120.0},
				],
			},
			{
				"hp": 3500,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 245.0),
					"amp_x": 200.0, "amp_y": 70.0, "freq_x": 1.1, "freq_y": 1.8},
				"attacks": [
					{"pattern": "bloom", "n": 16, "speed": 400.0, "accel": -520.0,
						"speed_min": -170.0, "style": "orb", "color": "cyan",
						"aim": false, "start": 1.2, "interval": 2.6},
					# Wider ring, longer tell and a slower closing speed: the
					# lock-on stays a readable trap rather than a gotcha.
					{"pattern": "lockon", "n": 5, "radius": 300.0, "speed": 240.0,
						"style": "small", "color": "pink", "delay": 0.9,
						"start": 3.0, "interval": 3.6},
					{"pattern": "spray", "n": 3, "spread": 55.0, "speed": 235.0,
						"style": "tiny", "color": "pink", "flash": false,
						"start": 0.8, "interval": 0.9},
				],
			},
		],
	}


# --- Stage 2: COLOSSUS -------------------------------------------------------

static func _colossus() -> Dictionary:
	return {
		"name": "COLOSSUS",
		"tex": 7,
		"scale": 1.10,
		"radius": 86.0,
		"score": 250_000,
		"anchor": Vector2(Cfg.FIELD_W * 0.5, 240.0),
		"drop_extend": true,
		"phases": [
			{
				"hp": 4000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 240.0),
					"amp_x": 230.0, "amp_y": 35.0, "freq_x": 0.85, "freq_y": 1.4},
				"attacks": [
					{"pattern": "flower", "n": 26, "petals": 5, "variance": 0.5,
						"speed": 215.0, "style": "small", "color": "green",
						"aim": false, "start": 1.0, "interval": 1.7, "rot": 7.0},
					{"pattern": "homing", "n": 2, "spread": 150.0, "speed": 120.0,
						"style": "missile", "color": "ember", "homing": 140.0,
						"homing_time": 2.0, "start": 2.5, "interval": 3.2},
				],
			},
			{
				"hp": 4400,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 225.0),
					"amp_x": 265.0, "amp_y": 70.0, "freq_x": 1.25, "freq_y": 1.9},
				"attacks": [
					{"pattern": "arc_wall", "n": 15, "spread": 170.0, "speed": 215.0,
						"stagger": 0.05, "delay": 0.4, "style": "small",
						"color": "pink", "aim": false, "start": 1.2, "interval": 2.4},
					{"pattern": "fan", "n": 5, "spread": 30.0, "swing": 60.0,
						"swing_rate": 0.42, "speed": 300.0, "style": "needle",
						"color": "white", "start": 0.9, "interval": 0.22,
						"flash": false},
				],
			},
			{
				"hp": 4800,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 250.0),
					"amp_x": 200.0, "amp_y": 90.0, "freq_x": 1.6, "freq_y": 2.4},
				"attacks": [
					{"pattern": "vortex", "n": 18, "speed": 110.0, "accel": 110.0,
						"speed_max": 350.0, "curve": 42.0, "style": "orb",
						"color": "violet", "aim": false, "start": 0.8,
						"interval": 1.5, "rot": 21.0},
					{"pattern": "petal", "n": 10, "speed": 235.0, "curve": 70.0,
						"style": "small", "color": "cyan", "aim": false,
						"start": 1.6, "interval": 1.1},
					{"pattern": "aimed", "n": 5, "spread": 40.0, "speed": 340.0,
						"style": "needle", "color": "red", "start": 2.4,
						"interval": 2.0, "burst": 3, "burst_gap": 0.1},
				],
			},
		],
	}


# --- Stage 3: OMEGA ----------------------------------------------------------

static func _omega() -> Dictionary:
	return {
		"name": "OMEGA DRIVE",
		"tex": 8,
		"scale": 1.25,
		"radius": 94.0,
		"score": 500_000,
		"anchor": Vector2(Cfg.FIELD_W * 0.5, 255.0),
		"phases": [
			{
				"hp": 4800,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 255.0),
					"amp_x": 235.0, "amp_y": 50.0, "freq_x": 0.95, "freq_y": 1.6},
				"attacks": [
					{"pattern": "spiral", "n": 5, "speed": 225.0, "rot": 14.0,
						"style": "tiny", "color": "cyan", "aim": false,
						"flash": false, "start": 0.8, "interval": 0.085},
					{"pattern": "shotgun", "n": 9, "spread": 28.0, "speed": 340.0,
						"style": "small", "color": "red", "start": 2.0,
						"interval": 2.1},
				],
			},
			{
				"hp": 5200,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 235.0),
					"amp_x": 270.0, "amp_y": 80.0, "freq_x": 1.4, "freq_y": 2.2},
				"attacks": [
					{"pattern": "wall", "n": 17, "gap": 3, "speed": 235.0,
						"style": "small", "color": "ember", "start": 1.0,
						"interval": 1.5, "oy": -150.0},
					{"pattern": "dual_spiral", "n": 3, "speed": 215.0, "rot": 12.0,
						"style": "tiny", "color": "violet", "flash": false,
						"start": 0.6, "interval": 0.085},
				],
			},
			{
				"hp": 5600,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 250.0),
					"amp_x": 210.0, "amp_y": 95.0, "freq_x": 1.75, "freq_y": 2.6},
				"attacks": [
					{"pattern": "lockon", "n": 10, "radius": 270.0, "speed": 330.0,
						"style": "small", "color": "pink", "delay": 0.55,
						"start": 1.0, "interval": 1.9},
					{"pattern": "flower", "n": 30, "petals": 6, "variance": 0.55,
						"speed": 230.0, "style": "tiny", "color": "green",
						"aim": false, "start": 1.6, "interval": 1.4, "rot": 11.0},
					{"pattern": "homing", "n": 3, "spread": 160.0, "speed": 130.0,
						"style": "missile", "color": "ember", "homing": 160.0,
						"homing_time": 2.2, "start": 3.0, "interval": 3.4},
				],
			},
			{
				"hp": 6000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 260.0),
					"amp_x": 245.0, "amp_y": 60.0, "freq_x": 2.1, "freq_y": 3.0},
				"attacks": [
					{"pattern": "bloom", "n": 26, "speed": 470.0, "accel": -600.0,
						"speed_min": -210.0, "style": "orb", "color": "cyan",
						"aim": false, "start": 0.9, "interval": 2.0},
					{"pattern": "vortex", "n": 20, "speed": 120.0, "accel": 130.0,
						"speed_max": 380.0, "curve": -50.0, "style": "tiny",
						"color": "violet", "aim": false, "start": 1.4,
						"interval": 1.2, "rot": 25.0},
					{"pattern": "fan", "n": 7, "spread": 34.0, "swing": 70.0,
						"swing_rate": 0.5, "speed": 320.0, "style": "needle",
						"color": "white", "flash": false, "start": 0.7,
						"interval": 0.2},
					{"pattern": "rain", "n": 3, "speed": 290.0, "style": "small",
						"color": "pink", "flash": false, "start": 2.0,
						"interval": 0.45},
				],
			},
		],
	}


# --- Stage 4: HARBINGER ------------------------------------------------------

static func _harbinger() -> Dictionary:
	return {
		"name": "HARBINGER",
		"tex": 5,
		"scale": 1.20,
		"radius": 90.0,
		"score": 700_000,
		"anchor": Vector2(Cfg.FIELD_W * 0.5, 250.0),
		"drop_extend": true,
		# Built around the new vocabulary: unfurling rings, scatter carriers and
		# sniper tells, so it plays unlike the first three bosses.
		"phases": [
			{
				"hp": 5200,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 250.0),
					"amp_x": 225.0, "amp_y": 45.0, "freq_x": 0.85, "freq_y": 1.4},
				"attacks": [
					{"pattern": "unfurl", "n": 20, "speed": 225.0, "stagger": 0.03,
						"delay": 0.3, "style": "small", "color": "indigo",
						"aim": false, "start": 1.2, "interval": 2.2},
					{"pattern": "sniper", "speed": 640.0, "delay": 0.8,
						"style": "needle", "color": "white", "start": 2.6,
						"interval": 2.0},
				],
			},
			{
				"hp": 5600,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 235.0),
					"amp_x": 255.0, "amp_y": 70.0, "freq_x": 1.2, "freq_y": 1.9},
				"attacks": [
					{"pattern": "scatter", "n": 3, "spread": 54.0, "speed": 210.0,
						"fuse": 1.05, "style": "seed", "color": "pink",
						"start": 1.0, "interval": 2.3,
						"burst": {"pattern": "ring", "n": 10, "speed": 210.0,
							"style": "small", "color": "pink", "aim": false}},
					{"pattern": "helix", "speed": 235.0, "wave": 38.0,
						"wave_freq": 6.5, "style": "small", "color": "teal",
						"flash": false, "start": 0.8, "interval": 0.22},
				],
			},
			{
				"hp": 6000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 245.0),
					"amp_x": 215.0, "amp_y": 85.0, "freq_x": 1.5, "freq_y": 2.2},
				"attacks": [
					{"pattern": "pinwheel", "arms": 5, "n": 6, "speed": 255.0,
						"arm_gap": 24.0, "rot": 16.0, "style": "shard",
						"color": "cyan", "aim": false, "start": 0.9,
						"interval": 0.44},
					{"pattern": "minefield", "n": 4, "speed": 265.0, "delay": 1.2,
						"style": "orb", "color": "violet", "start": 2.2,
						"interval": 3.0},
				],
			},
			{
				"hp": 6400,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 255.0),
					"amp_x": 240.0, "amp_y": 60.0, "freq_x": 1.9, "freq_y": 2.7},
				"attacks": [
					{"pattern": "bloom", "n": 22, "speed": 450.0, "accel": -570.0,
						"speed_min": -190.0, "style": "orb", "color": "cyan",
						"aim": false, "start": 0.9, "interval": 2.2},
					{"pattern": "gatling", "speed": 390.0, "spread": 8.0,
						"style": "needle", "color": "white", "flash": false,
						"start": 1.6, "interval": 0.10},
					{"pattern": "wave_wall", "n": 12, "speed": 210.0, "wave": 44.0,
						"style": "small", "color": "ember", "start": 3.0,
						"interval": 3.2, "oy": -150.0},
				],
			},
		],
	}


# --- Stage 5: SINGULARITY ----------------------------------------------------

static func _singularity() -> Dictionary:
	return {
		"name": "SINGULARITY",
		"tex": 7,
		"scale": 1.40,
		"radius": 104.0,
		"score": 1_200_000,
		"anchor": Vector2(Cfg.FIELD_W * 0.5, 260.0),
		# Five phases, each stacking one more simultaneous threat than the last.
		"phases": [
			{
				"hp": 5600,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 260.0),
					"amp_x": 230.0, "amp_y": 45.0, "freq_x": 0.9, "freq_y": 1.5},
				"attacks": [
					{"pattern": "dual_spiral", "n": 3, "speed": 210.0, "rot": 10.0,
						"style": "tiny", "color": "violet", "flash": false,
						"start": 0.8, "interval": 0.10},
					{"pattern": "sniper", "speed": 660.0, "delay": 0.75,
						"style": "needle", "color": "white", "start": 2.4,
						"interval": 1.8},
				],
			},
			{
				"hp": 6000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 240.0),
					"amp_x": 265.0, "amp_y": 75.0, "freq_x": 1.3, "freq_y": 2.0},
				"attacks": [
					{"pattern": "unfurl", "n": 22, "speed": 230.0, "stagger": 0.028,
						"delay": 0.26, "style": "small", "color": "indigo",
						"aim": false, "start": 1.0, "interval": 2.0},
					{"pattern": "pinwheel", "arms": 4, "n": 6, "speed": 250.0,
						"arm_gap": 24.0, "rot": -18.0, "style": "shard",
						"color": "teal", "aim": false, "start": 1.8,
						"interval": 0.48},
				],
			},
			{
				"hp": 6400,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 255.0),
					"amp_x": 220.0, "amp_y": 90.0, "freq_x": 1.7, "freq_y": 2.4},
				"attacks": [
					{"pattern": "scatter", "n": 4, "spread": 66.0, "speed": 205.0,
						"fuse": 0.95, "style": "seed", "color": "pink",
						"start": 0.9, "interval": 2.1,
						"burst": {"pattern": "ring", "n": 11, "speed": 220.0,
							"style": "small", "color": "pink", "aim": false}},
					{"pattern": "lockon", "n": 8, "radius": 280.0, "speed": 320.0,
						"style": "small", "color": "red", "delay": 0.6,
						"start": 2.2, "interval": 2.4},
				],
			},
			{
				"hp": 6800,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 245.0),
					"amp_x": 250.0, "amp_y": 70.0, "freq_x": 2.0, "freq_y": 2.8},
				"attacks": [
					{"pattern": "flower", "n": 30, "petals": 6, "variance": 0.55,
						"speed": 235.0, "style": "tiny", "color": "green",
						"aim": false, "start": 1.0, "interval": 1.4, "rot": 12.0},
					{"pattern": "minefield", "n": 5, "speed": 275.0, "delay": 1.1,
						"style": "orb", "color": "violet", "start": 2.0,
						"interval": 2.6},
					{"pattern": "gatling", "speed": 400.0, "spread": 9.0,
						"style": "needle", "color": "white", "flash": false,
						"start": 1.4, "interval": 0.10},
				],
			},
			{
				"hp": 7200,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 260.0),
					"amp_x": 235.0, "amp_y": 55.0, "freq_x": 2.3, "freq_y": 3.1},
				"attacks": [
					{"pattern": "bloom", "n": 28, "speed": 480.0, "accel": -610.0,
						"speed_min": -215.0, "style": "orb", "color": "cyan",
						"aim": false, "start": 0.8, "interval": 1.9},
					{"pattern": "vortex", "n": 20, "speed": 125.0, "accel": 135.0,
						"speed_max": 385.0, "curve": -52.0, "style": "tiny",
						"color": "violet", "aim": false, "start": 1.3,
						"interval": 1.1, "rot": 26.0},
					{"pattern": "wave_wall", "n": 13, "speed": 220.0, "wave": 48.0,
						"style": "small", "color": "ember", "start": 2.2,
						"interval": 2.8, "oy": -160.0},
					{"pattern": "rain", "n": 3, "speed": 300.0, "style": "small",
						"color": "pink", "flash": false, "start": 2.6,
						"interval": 0.42},
				],
			},
		],
	}
