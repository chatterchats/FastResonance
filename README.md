# Fast Resonance

[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-Fast%20Resonance-d98f40)](https://www.nexusmods.com/starwarszerocompany/mods/154)
[![UE4SS](https://img.shields.io/badge/framework-UE4SS-6f42c1)](https://github.com/UE4SS-RE/RE-UE4SS)
[![License: MIT](https://img.shields.io/badge/license-MIT-2f7d4f)](LICENSE)

Fast Resonance is a UE4SS Lua mod for **Star Wars: Zero Company** that
shortens the Coil's ability presentations without speeding up combat as a
whole.

It changes only the play rate of each supported ability's cinematic sequences
and the fixed holds and effect timings inside its state machine. The abilities
complete through their normal paths and their gameplay effects are unchanged.

## Features

- Speeds up the camera and body animation of every Coil ability presentation
  together, plus their fixed holds and effect timings.
- One Speed setting, `4.0x` by default, configurable from `0.25x` to `8.0x`.
- An on/off switch for each ability.
- Live settings through
  [Mixamoo Mod Config Manager (MXM)](https://www.nexusmods.com/starwarszerocompany/mods/149);
  built-in defaults when MXM isn't installed.
- No broad animation, MovieScene or Blueprint delay hooks: anything outside the
  supported abilities' state machines plays at normal speed.

## Supported abilities

| Switch | Covers (state machines) |
| --- | --- |
| Resonance Transfer | Resonate and plague transfer, including the bridge's build and travel (`SM_Resonate`, `SM_PlagueBroadcaster`, `SM_AbilityPresentation_PlagueBroadcast`) |
| Shared Suffering | The Guardian's link, its Confirm shot and end hold, and the damage redirect (`SM_SharedSuffering`, `SM_SharedSuffering_Redirect`) |
| Unnatural Resilience | The Brute's opening hold, body animation and camera (`SM_Tenacity`) |
| Tenacity Heal | `SM_TenacityHeal` |
| Miasma | `SM_Miasma` |
| Plague Surge | Surging and plague stack gain (`SM_PlagueSurge`, `SM_Passive_PlagueStackGain`) |
| Scream | `SM_Scream` |
| Devour | `SM_Devour` |
| Bind | `SM_Bind`, `SM_Bind_AttackerRelease` |
| Cloak | Cloak, reaction cloak and decloak (`SM_Cloak`, `SM_Cloak_Tutorial`, `SM_ReactionCloak`, `SM_Decloak_OnCondition`) |
| Death Explosion | `SM_Coil_DeathExplosion` |
| Life Beyond Death | `SM_LifeBeyondDeath` |
| Melee Strike | `SM_MeleeStrike` |

## Configuration

Without MXM, every ability is enabled at `4.0x`.

| Setting | Default | Range |
| --- | ---: | ---: |
| Speed | `4.0x` | `0.25x`–`8.0x` in `0.25x` steps |
| One switch per ability (above) | On | On / Off |

With MXM installed, open **MOD SETTINGS** from the main menu or press `F2`.
Sequence speed applies to the next presentation; holds and effect timings are
updated as soon as the setting changes. Set Speed to `1.0x`, or switch an
ability off, for vanilla timing.

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

Everything goes to `UE4SS.log` with the `[FastResonance]` prefix:

- `v… loaded | x4` at startup, then `Hooked …` lines once the cinematic
  Blueprints load;
- `Node timings set | <n> values | x4` when the abilities' state machines load
  with a mission (and again after a settings change);
- `<state machine> | x4 | <sequence>` each time a supported sequence is sped
  up, for example `SM_Resonate | x4 | …`.

An ability that plays at normal speed with no such line is either switched off
or not covered yet; please report it with the log.

### Reporting a bug

Open an [issue](https://github.com/chatterchats/FastResonance/issues) with:

- the game build and UE4SS version;
- whether MXM and a mod manager are installed;
- your ability settings;
- the steps to reproduce it, and for a hitch, whether it happens on the first
  use, repeated uses or both; and
- `UE4SS.log`, or the crash dump.

## How it works

The whole runtime is
[`src/Fast Resonance/Scripts/main.lua`](src/Fast%20Resonance/Scripts/main.lua).
Each Coil ability runs a cinematic state machine (`SM_*`). Inside the enabled
ones:

- **Sequences play faster.** The camera and the body animation are both in the
  ability's sequence, so setting the sequence player's rate covers both. Hooks
  on the two sequence state classes (`SMstate_PlayChoreographedSequence`,
  `SMState_PlaySequence`) find the owning state machine from the state's path
  and set the rate; it's reset to `1.0` when the state ends, because sequence
  actors can be reused.
- **Holds and effect timings are shortened on node templates.** Fixed delays
  (`SMstate_SimpleDelay`) and the plague bridge and Shared Suffering hit
  timings are divided (or their speeds multiplied) on each state machine's
  `TEMPLATE_` nodes, which the game copies for every cast. The original values
  are kept, so a settings change recomputes from vanilla.

Ability classes load with missions; when one loads, its templates are set once
the burst of loading has settled. Nothing runs per frame or per cast beyond the
sequence hook. The table of abilities and the state machines each switch covers
is at the top of `main.lua`.

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
│   ├── Scripts/                          # main.lua (the runtime) and MXM.lua
│   ├── enabled.txt
│   ├── modinfo.json                      # Zero Company Mod Command
│   └── zcom-mod.json                     # Zero Mod Manager
└── tests/nexus_changelog_test.py         # release-notes formatter test
```

`src/Fast Resonance` is the distributable folder; there is no compile or
bundle step. Keep repository-only files out of it.

## Development

1. Clone the repository and copy or link `src/Fast Resonance` into the game's
   `ue4ss/Mods` folder.
2. Run the test from the repository root:

   ```bash
   python3 tests/nexus_changelog_test.py
   ```

3. Restart the game after changes (the script doesn't support UE4SS hot
   reload), check that `UE4SS.log` has `[FastResonance] v… loaded`, then fight
   Coil units and check each changed ability's camera, body animation and
   holds.

### Verification status

- September 16, 2026: Resonance Transfer body and camera confirmed at 3x;
  Shared Suffering body, camera and confirmation at 4x, with the final delay
  cut from 2 seconds to 0.5 (the earlier design).
- October 12, 2026 (single-script rewrite): played through several story and
  side missions against the Coil, including the chapter 6 finale, at 4x with
  no problems seen (`SM_ReactionCloak`, added to Cloak that morning, wasn't
  in the tested copy). Not every ability has been confirmed individually.

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
3. Run the test, check the package with a mod manager and a clean manual
   install, and confirm the abilities with and without MXM.
4. Run **Release to Nexus Mods** from the **Actions** tab. It needs the
   `NEXUSMODS_API_KEY` repository secret, with a key allowed to update the
   mod.

The workflow:

- requires `modinfo.json` and `zcom-mod.json` to hold the same `#.#.#`
  version;
- reads that version's notes from `CHANGELOG.md`;
- packages `src/Fast Resonance`, with `LICENSE` added, as `Fast Resonance V#.#.#.zip`;
  and
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

[MIT](LICENSE) © 2026 Chatter Chats. The release ZIP includes the license.
