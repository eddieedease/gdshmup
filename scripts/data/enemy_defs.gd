class_name EnemyDefs
extends RefCounted
## Catalogue of reusable enemy archetypes.
##
## Levels reference these by name and tweak them through make(), e.g.
##   EnemyDefs.make("TURRET", {"attacks": [...], "hp": 90})
## Movement is usually overridden per wave; the defaults here are just sane
## starting points so a bare spawn already behaves sensibly.

const TYPES := {
	# --- Fodder --------------------------------------------------------------
	"POPCORN": {
		"tex": 0, "hp": 9, "scale": 0.17, "radius": 15, "score": 80,
		"move": {"type": "line", "dir": 90.0, "speed": 300.0},
		"attacks": [],
		"drop": "star",
	},
	"SCOUT": {
		"tex": 0, "hp": 16, "scale": 0.20, "radius": 17, "score": 120,
		"move": {"type": "line", "dir": 90.0, "speed": 250.0},
		"attacks": [{
			"pattern": "aimed", "n": 1, "speed": 250.0, "style": "small",
			"color": "pink", "start": 0.7, "interval": 1.5,
		}],
		"drop": "star",
	},
	"WEAVER": {
		"tex": 1, "hp": 24, "scale": 0.22, "radius": 19, "score": 200,
		"move": {"type": "sine", "dir": 90.0, "speed": 170.0, "amp": 95.0, "freq": 2.2},
		"attacks": [{
			"pattern": "aimed", "n": 3, "spread": 22.0, "speed": 235.0,
			"style": "small", "color": "violet", "start": 0.9, "interval": 1.35,
		}],
		"drop": "star",
	},
	"LANCER": {
		"tex": 6, "hp": 36, "scale": 0.24, "radius": 21, "score": 320,
		"face": "vel",
		"move": {"type": "line", "dir": 70.0, "speed": 330.0},
		# A pack of these used to put ~9 needles each into the air per cycle,
		# which only left the screen edges survivable.
		"attacks": [{
			"pattern": "aimed", "n": 2, "spread": 18.0, "speed": 295.0,
			"style": "needle", "color": "cyan", "start": 0.7,
			"interval": 1.7, "burst": 2, "burst_gap": 0.13,
		}],
		"drop": "star",
	},
	"HUNTER": {
		"tex": 3, "hp": 30, "scale": 0.23, "radius": 20, "score": 340,
		"face": "vel",
		"move": {"type": "dive", "speed": 520.0, "accel": 620.0, "lock": 0.6},
		"attacks": [{
			"pattern": "shotgun", "n": 7, "spread": 30.0, "speed": 300.0,
			"style": "small", "color": "red", "start": 0.45,
			"interval": 0.9, "count": 2,
		}],
		"drop": "star",
	},
	"SEEKER": {
		"tex": 8, "hp": 46, "scale": 0.24, "radius": 21, "score": 420,
		"move": {"type": "drift", "speed": 95.0, "track": 65.0},
		"attacks": [{
			"pattern": "homing", "n": 2, "spread": 130.0, "speed": 130.0,
			"style": "missile", "color": "ember", "start": 1.0, "interval": 2.1,
			"homing": 130.0, "homing_time": 1.8,
		}],
		"drop": "power",
	},

	# --- Emplacements --------------------------------------------------------
	"TURRET": {
		"tex": 2, "hp": 62, "scale": 0.28, "radius": 26, "score": 600,
		"move": {
			"type": "enter_hold_exit", "enter": 1.1, "hold": 4.2,
			"exit_dir": 90.0, "exit_speed": 300.0,
		},
		"attacks": [{
			"pattern": "ring", "n": 10, "speed": 190.0, "style": "small",
			"color": "blue", "start": 1.3, "interval": 1.5, "rot": 18.0,
		}],
		"drop": "power",
	},
	"SPINNER": {
		"tex": 5, "hp": 78, "scale": 0.28, "radius": 26, "score": 750,
		"move": {
			"type": "enter_hold_exit", "enter": 1.2, "hold": 5.5,
			"exit_dir": 90.0, "exit_speed": 280.0,
		},
		"attacks": [{
			"pattern": "spiral", "n": 3, "speed": 205.0, "style": "tiny",
			"color": "violet", "start": 1.4, "interval": 0.11, "rot": 16.0,
			"aim": false, "until": 5.6, "flash": false,
		}],
		"drop": "power",
	},
	"BOMBER": {
		"tex": 4, "hp": 105, "scale": 0.34, "radius": 33, "score": 900,
		"move": {"type": "line", "dir": 90.0, "speed": 95.0},
		"attacks": [{
			"pattern": "wall", "n": 15, "gap": 3, "speed": 195.0,
			"style": "small", "color": "ember", "start": 1.1, "interval": 2.0,
		}],
		"drop": "bomb",
	},
	"GUARD": {
		"tex": 7, "hp": 150, "scale": 0.34, "radius": 32, "score": 1200,
		"move": {
			"type": "enter_hold_exit", "enter": 1.4, "hold": 6.0,
			"exit_dir": 90.0, "exit_speed": 260.0,
		},
		"attacks": [{
			"pattern": "bloom", "n": 18, "speed": 430.0, "accel": -540.0,
			"speed_min": -170.0, "style": "orb", "color": "cyan",
			"start": 1.6, "interval": 2.4,
		}],
		"drop": "power",
	},
	"STINGER": {
		"tex": 1, "hp": 40, "scale": 0.23, "radius": 20, "score": 400,
		"face": "vel",
		"move": {
			"type": "path", "seg_time": 0.85, "exit_dir": 90.0, "exit_speed": 340.0,
			"points": [],
		},
		"attacks": [{
			"pattern": "whip", "n": 1, "speed": 210.0, "ramp": 26.0, "cycle": 9,
			"style": "small", "color": "green", "start": 0.6,
			"interval": 0.10, "count": 9, "flash": false,
		}],
		"drop": "star",
	},
	# --- Variants introduced for the space stages ----------------------------
	"SNIPER": {
		# Holds high and telegraphs single very fast shots: punishes idling.
		"tex": 6, "hp": 70, "scale": 0.24, "radius": 21, "score": 500,
		"move": {
			"type": "enter_hold_exit", "enter": 1.0, "hold": 6.0,
			"exit_dir": 90.0, "exit_speed": 330.0, "bob": 8.0,
		},
		"attacks": [{
			"pattern": "sniper", "speed": 620.0, "delay": 0.85,
			"style": "needle", "color": "white", "start": 1.2, "interval": 1.6,
		}],
		"drop": "star",
	},
	"SPLITTER": {
		# Dies into two escorts, so clearing it is not the end of the exchange.
		"tex": 2, "hp": 55, "scale": 0.26, "radius": 24, "score": 450,
		"move": {"type": "sine", "dir": 90.0, "speed": 140.0, "amp": 70.0,
			"freq": 1.7},
		"attacks": [{
			"pattern": "nway", "n": 4, "spread": 60.0, "speed": 210.0,
			"style": "small", "color": "teal", "start": 0.9, "interval": 1.5,
		}],
		"spawn_on_death": {"type": "POPCORN", "count": 2, "spread": 150.0},
		"drop": "star",
	},
	"ORBITER": {
		# Circles a point overhead while streaming weaving fire.
		"tex": 5, "hp": 60, "scale": 0.23, "radius": 20, "score": 480,
		"face": "vel",
		"move": {"type": "arc", "radius": 190.0, "omega": 1.6},
		"attacks": [{
			"pattern": "helix", "speed": 230.0, "wave": 34.0, "wave_freq": 7.0,
			"style": "small", "color": "indigo", "flash": false,
			"start": 0.8, "interval": 0.22,
		}],
		"drop": "star",
	},
	"MINELAYER": {
		# Seeds delayed bullets across the field: forces you to keep moving.
		"tex": 4, "hp": 130, "scale": 0.30, "radius": 29, "score": 900,
		"move": {"type": "line", "dir": 90.0, "speed": 85.0},
		"attacks": [{
			"pattern": "minefield", "n": 5, "speed": 250.0, "delay": 1.3,
			"style": "orb", "color": "violet", "start": 1.0, "interval": 2.6,
		}],
		"drop": "bomb",
	},
	"SEEDER": {
		# Lobs scatter carriers that burst into rings mid-screen.
		"tex": 8, "hp": 110, "scale": 0.28, "radius": 26, "score": 800,
		"move": {
			"type": "enter_hold_exit", "enter": 1.2, "hold": 6.5,
			"exit_dir": 90.0, "exit_speed": 280.0,
		},
		"attacks": [{
			"pattern": "scatter", "n": 3, "spread": 46.0, "speed": 205.0,
			"fuse": 1.1, "style": "seed", "color": "pink",
			"start": 1.3, "interval": 2.4,
			"payload": {"pattern": "ring", "n": 9, "speed": 205.0,
				"style": "small", "color": "pink", "aim": false},
		}],
		"drop": "power",
	},
	"BLADE": {
		# Rotating straight arms that sweep the arena like a fan.
		"tex": 3, "hp": 120, "scale": 0.28, "radius": 26, "score": 850,
		"move": {
			"type": "enter_hold_exit", "enter": 1.2, "hold": 7.0,
			"exit_dir": 90.0, "exit_speed": 280.0,
		},
		"attacks": [{
			"pattern": "pinwheel", "arms": 4, "n": 5, "speed": 250.0,
			"arm_gap": 26.0, "rot": 17.0, "style": "shard", "color": "cyan",
			"aim": false, "start": 1.4, "interval": 0.5,
		}],
		"drop": "power",
	},
	"WARDEN": {
		"tex": 7, "hp": 1800, "scale": 0.46, "radius": 46, "score": 6000,
		"move": {
			"type": "enter_hold_exit", "enter": 1.6, "hold": 12.0,
			"exit_dir": 90.0, "exit_speed": 240.0, "bob": 22.0,
		},
		"attacks": [
			{
				"pattern": "petal", "n": 12, "speed": 210.0, "curve": 55.0,
				"style": "small", "color": "pink", "start": 1.8, "interval": 1.5,
			},
			{
				"pattern": "aimed", "n": 5, "spread": 34.0, "speed": 300.0,
				"style": "needle", "color": "white", "start": 3.0, "interval": 2.2,
			},
		],
		"drop": "bomb",
	},
}


## Returns a fresh copy of an archetype with `overrides` merged in.
static func make(type_name: String, overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = TYPES[type_name].duplicate(true)
	for k in overrides:
		base[k] = overrides[k]
	return base


## Convenience for the common case of "same enemy, different flight path".
static func moved(type_name: String, move: Dictionary,
		overrides: Dictionary = {}) -> Dictionary:
	var o := overrides.duplicate()
	o["move"] = move
	return make(type_name, o)
