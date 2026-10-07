# Fast Resonance

[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Fast%20Resonance-orange)](https://www.nexusmods.com/starwarszerocompany/mods/154)
[![UE4SS](https://img.shields.io/badge/framework-UE4SS-6f42c1)](https://github.com/UE4SS-RE/RE-UE4SS)

A focused [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for
**Star Wars: Zero Company** that shortens selected Coil Resonance presentation
sequences without globally accelerating combat.

Fast Resonance changes animation, camera, and delay timing only for the
supported abilities. It preserves their normal state-machine completion paths
and does not change their gameplay effects.

## Features

- Speeds up Resonance Transfer, Shared Suffering, and Unnatural Resilience
  body animations and camera choreography.
- Provides independent enable switches and speed multipliers for each ability.
- Uses a `4.0x` default, configurable from `0.25x` to `8.0x`.
- Supports live settings through
  [Mixamoo Mod Config Manager (MXM)](https://www.nexusmods.com/starwarszerocompany/mods/149).
- Runs with built-in defaults when MXM is not installed.
- Supports
  [ZCOM Mod Manager](https://github.com/arctco/zcom-mod-manager), Zero Company
  Mod Command, and manual UE4SS installation.
- Avoids broad animation, MovieScene, or Blueprint delay hooks.

## Supported abilities

### Resonance Transfer

The Resonance Transfer multiplier controls:

- Coil's transfer body animation;
- the captured pistol Captain resonance animation and rifle non-surge transfer
  reaction;
- the Resonance Transfer camera choreography; and
- the recipient Surge reaction animation.

The additional body targets are `A_1HPistol_Coil_Captain_Resonance` and
`A_2HRifle_Coil_PlagueTransfer_NonSurge`. Camera stages within the captured
`SM_Resonate` state machine use the same multiplier. Matching the ability
instance keeps generic camera assets unchanged when used by other abilities.

### Shared Suffering

The Shared Suffering multiplier controls:

- the Guardian body animation;
- the dedicated Shared Suffering camera choreography;
- the generic Confirm choreography only within the Shared Suffering context;
  and
- the exact two-second presentation hold at the end of the sequence.

At the default `4.0x` multiplier, the two-second hold is reduced to
approximately half a second.

### Unnatural Resilience

The Unnatural Resilience multiplier controls the captured Coil Brute body
animation, `A_2HRifle_Coil_Brute_Tenacity_Start`. It has its own enable switch
and defaults to `4.0x`. Camera stages within the captured `SM_Tenacity` state
machine use that same setting. Disabling the ability restores both body and
camera playback to `1.0x`.

## Requirements

- **Star Wars: Zero Company**
- A working [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html)
  installation for the game with the delayed game-thread action API
- Optional:
  [Mixamoo Mod Config Manager](https://www.nexusmods.com/starwarszerocompany/mods/149)
  for in-game configuration

The current package metadata identifies Steam as the supported launcher and
lists game builds `25134257` and `24874058` as tested. Later builds may work,
but should be treated as unverified until tested.

## Installation

Download the packaged release from
[Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/154). Do not
install a GitHub source-code archive unless you intend to package the
`src/Fast Resonance` directory yourself.

### ZCOM Mod Manager

1. Open the Install page in
   [ZCOM Mod Manager](https://github.com/arctco/zcom-mod-manager).
2. Select or drop the Fast Resonance release ZIP.
3. Confirm that Fast Resonance is enabled.

The release archive must retain `Fast Resonance` as the top-level mod folder.

### Manual UE4SS installation

1. Install and verify UE4SS for Star Wars: Zero Company.
2. Extract the `Fast Resonance` folder into:

   ```text
   SWZeroCompany/Binaries/Win64/ue4ss/Mods/
   ```

3. Confirm that the entry point exists at:

   ```text
   SWZeroCompany/Binaries/Win64/ue4ss/Mods/Fast Resonance/Scripts/main.lua
   ```

4. If your UE4SS setup does not enable the packaged mod automatically, add the
   following entry to `ue4ss/Mods/mods.txt`:

   ```text
   Fast Resonance : 1
   ```

See the official
[UE4SS Lua mod guide](https://docs.ue4ss.com/dev/guides/creating-a-lua-mod.html)
for loader configuration details.

## Configuration

MXM is optional. Without it, all three abilities are enabled at `4.0x`.

| Setting | Default | Range |
| --- | ---: | ---: |
| Enable Resonance Transfer | On | On / Off |
| Resonance Transfer multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| Enable Shared Suffering | On | On / Off |
| Shared Suffering multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| Enable Unnatural Resilience | On | On / Off |
| Unnatural Resilience multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |

With MXM installed, open **MOD SETTINGS** from the main menu or press `F2`.
Changes are detected at runtime and apply to the next matching presentation.
Set a multiplier to `1.0x` for vanilla timing.

## Troubleshooting

Use `fast_resonance.log` and `UE4SS.log` to check startup, mission readiness,
and applied animation and camera rates. When reporting a hitch, include your
speed settings and whether it happens on the first use, repeated uses, or both.

The release build does not include the temporary hitch profiler or its scheduled
probes. Leave the separate F8 animation probe idle when comparing performance;
use it only when capturing an animation that appears to be missing coverage.

## Design

Fast Resonance targets known assets and contexts rather than applying a global
speed change:

- montage rates are changed only when a supported embedded animation is active;
- camera sequence rates are changed only for registered Resonance targets;
- the shared Confirm sequence is gated to the Shared Suffering state-machine
  context; and
- the delay hook changes only the two-second Shared Suffering end hold, leaving
  unrelated delays untouched.

Startup publishes one game-thread setup action and then returns. It does not
scan resident montages or submit presentation retries on the loader thread.
Combat work begins only when a live `BRGameMissionActor` reports
`bIsMissionActorReady`, active mission status, and that it is not ending.
Mission lifecycle and construction events trigger bounded readiness checks;
the main menu does not run a permanent readiness poll.

Montage construction and matching choreography events trigger presentation
work within that mission. A one-time game-thread mission lookup also supports
reloading the mod during combat. Pending work is cancelled on mission ending,
actor EndPlay, map travel, and mission save reload. Animation instances and
sequence states must belong to the active mission's world.

Each mission activation seeds a humanoid animation-instance cache with one
global search. Construction notifications add later instances after their
construction callback unwinds. Playback walks this cache, removes invalid
instances, and rechecks current mission ownership. Presentation inspection
applies rates directly to its known owner instead of searching again. Each
montage readiness cycle queues only its next retry, preventing a backlog of
13 immediately runnable callbacks per montage after a stalled frame. Cache
contents are cleared on mission changes and runtime teardown.

Target names and settings mappings live in
[`src/Fast Resonance/Scripts/targets.lua`](src/Fast%20Resonance/Scripts/targets.lua).

## Repository layout

```text
.
├── .github/
│   └── workflows/
│       └── release-nexus.yml
├── CHANGELOG.md
├── README.md
├── scripts/
│   └── bump_version.py
└── src/
    └── Fast Resonance/
        ├── enabled.txt
        ├── modinfo.json
        ├── zcom-mod.json
        ├── MXM/
        │   └── settings.lua
        └── Scripts/
            ├── actions.lua
            ├── feature.lua
            ├── hook_registry.lua
            ├── logging.lua
            ├── main.lua
            ├── mission.lua
            ├── MXM.lua
            └── targets.lua
```

`src/Fast Resonance` is the distributable UE4SS mod directory. There is no
compile or bundle step.

## Development

1. Clone the repository:

   ```bash
   git clone https://github.com/chatterchats/FastResonance.git
   cd FastResonance
   ```

2. Copy or link `src/Fast Resonance` into the game's `ue4ss/Mods` directory.
3. Make changes to the Lua sources.
4. Run the runtime regression test:

   ```bash
   luajit tests/bootstrap_test.lua "src/Fast Resonance/Scripts"
   luajit tests/logging_test.lua "src/Fast Resonance/Scripts"
   luajit tests/runtime_test.lua "src/Fast Resonance/Scripts"
   python3 tests/nexus_changelog_test.py
   ```

5. Reload all mods from the UE4SS GUI console, or use the configured hot-reload
   shortcut.
6. Confirm that the UE4SS log contains a line beginning with:

   ```text
   [FastResonance] Loaded v
   ```

7. Exercise all three supported abilities in game and verify their body animation,
   camera sequence, reaction, and final delay behavior as applicable.

The runtime tests cover production bootstrap/reload wiring, action ownership,
group cancellation, hook-ID cleanup, generation guards, and persistent-dispatcher
reuse. The bootstrap harness rejects loader-side object discovery and hook
installation, and exercises delayed mission readiness, partial hook discovery,
save loads, map changes, mission teardown, world isolation, and reused players.
It also models exact class matching and separately loaded choreography functions,
including recovery after a class event and failed hook installation. It also
checks cached animation discovery, late-spawning characters, sequential retry
bounds, per-ability settings, and camera context isolation.
The mission model includes a streamed gameplay world whose level belongs to the
root world used by characters and cinematics, and rejects unavailable, cyclic,
or unrelated world ownership.

For the startup fix, repeat cold launches on the affected UE4SS/Wine setup,
then verify new missions, loading a combat save, mod reload during combat,
mission restart/exit, and all three supported abilities (including repeated uses
after changing settings). Check `fast_resonance.log` for mission transitions and
readiness timeouts. The mocked scheduler cannot reproduce or prove elimination
of UE4SS's native concurrency race; in-game verification remains required.

After mission activation, look for `Choreography hooks ready | 3/3`, then
`LIVE RATE APPLIED` and `CAMERA RATE APPLIED` when using a supported ability.
A `Loaded` or mission-active entry alone does not confirm that acceleration is
working. If discovery times out, its log entry names the missing functions.

In-game validation on September 16, 2026 confirmed Resonance Transfer body and
camera playback at 3x, and Shared Suffering body, camera, and confirmation
playback at 4x, with its final delay reduced from 2 seconds to 0.5 seconds.
Testing for v1.0.5 confirmed all added body animations were accelerated and no
visible freezes were reported with the animation cache in place. Unnatural
Resilience's camera was also confirmed at 4x in the log and visually in game.
The Captain/non-surge camera path has automated coverage; its visual behavior
has not yet been explicitly confirmed. The final build removes only temporary
profiling from the tested playback paths and still needs a release smoke test.
The intermittent startup crash still needs confirmation from the affected user.

## Releasing

The manual **Release to Nexus Mods** workflow packages and publishes the mod.
Before running it:

1. Record the release notes under `## [Unreleased]` in
   [`CHANGELOG.md`](CHANGELOG.md).
2. Run the version bump script with `patch`, `minor`, or `major`:

   ```bash
   ./scripts/bump_version.py patch
   ```

   The argument is case-insensitive. The script validates and updates all four
   version declarations, promotes the Unreleased notes to the new version
   section, and leaves an empty Unreleased section.
3. Verify the package through ZCOM Mod Manager and a clean manual UE4SS
   installation.
4. Confirm all three abilities with MXM installed and with MXM absent.
5. Configure the `NEXUSMODS_API_KEY` repository secret with an API key permitted
   to update the mod. The workflow resolves the Nexus mod and file IDs itself
   and requires exactly one active file.

Run the workflow manually from the repository's **Actions** tab. It:

- requires `modinfo.json` and `zcom-mod.json` to contain the same `#.#.#`
  version;
- reads the matching release notes from `CHANGELOG.md`;
- packages `src/Fast Resonance` as `Fast Resonance V#.#.#.zip`; and
- uploads the archive to Nexus Mods as `Fast Resonance v#.#.#.zip`.

Do not include repository-only files inside the `Fast Resonance` mod directory.

## Contributing

Bug reports and focused pull requests are welcome through
[GitHub Issues](https://github.com/chatterchats/FastResonance/issues) and
[GitHub Pull Requests](https://github.com/chatterchats/FastResonance/pulls).

When reporting a bug, include:

- the game build ID;
- the UE4SS version;
- whether MXM and ZCOM Mod Manager are installed;
- the configured ability settings;
- reproduction steps; and
- the relevant `fast_resonance.log` and UE4SS log excerpt or crash dump.

`fast_resonance.log` is written beside the installed mod. Its entries include
UTC timestamps and runtime generations so activity from a hot-reloaded instance
can be separated from callbacks belonging to an earlier session.

Keep changes narrowly scoped. Any new timing target must be gated to its owning
ability context; global animation or delay acceleration is out of scope.

## Releases and support

- Downloads: [Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/154)
- Changes: [`CHANGELOG.md`](CHANGELOG.md)
- Bugs and feature requests:
  [GitHub Issues](https://github.com/chatterchats/FastResonance/issues)

## License

This repository does not currently include a license. Unless a license is
added, the source remains subject to applicable copyright law.
