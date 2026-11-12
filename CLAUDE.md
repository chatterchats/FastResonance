# FastResonance

@docs/agent-rules.md

Read README.md first: what the mod speeds up, its layout and how it's tested.

## Rules for this repo

- Change presentation only: sequence play rates and node-template timings. Never touch gameplay
  effects, ability logic or the global time dilation.
- Always reset a sequence player's rate to 1.0 when its state ends; sequence actors are reused.
- Keep the vanilla template values and recompute from them on every settings change.
- A new ability goes in the `ABILITIES` table and gets a switch in `MXM/settings.lua`; find its
  state machine with `dev/ResonanceProbe`.
- Nothing per frame: the only per-cast work is the sequence hook.
