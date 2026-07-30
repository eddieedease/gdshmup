class_name LevelDefs
extends RefCounted
## Stage metadata: which script runs, which terrain palette to scroll, and how
## hard the enemies hit. Difficulty is applied uniformly by Director to the
## reusable enemy archetypes; bosses ignore it and carry authored numbers.
##
## The curve is stretched over five stages rather than three, so the early
## multipliers are gentler than they were and the top end climbs further.

const STAGES := [
	{
		"title": "STAGE 1",
		"name": "VERDANT COAST",
		"terrain": 0,
		"difficulty": {"hp": 1.0, "fire_rate": 1.0, "speed": 1.0},
	},
	{
		"title": "STAGE 2",
		"name": "SCORCHED FLATS",
		"terrain": 1,
		"difficulty": {"hp": 1.6, "fire_rate": 1.18, "speed": 1.08},
	},
	{
		"title": "STAGE 3",
		"name": "GLACIER CORE",
		"terrain": 2,
		"difficulty": {"hp": 2.3, "fire_rate": 1.32, "speed": 1.16},
	},
	{
		"title": "STAGE 4",
		"name": "ORBITAL DEBRIS",
		"terrain": 3,
		"difficulty": {"hp": 3.1, "fire_rate": 1.44, "speed": 1.24},
	},
	{
		"title": "FINAL STAGE",
		"name": "VOID CORE",
		"terrain": 4,
		"difficulty": {"hp": 4.0, "fire_rate": 1.56, "speed": 1.32},
	},
]


static func count() -> int:
	return STAGES.size()


static func meta(i: int) -> Dictionary:
	return STAGES[clampi(i, 0, STAGES.size() - 1)]


static func script_for(i: int) -> RefCounted:
	match i:
		0:
			return Level1.new()
		1:
			return Level2.new()
		2:
			return Level3.new()
		3:
			return Level4.new()
		_:
			return Level5.new()
