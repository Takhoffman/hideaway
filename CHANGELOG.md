# Changelog

All notable changes to Hideaway will be documented here. The project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Replaced manual app-bundle assembly with a universal, hardened-runtime Xcode archive signed with Developer ID.
- Moved Sparkle embedding and helper signing into the Xcode build system.

## [0.1.0] - 2026-07-13

### Added

- One-click stashing and exact restoration for desktop files, widgets, the Dock, and menu bar.
- Crash-resilient preference snapshots across app relaunches.
- Automatic signed updates with Sparkle and a manual update check.
- Universal macOS app packaging and automated GitHub releases.

[Unreleased]: https://github.com/Takhoffman/hideaway/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Takhoffman/hideaway/releases/tag/v0.1.0
