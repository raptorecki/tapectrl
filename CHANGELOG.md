# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2025-09-09

### Changed
- Updated "Restore From Tape" command to include `mbuffer` for buffered reading, improving performance and stability.
- Modified the restore UI to display `mbuffer` status and `tar` file list concurrently, providing better real-time feedback.

### Fixed
- Improved error handling for the restore pipeline to check the individual exit codes of `dd`, `mbuffer`, and `tar`.

## [1.0.1] - 2025-09-09

### Added
- New "Restore From Tape" feature as menu option #4.
- The restore function rewinds the tape, prompts for a destination directory, creates it if non-existent, and extracts the archive from the tape.

### Changed
- Re-numbered all subsequent menu options to accommodate the new Restore feature.
- Updated script version to 1.0.1.

## [1.0.0] - 2025-09-09

This is the first public release of tapectrl, establishing all core functionalities for LTO tape management via a user-friendly, terminal-based menu.

### Added
- Core script structure with a `dialog`-based UI styled after the Debian installer.
- Main menu with 11 initial options: Write, Rewind, Verify, Clean, Erase, Status, Offline, Tape Movement, Write EOF, Retension, and Info.
- Dependency check for `dialog`, `mt`, `mbuffer`, `dd`, and `tar`.
- Custom dark theme using a `.dialogrc` file.
- ASCII art logo.
- Robust input handling and cancellation for all dialog boxes.
- Environment check and fix for `TERM` variable to ensure `dialog` compatibility.
