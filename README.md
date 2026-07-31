# StressReliever

A DoDonPachi-style vertical danmaku shooter built in Godot 4.7.
Developed by EDease.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | `WASD` or arrow keys | Left stick / D-pad |
| Shot | `J` | A / X |
| Laser | `K` | B / Y |
| Bomb | `Space` or `L` | Shoulder buttons |
| Confirm | `Enter` / `J` | A / Start |
| Pause | `Esc` / `P` | Start |
| Fullscreen | `F11` | — |
| Screenshot | `F12` (saves to `user://`) | — |

`J` and `K` always mean "fast weapon" and "slow weapon", but what they fire
depends on which of the two **weapon modes** you are carrying. `K` slows you to
roughly 40% in both, which is the trade that makes precise dodging possible, and
holding both buttons favours `K`. Your real hitbox is a few pixels wide and is
shown as a dot while `K` is held.

### VULCAN (starting weapon)

**Shot** (`J`) is a wide spread at full speed with the option bits fanned out.
**Laser** (`K`) tucks the bits in tight and replaces the spread with a piercing
beam. Power widens the spread, adds bits, and fattens the beam.

### TRACKER

Picked up in the field (see below). One homing beam fires out of the ship on
`J` — a braided rope of segments that snakes onto whatever is nearest. It is
deliberately weaker per second than the same ship's vulcan; what you buy is that
it hits things you are not pointing at. The option bits dock and go dark in this
mode: power makes the *beam itself* bigger rather than adding more guns.

`K` paints targets *as well as* firing — the beam keeps going on either button
(slower on `K` alone), because a weapon that stops shooting while you set up a
lock leaves the screen empty for a second or two. A ring opens and widens
while you hold it, bracketing everything it touches; releasing sends one very
fast homing missile at each painted target. The ring is deliberately huge — it
opens at a full playfield width across (`Cfg.LOCK_RADIUS_MIN`) before it starts
growing, because the mode buys its reach with movement speed and a ring you
have to fly into things to use would just be a worse vulcan. What balances it
is the salvo size, not the reach: three missiles at power 1 however much field
the ring covers, rising to fourteen at full power. Both the ring and the cap
grow with every power level, so the same weapon is a scalpel early and a net
late. Ordinary enemies
take at most `Cfg.LOCK_STACK_MAX` missiles each so a salvo spreads across a
wave, but a boss will take the entire rack. A short dead time after each salvo
(`Player.LOCK_REFIRE`) stops tapping `K` from machine-gunning single missiles.

Every ship flies both modes with its own numbers — see the `track_*` and
`lock_*` arrays in `scripts/data/ship_defs.gd`. Hornet is even-handed, Falcon
gets a thin fast hard-turning ribbon and a small ring, Goliath a slow fat rope,
the widest ring and by far the heaviest salvo.

## Layout

Gameplay runs in a fixed 810x1080 column (classic 3:4 arcade "tate" aspect), so
every ship, bullet and spawn point is authored in the same coordinates whatever
you play on. That column is scaled to the window height and centred at runtime
(`Cfg.field_rect`), which keeps 16:10 and 3:2 laptops free of the dead strip an
un-scaled column would leave under the field. The sidebars fill whatever is left
over and double as a mask for anything that spills outside the column; they
never shrink below `Cfg.MIN_SIDEBAR`, and on a window too tall for even that the
field is capped top and bottom with matching cabinet trim.

## Dev switches

Passed after `--`. See `_apply_cli` in `scripts/main.gd` for the full list.
`--size=WxH` forces a windowed size (for aspect-ratio checks) and
`--shot=PATH --shot-at=FRAME` grabs a still and quits, so a change can be
eyeballed without a human at the keyboard:

```bash
godot --path . -- --size=1600x1000 --screen=game --shot=shot.png --shot-at=150
```

`--demo` drives the ship itself, and pairs with `--hunt` (fly at the nearest
enemy, which is the only way the range-limited lock ring gets exercised),
`--power=N`, `--weapon-at=SECONDS`, `--boss`, `--stage=N` and `--ship=N`.

## Pickups

