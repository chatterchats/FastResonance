# Fast Resonance

[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Fast%20Resonance-d98f40)](https://www.nexusmods.com/starwarszerocompany/mods/154)
[![UE4SS](https://img.shields.io/badge/framework-UE4SS-6f42c1)](https://github.com/UE4SS-RE/RE-UE4SS)

Fast Resonance is a UE4SS Lua mod for **Star Wars: Zero Company** that
shortens selected Coil Resonance presentation sequences without speeding up
combat as a whole.

It changes animation, camera and delay timing only for the supported
abilities, keeps their normal state-machine completion paths, and does not
change their gameplay effects.

## Features

- Speeds up the body animations and camera choreography of Resonance
  Transfer, Shared Suffering and Unnatural Resilience.
- A separate on/off switch and speed multiplier for each ability.
- `4.0x` by default, configurable from `0.25x` to `8.0x`.
- Live settings through
  [Mixamoo Mod Config Manager (MXM)](https://www.nexusmods.com/starwarszerocompany/mods/149);
  built-in defaults when MXM isn't installed.
- No broad animation, MovieScene or Blueprint delay hooks.

## Supported abilities

### Resonance Transfer

The Resonance Transfer multiplier controls:

- Coil's transfer body animation;
- the captured pistol Captain resonance animation and rifle non-surge transfer
  reaction (`A_1HPistol_Coil_Captain_Resonance`,
  `A_2HRifle_Coil_PlagueTransfer_NonSurge`);
- the Resonance Transfer camera choreography (camera stages within the
  captured `SM_Resonate` state machine); and
- the recipient's Surge reaction animation.

Matching the ability instance leaves generic camera assets unchanged when
other abilities use them.

### Shared Suffering

The Shared Suffering multiplier controls:

- the Guardian body animation;
- the dedicated Shared Suffering camera choreography;
- the generic Confirm choreography, only within the Shared Suffering context;
  and
- the two-second presentation hold at the end of the sequence (about half a
  second at the default `4.0x`).

### Unnatural Resilience

The Unnatural Resilience multiplier controls Coil Brute's body animation
(`A_2HRifle_Coil_Brute_Tenacity_Start`) and the camera stages within the
captured `SM_Tenacity` state machine. Disabling the ability restores both to
`1.0x`.

## Configuration

Without MXM, all three abilities are enabled at `4.0x`.

| Setting | Default | Range |
| --- | ---: | ---: |
| Enable Resonance Transfer | On | On / Off |
| Resonance Transfer multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| Enable Shared Suffering | On | On / Off |
| Shared Suffering multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| Enable Unnatural Resilience | On | On / Off |
| Unnatural Resilience multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |

With MXM installed, open **MOD SETTINGS** from the main menu or press `F2`.
Changes apply to the next matching presentation. Set a multiplier to `1.0x`
for vanilla timing.

## Requirements

- **Star Wars: Zero Company**
- **UE4SS** for Zero Company, with the delayed game-thread action API
- Optional: [Mixamoo Mod Config Manager](https://www.nexusmods.com/starwarszerocompany/mods/149)
  for in-game settings

| Steam build | Status |
| --- | --- |
| [25134257](https://steamdb.info/app/2075800/patchnotes/) | Tested |
| 24874058 | Tested |

Steam is the tested launcher. Later builds may work but are unverified until
tested.

## Installation

Download the release ZIP from
[Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/154), not
GitHub's source-code archive (unless you package `src/Fast Resonance`
yourself). The ZIP keeps `Fast Resonance` as its top-level folder and
includes metadata for both mod managers below.

### With a mod manager

- **[Zero Mod Manager](https://github.com/stellamarislabs/zero-mod-manager)**
  (formerly ZCOM Mod Manager): open **Install**, drop in the ZIP, then
  confirm Fast Resonance is enabled under **Mods**.
- **[Zero Company Mod Command](https://github.com/EnvianMods/ZeroCompanyModCommand)**:
  drag the ZIP into the **Hangar Bay** and check that it's enabled.

### By hand

1. Install UE4SS for Star Wars: Zero Company.
2. Extract the `Fast Resonance` folder into
   `SWZeroCompany/Binaries/Win64/ue4ss/Mods/`.
3. Check that `ue4ss/Mods/Fast Resonance/Scripts/main.lua` exists.
4. If your UE4SS setup ignores the packaged `enabled.txt`, add
   `Fast Resonance : 1` to `ue4ss/Mods/mods.txt`.

See the [UE4SS Lua mod guide](https://docs.ue4ss.com/dev/guides/creating-a-lua-mod.html)
for loader configuration details.

### Updating and uninstalling

Close the game, then install the new ZIP the same way (by hand, copy it over
the old folder). To uninstall, disable or remove it in your mod manager, or
delete the `Fast Resonance` folder; timings return to vanilla.

## Troubleshooting

`fast_resonance.log` (beside the installed mod) and `UE4SS.log` show startup,
mission readiness, and the animation and camera rates applied. Its entries
carry UTC timestamps and runtime generations, so a hot-reloaded instance can
be told apart from an earlier one.

After a mission starts, look for `Choreography hooks ready | 3/3`, then
`LIVE RATE APPLIED` and `CAMERA RATE APPLIED` when using a supported ability.
A `Loaded` or mission-active line alone doesn't confirm acceleration. If
discovery times out, its log line names the missing functions.

The release build has no hitch profiler. Leave the separate F8 animation
probe idle when comparing performance; use it only to capture an animation
that seems to be missing coverage.

### Reporting a bug

Open an [issue](https://github.com/chatterchats/FastResonance/issues) with:

- the game build and UE4SS version;
- whether MXM and a mod manager are installed;
- your ability settings;
- the steps to reproduce it, and for a hitch, whether it happens on the first
  use, repeated uses or both; and
- `fast_resonance.log` and the `UE4SS.log` excerpt or crash dump.

## How it works

Fast Resonance targets known assets and contexts instead of applying a global
speed change:

- montage rates change only while a supported embedded animation is active;
- camera sequence rates change only for registered Resonance targets;
- the shared Confirm sequence is gated to the Shared Suffering state-machine
  context; and
- the delay hook changes only Shared Suffering's two-second end hold.

Startup publishes one game-thread setup action and returns; it neither scans
resident montages nor retries presentations on the loader thread. Combat work
begins only when a live `BRGameMissionActor` reports `bIsMissionActorReady`,
an active mission and that it isn't ending. Mission lifecycle and construction
events trigger bounded readiness checks; the main menu runs no permanent
readiness poll.

Montage construction and matching choreography events trigger presentation
work within that mission, and a one-time game-thread mission lookup supports
reloading the mod mid-combat. Pending work is cancelled on mission end, actor
EndPlay, map travel and mission save reload. Animation instances and sequence
states must belong to the active mission's world.

Each mission activation seeds a humanoid animation-instance cache with one
global search; construction notifications add later instances once their
callbacks unwind. Playback walks the cache, drops invalid instances and
rechecks mission ownership, and presentation inspection applies rates
directly to the known owner. Each montage readiness cycle queues only its next
retry, so a stalled frame can't build a backlog of 13 runnable callbacks per
montage. The cache is cleared on mission changes and teardown.

Target names and settings mappings live in
[`src/Fast Resonance/Scripts/targets.lua`](src/Fast%20Resonance/Scripts/targets.lua).

## Repository layout

```text
.
├── .github/workflows/release-nexus.yml   # manual Nexus release
├── CHANGELOG.md
├── README.md
├── docs/nexus/description.bbcode         # mod page description
├── scripts/
│   ├── bump_version.py                   # version bump + changelog promotion
│   └── nexus_changelog.py                # a release's notes as Nexus text
├── src/Fast Resonance/                   # the distributable mod folder
│   ├── MXM/settings.lua                  # MXM settings page
│   ├── Scripts/                          # main.lua, feature, mission, targets, MXM
│   ├── enabled.txt
│   ├── modinfo.json                      # Zero Company Mod Command
│   └── zcom-mod.json                     # Zero Mod Manager
└── tests/                                # LuaJIT and Python tests
```

`src/Fast Resonance` is the distributable folder; there is no compile or
bundle step. Keep repository-only files out of it.

## Development

1. Clone the repository and copy or link `src/Fast Resonance` into the game's
   `ue4ss/Mods` folder.
2. Run the tests from the repository root:

   ```bash
   for t in tests/*_test.lua; do luajit "$t" "src/Fast Resonance/Scripts" || break; done
   for t in tests/*_test.py; do python3 "$t" || break; done
   ```

3. Reload all mods from the UE4SS GUI console (or the hot-reload shortcut)
   and check that `UE4SS.log` has a line starting with
   `[FastResonance] Loaded v`.
4. Exercise all three abilities in game and check their body animation,
   camera sequence, reaction and final delay as applicable.

The tests cover bootstrap and reload wiring, action ownership, group
cancellation, hook-ID cleanup, generation guards and dispatcher reuse. The
bootstrap harness rejects loader-side object discovery and hook installation,
and exercises delayed mission readiness, partial hook discovery, save loads,
map changes, mission teardown, world isolation, reused players, exact class
matching, separately loaded choreography functions, recovery after failed
hook installation, cached animation discovery, late-spawning characters,
retry bounds, per-ability settings and camera context isolation. The mission
model includes a streamed gameplay world whose level belongs to the root
world, and rejects unavailable, cyclic or unrelated world ownership.

The mocked scheduler can't reproduce UE4SS's native concurrency race, so
startup changes still need repeated cold launches on the affected
UE4SS/Wine setup, then new missions, loading a combat save, reloading the
mod mid-combat, mission restart and exit, and all three abilities (including
repeated uses after changing settings).

### Verification status

- September 16, 2026: Resonance Transfer body and camera confirmed at 3x;
  Shared Suffering body, camera and confirmation at 4x, with the final delay
  cut from 2 seconds to 0.5.
- v1.0.5: all added body animations accelerated, with no visible freezes
  with the animation cache in place; Unnatural Resilience's camera confirmed
  at 4x in the log and in game.
- The Captain/non-surge camera path has automated coverage but no explicit
  visual confirmation yet. The final build removes only temporary profiling
  from the tested paths and still needs a release smoke test. The
  intermittent startup crash still needs confirmation from the affected user.

## Releasing

The manually run **Release to Nexus Mods** workflow publishes a release; build
a local ZIP for package-only checks.

1. Add release notes under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md).
2. Bump the version with `patch`, `minor` or `major` (case-insensitive):

   ```bash
   ./scripts/bump_version.py patch
   ```

   It checks and updates all four version declarations, promotes the
   Unreleased notes to the new version and leaves an empty Unreleased
   section.
3. Run the tests, check the package with a mod manager and a clean manual
   install, and confirm all three abilities with and without MXM.
4. Run **Release to Nexus Mods** from the **Actions** tab. It needs the
   `NEXUSMODS_API_KEY` repository secret, with a key allowed to update the
   mod.

The workflow:

- requires `modinfo.json` and `zcom-mod.json` to hold the same `#.#.#`
  version;
- reads that version's notes from `CHANGELOG.md`;
- packages `src/Fast Resonance` as `Fast Resonance V#.#.#.zip`; and
- uploads it to Nexus as `Fast Resonance v#.#.#.zip`, finding the mod and its
  single active file through the API (exactly one active file is required).

## Contributing

Bug reports and focused pull requests are welcome through
[Issues](https://github.com/chatterchats/FastResonance/issues) and
[Pull Requests](https://github.com/chatterchats/FastResonance/pulls).

Keep changes narrowly scoped: any new timing target must be gated to its
owning ability's context. Global animation or delay acceleration is out of
scope.

## Support

- Downloads: [Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/154)
- Changes: [`CHANGELOG.md`](CHANGELOG.md)
- Bugs and requests: [GitHub Issues](https://github.com/chatterchats/FastResonance/issues)

## License

This repository does not currently include a license. Unless one is added,
the source remains subject to applicable copyright law.
