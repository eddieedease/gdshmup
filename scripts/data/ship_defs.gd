class_name ShipDefs
extends RefCounted
## The three selectable ships.
##
## Each ship carries the DoDonPachi-style pair of weapons:
##   SHOT  (J) - rapid spread, full movement speed
##   LASER (K) - focused continuous beam, movement slowed for precise dodging
##
## Per-power arrays are indexed by (power - 1), power running 1..Cfg.MAX_POWER.

const SHIPS := [
	{
		"name": "HORNET",
		"code": "TYPE-A",
		"tag": "ALL-ROUND GUNSHIP",
		"blurb": "Even spread, dependable beam.\nThe safe pick for learning a stage.",
		"tex": 0,
		"color": Color(0.36, 0.88, 1.0),
		"speed_shot": 560.0,
		"speed_laser": 235.0,
		"shot_rate": 0.060,
		"shot_n": [2, 3, 4, 5],
		"shot_spread": 15.0,
		"shot_damage": [4, 4, 5, 5],
		"shot_speed": 1250.0,
		"opt_count": [1, 2, 2, 2],
		"opt_mode": "straight",
		"opt_damage": [3, 3, 4, 4],
		"opt_rate": 0.085,
		"laser_width": [30.0, 38.0, 47.0, 58.0],
		"laser_dps": [175.0, 220.0, 270.0, 330.0],
		"opt_spread": [58.0, 104.0],
		"opt_tight": [17.0, 31.0],
		"stats": {"SPEED": 3, "POWER": 3, "SPREAD": 3},
	},
	{
		"name": "FALCON",
		"code": "TYPE-B",
		"tag": "HIGH-SPEED INTERCEPTOR",
		"blurb": "Fastest hull, needle-thin laser.\nRewards aggressive point-blank play.",
		"tex": 1,
		"color": Color(1.0, 0.42, 0.40),
		"speed_shot": 710.0,
		"speed_laser": 305.0,
		"shot_rate": 0.042,
		"shot_n": [2, 2, 3, 4],
		"shot_spread": 7.0,
		"shot_damage": [4, 5, 5, 6],
		"shot_speed": 1500.0,
		"opt_count": [1, 2, 2, 2],
		"opt_mode": "straight",
		"opt_damage": [3, 3, 4, 5],
		"opt_rate": 0.060,
		"laser_width": [20.0, 25.0, 31.0, 38.0],
		"laser_dps": [205.0, 260.0, 320.0, 395.0],
		"opt_spread": [40.0, 72.0],
		"opt_tight": [11.0, 20.0],
		"stats": {"SPEED": 5, "POWER": 4, "SPREAD": 1},
	},
	{
		"name": "GOLIATH",
		"code": "TYPE-C",
		"tag": "HEAVY ASSAULT ROCKET",
		"blurb": "Widest shot, seeking missiles,\nsiege-grade beam. Slow to turn.",
		"tex": 2,
		"color": Color(1.0, 0.80, 0.30),
		"speed_shot": 440.0,
		"speed_laser": 180.0,
		"shot_rate": 0.078,
		"shot_n": [3, 4, 5, 6],
		"shot_spread": 32.0,
		"shot_damage": [5, 6, 6, 7],
		"shot_speed": 1050.0,
		"opt_count": [1, 2, 2, 2],
		"opt_mode": "missile",
		"opt_damage": [7, 8, 9, 11],
		"opt_rate": 0.24,
		"laser_width": [42.0, 53.0, 66.0, 80.0],
		"laser_dps": [155.0, 195.0, 240.0, 295.0],
		"opt_spread": [70.0, 122.0],
		"opt_tight": [22.0, 40.0],
		"stats": {"SPEED": 1, "POWER": 5, "SPREAD": 5},
	},
]


static func get_ship(i: int) -> Dictionary:
	return SHIPS[clampi(i, 0, SHIPS.size() - 1)]


static func count() -> int:
	return SHIPS.size()


## Reads a per-power array (or a plain value) for the given power level.
static func at_power(ship: Dictionary, key: String, power: int) -> Variant:
	var v: Variant = ship[key]
	if v is Array:
		return v[clampi(power - 1, 0, v.size() - 1)]
	return v