| Item | Effect |
| --- | --- |
| `P` | Power chip. Later bars cost more chips, so full power lands mid-run. |
| `B` | A bomb. Stops dropping while you already hold `Cfg.MAX_BOMBS` (3) — a full rack pays out as points instead, so bosses cannot simply be deleted with a hoarded stock. |
| `W` | Swaps between VULCAN and TRACKER. Four per stage (`Cfg.WEAPON_DROPS_PER_STAGE`), one every 18 kills rather than on a die roll, plus one from every boss. Paced on kills, not on the enemies that drop power and bombs — those are scarce enough that gating on them left a whole stage going by on one weapon. |
| `1UP` | Spare ship. Dropped by the bosses flagged in `BossDefs`. |
| stars | Score, and a trickle of hyper charge. |

## Scoring

Destroying enemies without a gap builds a **chain**; the multiplier climbs to
x6 and resets ~1.35s after you stop landing damage. Grazing bullets, collecting
stars and bombing bullets off the screen all add score. Extends at 2M / 5M / 10M.

## Modes

**Arcade** — the authored five-stage run on one credit. No continues. This is
the mode the pacing and difficulty curve were tuned for.

**Endless** — the same stages, looping forever and getting harder each lap
(x1.35 enemy health per loop, plus fire rate and speed). You may continue as
often as you like, but every continue resets your score to zero and drops you
back to base power, so continues buy *depth*, not points. The leaderboard
records the best score reached on any single credit, plus the loop and stage
you got to.

Each mode keeps its own ranking table — they are not comparable achievements.
Press A/D on the high-score screen to switch boards.

## Stages

Five stages: three over terrain, then two in vacuum. The space themes are
procedural (starfield, drifting nebula bands, tumbling debris built from the
rock tiles) since the asset pack has no space art — see the `space` flag in
`Terrain.PALETTES`.

Music is resolved at runtime, so dropping `levelN.mp3` into `assets/music`
is all that is needed to score a new stage.

## Power and hyper

Power items are **chips**, and each bar costs more per level (2 / 3 / 4), so
full power lands around stage three rather than stage one. Power runs to
**12 levels across three bars**. Bar one is the old full-power
ramp; bar two adds a wide secondary volley and a third option bit, bar three a
swept-back pair and a fourth bit. Option bits share one damage budget, so the
extra bits widen your coverage rather than multiplying raw damage.

The **hyper** meter fills from kills, grazes and pickups, then fires itself when
it tops out. While hyper is up you fire faster and enemy bullets near the hull
are *absorbed for score* instead of killing you.

## Structure

```
scripts/
  main.gd              screen flow (title -> ship select -> game)
  game.gd              the playing scene: field, scoring, stage progression
  autoload/gs.gd       persistence + input map (built in code)
  autoload/audio.gd    music playback + synthesised SFX bank
  core/                cfg, art, bullets, patterns, fx, items, terrain
  player/              ship, option bits, laser beam
  enemy/               data-driven enemy, multi-phase boss
  data/                ship / enemy / boss / stage tables
  levels/              director + one coroutine script per stage
  ui/                  hud, cabinet frame, title, ship select
  dev/                 demo driver (`--demo`)
```

Enemies and attacks are plain dictionaries: one movement behaviour plus a list
of scheduled `Patterns` specs. Stages are coroutines that read like a
storyboard, so new waves are a few lines in `scripts/levels/`.

Sound effects have no source assets — they are synthesised as 16-bit PCM at
startup from the table in `scripts/autoload/audio.gd`.

### Asset orientation

The sprite sheets are not consistently oriented and the `.json` sidecars are not
a reliable guide: the player ships are drawn nose-**up**, every enemy sheet is
drawn nose-**down**, and the "bank left"/"bank right" clip labels are swapped
relative to the pixels. `tools/orientation_probe.gd` derives the true facing by
diffing the two thrust frames of a row — the pixels that change are the exhaust
flame, so their vertical position locates the tail:

```
godot --headless --path . --script res://tools/orientation_probe.gd
```

Re-run it if new ship sheets are added.

## Dev switches

Pass after `--`:

```
--screen=title|select|game   start on a given screen
--stage=N                    begin at stage N (1-3)
--ship=N                     preselect ship N (1-3)
--boss                       boss rush: skip the waves
--demo                       drive the ship automatically
--hyper-at=SEC               fill the hyper meter once, to inspect the state
--tunnel-at=SEC              fire a stage transition, to inspect the tunnel
--pause-at=SEC               open the pause menu
```
