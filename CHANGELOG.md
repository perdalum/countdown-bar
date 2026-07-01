# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Third countdown display mode for percent remaining in the menu bar and dropdown.
- Configurable `startDate` for countdowns so percent remaining uses a user-defined interval.

### Changed

- Replaced the old `includeTime` toggle with a three-mode display selector.
- Added start-date editing to the add/edit countdown dialog.
- Added validation so the start date cannot be after the target date.
- Date-only modes now normalize stored dates to noon.
- Existing JSON configs using `includeTime` are migrated on load.

## [1.0.1] - 2026-06-13

### Added

- MIT License for publishing and reuse.

### Changed

- Bumped app bundle version metadata to 1.0.1.

## [1.0.0] - 2026-06-13

### Added

- Native macOS menu bar countdown application.
- Menu bar display for one selected countdown.
- Dropdown menu listing all saved countdowns.
- Add, edit, delete, and copy countdown actions.
- Standard macOS date picker in the add/edit dialog.
- Per-countdown option to include time or count whole days only.
- JSON persistence at `~/Library/Application Support/CountdownBar/countdowns.json`.
- Script to build a `.app` bundle at `.build/CountdownBar.app`.
- Project README with development, build, and JSON configuration instructions.
