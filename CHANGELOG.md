# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-02-02

### Added
- Initial release with modular detection pipeline
- `verify.sh` — main entry point with human-readable and JSON output
- `contribute.sh` — community data collection tool
- Detection modules: bootloader, strings, DTB, disk, partitions
- Cross-platform support (macOS and Linux)
- Verdict engine combining signals with confidence levels
- Verified GA36 Allwinner A33 clone detection (high confidence)
- Documented (unverified) Rockchip and Amlogic detection
- Signature database with schema validation
- 35 unit tests with real GA36 hardware fixtures
- CI/CD via GitHub Actions (lint + test on ubuntu + macOS)
- Community contribution workflow via GitHub issue templates
