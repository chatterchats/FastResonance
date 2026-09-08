# Fast Resonance 1.0.0

A UE4SS Lua mod for **Star Wars Zero Company** that shortens selected Coil
Resonance presentation sequences without globally accelerating combat.

## Supported abilities

### Resonance Transfer
Default: **enabled, 4.0x**

The one multiplier controls all known presentation layers:

- Coil transfer body animation
- Resonance transfer camera choreography
- Recipient Surge facial/reaction animation

### Shared Suffering
Default: **enabled, 4.0x**

The one multiplier controls:

- Guardian Shared Suffering body animation
- Dedicated Shared Suffering camera choreography
- The generic Confirm choreography only while it is nested under
  `SM_SharedSuffering_C`
- The exact 2.0-second Shared Suffering end hold

At 4.0x, the 2.0-second end hold becomes 0.5 seconds.

## Configuration

Fast Resonance supports **Mixamoo Mod Config Manager (MXM)**.

MXM is optional. Without it, Fast Resonance uses the defaults above.

The in-game settings are intentionally simple:

- Resonance Transfer
  - Enable Resonance Transfer
  - Multiplier
- Shared Suffering
  - Enable Shared Suffering
  - Multiplier

## ZCOM Mod Manager

This package includes `zcom-mod.json` schema version 1 and is laid out as a
single UE4SS mod folder:

```text
Fast Resonance/
├── zcom-mod.json
├── enabled.txt
├── README.md
├── MXM/
│   └── settings.lua
└── Scripts/
    ├── main.lua
    ├── MXM.lua
    └── targets.lua
```

Drop the ZIP directly into ZCOM Mod Manager's Install page.

## Manual install

Copy the `Fast Resonance` folder into:

```text
SWZeroCompany/Binaries/Win64/ue4ss/Mods/
```

A compatible UE4SS runtime for Zero Company is required.

## Design

Fast Resonance avoids broad timing hooks.

It does not globally accelerate animations, MovieScene players, or Blueprint
delays. Shared/common assets are only altered when they are running in the
specific Resonance ability context that owns them.
