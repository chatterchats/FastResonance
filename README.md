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

- Speeds up Resonance Transfer and Shared Suffering presentations.
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
- the Resonance Transfer camera choreography; and
- the recipient Surge reaction animation.

### Shared Suffering

The Shared Suffering multiplier controls:

- the Guardian body animation;
- the dedicated Shared Suffering camera choreography;
- the generic Confirm choreography only within the Shared Suffering context;
  and
- the exact two-second presentation hold at the end of the sequence.

At the default `4.0x` multiplier, the two-second hold is reduced to
approximately half a second.

## Requirements

- **Star Wars: Zero Company**
- A working [UE4SS](https://docs.ue4ss.com/dev/installation-guide.html)
  installation for the game
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

MXM is optional. Without it, both abilities are enabled at `4.0x`.

| Setting | Default | Range |
| --- | ---: | ---: |
| Enable Resonance Transfer | On | On / Off |
| Resonance Transfer multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| Enable Shared Suffering | On | On / Off |
| Shared Suffering multiplier | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |

With MXM installed, open **MOD SETTINGS** from the main menu or press `F2`.
Changes are detected at runtime and apply to the next matching presentation.
Set a multiplier to `1.0x` for vanilla timing.

## Design

Fast Resonance targets known assets and contexts rather than applying a global
speed change:

- montage rates are changed only when a supported embedded animation is active;
- camera sequence rates are changed only for registered Resonance targets;
- the shared Confirm sequence is gated to the Shared Suffering state-machine
  context; and
- the delay hook changes only the two-second Shared Suffering end hold, leaving
  unrelated delays untouched.

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
└── src/
    └── Fast Resonance/
        ├── enabled.txt
        ├── modinfo.json
        ├── zcom-mod.json
        ├── MXM/
        │   └── settings.lua
        └── Scripts/
            ├── main.lua
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
4. Reload all mods from the UE4SS GUI console, or use the configured hot-reload
   shortcut.
5. Confirm that the UE4SS log contains a line beginning with:

   ```text
   [FastResonance] Loaded v
   ```

6. Exercise both supported abilities in game and verify their body animation,
   camera sequence, reaction, and final delay behavior as applicable.

This repository has no automated test suite. In-game verification against a
supported build is required for behavior changes.

## Releasing

The manual **Release to Nexus Mods** workflow packages and publishes the mod.
Before running it:

1. Keep the version synchronized in `src/Fast Resonance/Scripts/main.lua`,
   `src/Fast Resonance/MXM/settings.lua`, `src/Fast Resonance/modinfo.json`, and
   `src/Fast Resonance/zcom-mod.json`.
2. Add a matching, non-empty version section to
   [`CHANGELOG.md`](CHANGELOG.md).
3. Verify the package through ZCOM Mod Manager and a clean manual UE4SS
   installation.
4. Confirm both abilities with MXM installed and with MXM absent.
5. Configure these repository secrets:
   - `NEXUSMODS_API_KEY`: an API key permitted to update the mod.
   - `NEXUSMODS_FILE_ID`: the Nexus Mods file ID to update, not the mod ID
     (`154`).

Run the workflow manually from the repository's **Actions** tab. It:

- requires `modinfo.json` and `zcom-mod.json` to contain the same `#.#.#`
  version;
- reads the matching release notes from `CHANGELOG.md`;
- packages `src/Fast Resonance` as `Fast Resonance V#.#.#.zip`; and
- uploads the archive to Nexus Mods as `Fast Resonance.zip`.

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
- the relevant UE4SS log excerpt or crash dump.

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
