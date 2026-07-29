# GDSHMUP

A DoDonPachi-style vertical danmaku shooter built in Godot 4.7.

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

**Shot** keeps you at full speed with a wide spread and the option bits fanned
out. **Laser** cuts your speed to roughly 40%, tucks the bits in tight and
replaces the spread with a piercing beam — the trade that makes precise dodging
possible. Holding both favours the laser. Your real hitbox is a few pixels wide
and is shown as a dot while the laser is held.

## Layout

The playfield is a fixed 810x1080 column (classic 3:4 arcade "tate" aspect)
centred in the window. The sidebars fill whatever is left over and double as a
mask for anything that spills outside the column.

## Scoring

Destroying enemies without a gap builds a **chain**; the multiplier climbs to
x6 and resets ~1.35s after you stop landing damage. Grazing bullets, collecting
stars and bombing bullets off the screen all add score. Extends at 2M / 5M / 10M.

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
```
