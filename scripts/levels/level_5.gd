class_name Level5
extends RefCounted
## Stage 5 - VOID CORE.
##
## The finale. Every archetype in the game shows up, usually two kinds at once,
## and the waves overlap rather than queue politely.

const W := Cfg.FIELD_W


func run(d: Director) -> void:
	d.banner("FINAL STAGE", "VOID CORE")
	await d.wait(3.2)

	# 1. No warm-up: three ranks and a sniper line together.
	d.row("POPCORN", 9, 0.08, 60.0, W - 60.0, {"hp": 22})
	await d.wait(0.5)
	d.row("POPCORN", 9, 0.08, W - 60.0, 60.0, {"hp": 22})
	await d.wait(0.8)
	for i in 2:
		d.one("SNIPER", Vector2(W * (0.3 + 0.4 * i), Cfg.SPAWN_Y))
		await d.wait(0.4)
	await d.wait_until_under(3, 14.0)
	await d.wait(1.2)

	# 2. Counter-rotating orbiters over a splitter shoal.
	for i in 2:
		d.one("ORBITER", Vector2(W * 0.5, 240.0), {
			"hp": 80,
			"move": {"type": "arc", "centre": Vector2(W * 0.5, 235.0),
				"radius": 215.0, "omega": 1.7 * (1.0 if i == 0 else -1.0),
				"phase": 180.0 * i},
		})
		await d.wait(0.35)
	await d.wait(1.4)
	await d.row("SPLITTER", 5, 0.22, 130.0, W - 130.0)
	await d.wait_until_under(3, 20.0)
	await d.wait(1.4)

	# 3. Blade cross: two fans turning against each other.
	for i in 3:
		d.one("BLADE", Vector2(W * (0.24 + 0.26 * i), Cfg.SPAWN_Y), {
			"hp": 150,
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 9.0,
				"hold_at": Vector2(W * (0.24 + 0.26 * i), 200.0 + 45.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 290.0},
			"attacks": [{"pattern": "pinwheel", "arms": 5, "n": 5,
				"speed": 255.0, "arm_gap": 24.0,
				"rot": 19.0 * (1.0 if i % 2 == 0 else -1.0), "style": "shard",
				"color": ["cyan", "indigo", "teal"][i], "aim": false,
				"start": 1.3, "interval": 0.46}],
		})
		await d.wait(0.45)
	await d.wait(4.0)
	await d.row("HUNTER", 5, 0.14, 120.0, W - 120.0)
	await d.wait_until_under(2, 22.0)
	await d.wait(1.4)

	# 4. Wave curtains from bombers whose gaps move.
	for i in 3:
		d.one("BOMBER", Vector2(W * (0.24 + 0.26 * i), Cfg.SPAWN_Y), {
			"hp": 170,
			"move": {"type": "line", "dir": 90.0, "speed": 74.0},
			"attacks": [{"pattern": "wave_wall", "n": 12, "speed": 205.0,
				"wave": 46.0, "wave_freq": 3.4, "style": "small",
				"color": ["ember", "pink", "violet"][i],
				"start": 0.9 + 0.5 * i, "interval": 2.1}],
		})
		await d.wait(0.55)
	await d.wait(2.6)
	await d.snake("STINGER", 6, 0.16, true, {"hp": 70})
	await d.wait_until_under(2, 22.0)
	await d.wait(1.4)

	# 5. Seeder battery: scatter carriers bursting all over the field.
	for i in 3:
		d.one("SEEDER", Vector2(W * (0.26 + 0.24 * i), Cfg.SPAWN_Y), {
			"hp": 150,
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 9.0,
				"hold_at": Vector2(W * (0.26 + 0.24 * i), 190.0 + 40.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 290.0},
		})
		await d.wait(0.5)
	await d.wait(3.4)
	await d.crossfire("LANCER", 4, 0.40, 400.0, 560.0)
	await d.wait_until_under(2, 22.0)
	await d.wait(1.4)

	# 6. Mine grid plus guards: nowhere is safe for long.
	d.one("MINELAYER", Vector2(W * 0.28, Cfg.SPAWN_Y), {"hp": 170})
	d.one("MINELAYER", Vector2(W * 0.72, Cfg.SPAWN_Y), {"hp": 170})
	await d.wait(2.0)
	for i in 2:
		d.one("GUARD", Vector2(W * (0.36 + 0.28 * i), Cfg.SPAWN_Y), {
			"hp": 260,
			"move": {"type": "enter_hold_exit", "enter": 1.4, "hold": 8.0,
				"hold_at": Vector2(W * (0.36 + 0.28 * i), 215.0),
				"exit_dir": 90.0, "exit_speed": 265.0},
		})
		await d.wait(0.6)
	await d.wait_until_under(2, 24.0)
	await d.wait(1.6)

	# 7. Triple carousel with the centre ring reversed.
	d.carousel("SCOUT", 9, 280.0, 1.3, {"hp": 40})
	await d.wait(0.7)
	d.carousel("SCOUT", 7, 190.0, -1.8, {"hp": 40})
	await d.wait(0.7)
	d.carousel("POPCORN", 5, 105.0, 2.6, {"hp": 28})
	await d.wait(9.0)
	await d.wait_clear(10.0)
	await d.wait(1.2)

	# 8. Twin wardens, one per side, with entirely different arsenals.
	d.banner("", "VOID GATE WARDENS", 2.2)
	d.one("WARDEN", Vector2(W * 0.27, Cfg.SPAWN_Y), {
		"hp": 800,
		"move": {"type": "enter_hold_exit", "enter": 1.6, "hold": 18.0,
			"hold_at": Vector2(W * 0.27, 245.0), "exit_dir": 90.0,
			"exit_speed": 245.0, "bob": 22.0},
		"attacks": [
			{"pattern": "unfurl", "n": 18, "speed": 220.0, "stagger": 0.03,
				"delay": 0.28, "style": "small", "color": "violet",
				"aim": false, "start": 1.6, "interval": 2.2},
			{"pattern": "gatling", "speed": 380.0, "spread": 7.0,
				"style": "needle", "color": "white", "flash": false,
				"start": 3.0, "interval": 0.11, "until": 16.0},
		],
	})
	d.one("WARDEN", Vector2(W * 0.73, Cfg.SPAWN_Y), {
		"hp": 800,
		"move": {"type": "enter_hold_exit", "enter": 2.0, "hold": 18.0,
			"hold_at": Vector2(W * 0.73, 245.0), "exit_dir": 90.0,
			"exit_speed": 245.0, "bob": 22.0},
		"attacks": [
			{"pattern": "scatter", "n": 3, "spread": 60.0, "speed": 200.0,
				"fuse": 1.0, "style": "seed", "color": "pink",
				"start": 2.0, "interval": 2.6,
				"payload": {"pattern": "ring", "n": 10, "speed": 215.0,
					"style": "small", "color": "pink", "aim": false}},
			{"pattern": "petal", "n": 12, "speed": 220.0, "curve": -58.0,
				"style": "small", "color": "teal", "start": 3.4,
				"interval": 1.6},
		],
	})
	await d.wait(4.0)
	await d.row("POPCORN", 8, 0.12, 100.0, W - 100.0, {"hp": 24})
	await d.wait_clear(36.0)
	await d.wait(2.0)

	# 9. The gauntlet before the gate.
	await d.row("SNIPER", 4, 0.4, 140.0, W - 140.0, {"hp": 90})
	await d.wait(2.4)
	d.one("SEEDER", Vector2(W * 0.5, Cfg.SPAWN_Y), {"hp": 170})
	await d.wait(1.4)
	await d.crossfire("LANCER", 5, 0.36, 410.0, 170.0)
	await d.wait_until_under(2, 22.0)
	await d.wait(2.4)

	await d.boss(BossDefs.get_boss(4))
