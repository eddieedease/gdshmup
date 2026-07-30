class_name Level4
extends RefCounted
## Stage 4 - ORBITAL DEBRIS.
##
## First stage in vacuum. Leans on the new variants: snipers punishing idle
## players, splitters that keep fighting after they die, orbiters weaving helix
## streams, and minelayers turning the whole field into a timed hazard.

const W := Cfg.FIELD_W


func run(d: Director) -> void:
	d.banner("STAGE 4", "ORBITAL DEBRIS")
	await d.wait(3.2)

	# 1. Debris run: fast fodder from alternating wings.
	for i in 3:
		await d.row("POPCORN", 8, 0.09,
			70.0 if i % 2 == 0 else W - 70.0,
			W - 70.0 if i % 2 == 0 else 70.0, {"hp": 18})
		await d.wait(0.9)
	await d.wait(1.6)

	# 2. Snipers overhead: standing still is now a decision.
	for i in 3:
		d.one("SNIPER", Vector2(W * (0.25 + 0.25 * i), Cfg.SPAWN_Y), {
			"move": {"type": "enter_hold_exit", "enter": 1.0, "hold": 7.0,
				"hold_at": Vector2(W * (0.25 + 0.25 * i), 170.0 + 30.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 330.0, "bob": 8.0},
		})
		await d.wait(0.5)
	await d.wait(2.4)
	await d.snake("WEAVER", 5, 0.20, true)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.4)

	# 3. Splitter shoal - clearing the front rank makes a second one.
	await d.row("SPLITTER", 4, 0.28, 150.0, W - 150.0)
	await d.wait(3.0)
	await d.row("SPLITTER", 4, 0.28, W - 150.0, 150.0)
	await d.wait_until_under(3, 16.0)
	await d.wait(1.6)

	# 4. Orbiter pair braiding helix fire from overhead.
	for i in 2:
		d.one("ORBITER", Vector2(W * 0.5, 250.0), {
			"move": {"type": "arc", "centre": Vector2(W * 0.5, 240.0),
				"radius": 200.0, "omega": 1.5 * (1.0 if i == 0 else -1.0),
				"phase": 180.0 * i},
		})
		await d.wait(0.4)
	await d.wait(6.0)
	await d.wait_clear(9.0)
	await d.wait(1.2)

	# 5. Minelayers: the field itself becomes the threat.
	d.one("MINELAYER", Vector2(W * 0.35, Cfg.SPAWN_Y))
	await d.wait(1.4)
	d.one("MINELAYER", Vector2(W * 0.65, Cfg.SPAWN_Y))
	await d.wait(1.6)
	await d.row("HUNTER", 4, 0.16, 140.0, W - 140.0)
	await d.wait_until_under(2, 18.0)
	await d.wait(1.6)

	# 6. Seeders lobbing scatter carriers over a turret line.
	for i in 2:
		d.one("SEEDER", Vector2(W * (0.3 + 0.4 * i), Cfg.SPAWN_Y), {
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 8.0,
				"hold_at": Vector2(W * (0.3 + 0.4 * i), 200.0),
				"exit_dir": 90.0, "exit_speed": 280.0},
		})
		await d.wait(0.6)
	await d.wait(1.6)
	d.one("TURRET", Vector2(W * 0.5, Cfg.SPAWN_Y), {"hp": 140})
	await d.wait_until_under(2, 20.0)
	await d.wait(1.6)

	# 7. Blade fans sweeping the arena.
	for i in 2:
		d.one("BLADE", Vector2(W * (0.32 + 0.36 * i), Cfg.SPAWN_Y), {
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 8.0,
				"hold_at": Vector2(W * (0.32 + 0.36 * i), 230.0),
				"exit_dir": 90.0, "exit_speed": 280.0},
			"attacks": [{"pattern": "pinwheel", "arms": 4, "n": 5,
				"speed": 250.0, "arm_gap": 26.0,
				"rot": 17.0 * (1.0 if i == 0 else -1.0), "style": "shard",
				"color": "cyan", "aim": false, "start": 1.4, "interval": 0.5}],
		})
		await d.wait(0.7)
	await d.wait(3.0)
	await d.snake("STINGER", 5, 0.20, false)
	await d.wait_until_under(2, 20.0)
	await d.wait(1.6)

	# 8. Warden escort with sniper support.
	d.banner("", "DEBRIS FIELD SENTINEL", 2.0)
	d.one("WARDEN", Vector2(W * 0.5, Cfg.SPAWN_Y), {
		"hp": 1300,
		"move": {"type": "enter_hold_exit", "enter": 1.6, "hold": 15.0,
			"hold_at": Vector2(W * 0.5, 240.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 22.0},
		"attacks": [
			{"pattern": "unfurl", "n": 16, "speed": 215.0, "stagger": 0.035,
				"delay": 0.3, "style": "small", "color": "violet",
				"aim": false, "start": 1.8, "interval": 2.4},
			{"pattern": "aimed", "n": 4, "spread": 30.0, "speed": 300.0,
				"style": "needle", "color": "white", "start": 3.2,
				"interval": 2.4},
		],
	})
	await d.wait(2.4)
	d.one("SNIPER", Vector2(W * 0.18, Cfg.SPAWN_Y))
	d.one("SNIPER", Vector2(W * 0.82, Cfg.SPAWN_Y))
	await d.wait_clear(28.0)
	await d.wait(1.8)

	# 9. Last push: everything the stage taught, at once.
	d.one("MINELAYER", Vector2(W * 0.5, Cfg.SPAWN_Y))
	await d.wait(1.2)
	await d.row("SPLITTER", 3, 0.3, 180.0, W - 180.0)
	await d.wait(2.0)
	await d.crossfire("LANCER", 4, 0.44, 380.0, 150.0)
	await d.wait_until_under(2, 18.0)
	await d.wait(2.2)

	await d.boss(BossDefs.get_boss(3))
