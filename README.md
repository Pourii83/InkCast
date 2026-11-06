# InkCast

Quartz-style cast bars for **OctoWoW** (1.12.1 client, Interface 11200).

## Features

- **Player cast bar**: replaces the Blizzard bar. Shows the spell icon, name and timer, colors casts and channels differently, and flashes green on success and red on failure.
- **Latency**: a red area at the end of the bar shows your real lag. It is measured from the key press to the server's cast start, and falls back to `GetNetStats` when that isn't available.
- **Crafting jobs**: when you create several items at once, the bar shows the total time of the whole job and the item count, fills against the whole job, and a glow sweeps across the bar once per item.
- **Pushback**: shows the delay added by damage taken (`+0.5`) on casts and channels.
- **GCD bar**: a thin bar with a spark under the cast bar.
- **Swing timer**: main-hand melee plus ranged Auto Shot / wand Shoot (in a different color), adjusting when haste changes.
- **Target cast bar**: needs [SuperWoW](https://github.com/balakethelock/SuperWoW) (`UNIT_CASTEVENT`). Without it, this bar stays inactive.

## Install

Clone or extract this repository into `Interface\AddOns\InkCast`, so that `InkCast.toc` sits directly in that folder.

## Commands

`/inkcast` or `/ink`

| Command | Effect |
|---|---|
| `unlock` / `lock` | Move the bars with the mouse |
| `test` | Show a test cast on the player bar |
| `latency` | Toggle the latency display |
| `texture <name>` | Choose the bar texture and show a test cast: `smooth`, `gloss`, `minimal`, `banto`, `blizzard`, `flat` |
| `<bar> on` / `<bar> off` | Enable or disable a bar: `player`, `gcd`, `swing`, `target` |
| `<bar> width <n>` / `<bar> height <n>` | Resize a bar |
| `<bar> icon` | Toggle the spell icon |
| `reset` | Reset all settings and reload the UI |

## Limitations

- Without SuperWoW, the swing timer reads the combat log, so off-hand hits also reset it. "On next swing" abilities such as Heroic Strike don't reset it, and Auto Shot is only seen when the arrow lands, so the ranged timer starts slightly late.
- Casts that don't fire the normal cast event on the 1.12 client (such as Aimed Shot) only show with SuperWoW.
- The 1.12 client has no API for other units' casts, so the target bar only works with SuperWoW.
