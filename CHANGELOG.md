# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Format release notes as single-line, category-prefixed plain-text entries when
  publishing to Nexus Mods, while retaining the readable Keep a Changelog source.

## [1.0.5]

### Fixed

- Reduce the hitch before Resonance animations by caching animation instances
  per mission instead of repeatedly searching all game objects during playback.
- Apply animation speed directly to the known character and queue readiness
  retries one at a time, reducing work that can accumulate in a stalled frame.

### Added

- Speed up the Captain's resonance animation and the non-surge recipient
  reaction, including camera choreography, with the Resonance Transfer settings.
- Speed up Unnatural Resilience's body animation and camera choreography, with
  its own enable switch and multiplier in MXM (4x by default).

### Changed

- Remove temporary hitch profiling, timing reports, and scheduler probes from
  the release build. Keep normal playback, lifecycle, and error logging.

## [1.0.4]

### Fixed

- Address the suspected initialization race behind #2 by handing setup to the
  game thread once, instead of submitting immediately runnable montage retries from the
  loader while it is still initializing the mod.
- Gate combat work on the mission actor's readiness and active status. Cancel
  session work on mission ending, actor EndPlay, map travel, and save reload.
- Recover an existing mission after mod reload without scanning resident
  montages, and retry incomplete choreography hook discovery after relevant
  mission or class events.
- Refresh reused montage rates from presentation events so subsequent uses
  respect changed settings, including restoring vanilla timing when disabled.
- Resolve choreography functions by their exact asset paths. The previous
  `FindObject("Class", ...)` lookup excludes the game's generated state-machine
  class and leaves preloaded choreography unhooked after mission activation.
- Log completion of all three choreography hooks and identify missing functions
  when bounded discovery expires.
- Compare level owning worlds when filtering mission playback. The mission actor
  can report a streamed `_Gameplay` world while characters and cinematics report
  `_Root`; comparing those raw pointers incorrectly rejected both animation and
  camera acceleration. Resolve `PersistentLevel.OwningWorld` before comparison.

Both abilities' playback acceleration was verified in-game, including Shared
Suffering's confirmation sequence and final delay. The intermittent startup
crash still requires confirmation on the affected user's Wine/Proton setup;
automated coverage models lifecycle and scheduling boundaries rather than
UE4SS's native thread race.

## [1.0.3]

### Added

- A manual GitHub Actions workflow for packaging releases and uploading them to
  Nexus Mods.
- Owned UE4SS delayed-action handles and cancellable retry groups for montage
  and choreography readiness work.
- A central runtime registry that retains both hook IDs, unregisters hooks,
  cancels pending actions, and guards persistent callbacks across hot reloads.
- A dedicated `fast_resonance.log` beside the installed mod with UTC timestamps,
  runtime generations, and explicit runtime/hook lifecycle transitions.

### Changed

- Cancel superseded retry groups immediately and cancel their remaining work as
  soon as the matching montage or camera rate has been applied.
- Reuse one live dispatcher for montage discovery and MXM settings changes
  across same-state reloads.
- Retire the broad choreography-class construction observer after one match and
  defer function discovery until its construction callback has unwound.

## [1.0.2]

### Added

- Support for Zero Company Mod Command.

## [1.0.1]

### Fixed

- A potential crash caused by incorrect UE4SS object handling.

## [1.0.0]

### Added

- Initial release.
- Faster Resonance Transfer sequences.
- Faster Shared Suffering sequences.
- Adjustable speed multipliers for both abilities.
- Optional MXM Config Manager support.
- ZCOM Mod Manager-compatible packaging.
