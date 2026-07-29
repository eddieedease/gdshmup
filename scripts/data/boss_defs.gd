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
		_:
			return _omega()


# --- Stage 1: ARBITER --------------------------------------------------------

static func _arbiter() -> Dictionary:
	return {
		"name": "ARBITER",
		"tex": 6,
		"scale": 0.95,
		"radius": 74.0,
		"score": 120_000,
		"anchor": CENTRE,
		"phases": [
			{
				"hp": 5000,
				"move": {"type": "sway", "centre": CENTRE, "amp_x": 200.0,
					"amp_y": 40.0, "freq_x": 0.7, "freq_y": 1.1},
				"attacks": [
					{"pattern": "ring", "n": 14, "speed": 195.0, "rot": 13.0,
						"style": "small", "color": "blue", "aim": false,
						"start": 1.0, "interval": 1.25},
					{"pattern": "aimed", "n": 3, "spread": 20.0, "speed": 330.0,
						"style": "needle", "color": "white",
						"start": 2.0, "interval": 1.8, "burst": 2, "burst_gap": 0.12},
				],
			},
			{
				"hp": 6000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 230.0),
					"amp_x": 250.0, "amp_y": 60.0, "freq_x": 1.05, "freq_y": 1.7},
				"attacks": [
					{"pattern": "dual_spiral", "n": 2, "speed": 200.0, "rot": 9.0,
						"style": "tiny", "color": "violet", "flash": false,
						"start": 0.8, "interval": 0.09},
					{"pattern": "wall", "n": 15, "gap": 3, "speed": 210.0,
						"style": "small", "color": "amber",
						"start": 2.2, "interval": 3.0, "oy": -120.0},
				],
			},
			{
				"hp": 7000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 245.0),
					"amp_x": 215.0, "amp_y": 75.0, "freq_x": 1.35, "freq_y": 2.1},
				"attacks": [
					{"pattern": "bloom", "n": 20, "speed": 430.0, "accel": -560.0,
						"speed_min": -190.0, "style": "orb", "color": "cyan",
						"aim": false, "start": 1.0, "interval": 2.3},
					{"pattern": "lockon", "n": 7, "radius": 250.0, "speed": 290.0,
						"style": "small", "color": "pink", "delay": 0.65,
						"start": 2.4, "interval": 2.6},
					{"pattern": "spray", "n": 4, "spread": 60.0, "speed": 250.0,
						"style": "tiny", "color": "pink", "flash": false,
						"start": 0.6, "interval": 0.5},
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
		"phases": [
			{
				"hp": 7000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 240.0),
					"amp_x": 230.0, "amp_y": 35.0, "freq_x": 0.85, "freq_y": 1.4},
				"attacks": [
					{"pattern": "flower", "n": 26, "petals": 5, "variance": 0.5,
						"speed": 215.0, "style": "small", "color": "green",
						"aim": false, "start": 1.0, "interval": 1.7, "rot": 7.0},
					{"pattern": "homing", "n": 2, "spread": 150.0, "speed": 120.0,
						"style": "missile", "color": "amber", "homing": 140.0,
						"homing_time": 2.0, "start": 2.5, "interval": 3.2},
				],
			},
			{
				"hp": 8000,
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
				"hp": 9000,
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
				"hp": 9000,
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
				"hp": 10000,
				"move": {"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 235.0),
					"amp_x": 270.0, "amp_y": 80.0, "freq_x": 1.4, "freq_y": 2.2},
				"attacks": [
					{"pattern": "wall", "n": 17, "gap": 3, "speed": 235.0,
						"style": "small", "color": "amber", "start": 1.0,
						"interval": 1.5, "oy": -150.0},
					{"pattern": "dual_spiral", "n": 3, "speed": 215.0, "rot": 12.0,
						"style": "tiny", "color": "violet", "flash": false,
						"start": 0.6, "interval": 0.085},
				],
			},
			{
				"hp": 11000,
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
						"style": "missile", "color": "amber", "homing": 160.0,
						"homing_time": 2.2, "start": 3.0, "interval": 3.4},
				],
			},
			{
				"hp": 12000,
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
