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
Players should download the release ZIP from
[Nexus Mods](https://www.nexusmods.com/starwarszerocompany/mods/154) or the
[GitHub releases](https://github.com/chatterchats/FastResonance/releases); the
mod page text, with install steps and the ability list, is in
[`docs/nexus/`](docs/nexus/).

## Commands

`make help` lists everything. The usual loop: edit, `make test`, `make install`, restart the game.

| Target | Does |
| --- | --- |
| `make test` | the mocked-UE4SS test of `main.lua`, no game needed |
| `make install` / `make uninstall` | link `src/Fast Resonance` into the main install, or remove the link |
| `make package` | `dist/FastResonance-X.Y.Z.zip`, with `Fast Resonance/` at its root |
| `make bump V=X.Y.Z` | set the version everywhere, date the changelog |
| `make release` | check, test, tag, push; CI publishes to GitHub and Nexus (mod 154) |
| `make check` / `make sync` | drift from the standard / fetch the latest shared files |

## Layout

The standard layout (see `../ModTemplate/STANDARD.md`). Specific to this repo:

- `src/Fast Resonance/Scripts/main.lua` is the whole runtime; `Scripts/MXM.lua` is the unmodified
  MXM client and `MXM/settings.lua` the settings page (speed plus one switch per ability).
- `tests/main_test.lua` loads `main.lua` with UE4SS and MXM stubbed out.
- `dev/ResonanceProbe/` is the development probe the rewrite was built from (never shipped).
  Link it into `ue4ss/Mods` by hand and run it with Fast Resonance disabled so rates are
  vanilla: it logs, with the `[ResonanceProbe]` prefix, every state inside a Coil ability's
  state machine, each node class's numeric settings, the sequences played and the animations
  they drive, and every new state machine the game creates (to find abilities not covered
  yet). It's slow and noisy; don't leave it enabled.

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

## Testing in game

Restart the game after `make install` (no UE4SS hot reload), then fight Coil units and check each
changed ability's camera, body animation and holds. Everything goes to `UE4SS.log` with the `[FastResonance]` prefix:

- `v… loaded | x4` at startup, then `Hooked …` lines once the cinematic
  Blueprints load;
- `Node timings set | <n> values | x4` when the abilities' state machines load
  with a mission (and again after a settings change);
- `<state machine> | x4 | <sequence>` each time a supported sequence is sped
  up, for example `SM_Resonate | x4 | …`.

An ability that plays at normal speed with no such line is either switched off
or not covered yet: find its state machine with the probe and add it to `ABILITIES`.

## Verification status

- September 16, 2026: Resonance Transfer body and camera confirmed at 3x;
  Shared Suffering body, camera and confirmation at 4x, with the final delay
  cut from 2 seconds to 0.5 (the earlier design).
- October 12, 2026 (single-script rewrite): played through several story and
  side missions against the Coil, including the chapter 6 finale, at 4x with
  no problems seen (`SM_ReactionCloak`, added to Cloak that morning, wasn't
  in the tested copy). Not every ability has been confirmed individually.

## License

[MIT](LICENSE), copyright 2026 Chatter Chats.
