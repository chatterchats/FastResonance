# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
