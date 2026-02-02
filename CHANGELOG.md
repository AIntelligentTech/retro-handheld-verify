# Changelog

All notable changes to this project will be documented in this file.

## [0.1.1] - 2026-02-02

### Fixed
- `plat_readbytes`: use block-aligned reads (bs=4096/512) instead of bs=1 for large reads — DTB 10MB scan went from minutes to milliseconds
- `_search_dtb_magic`: replace O(n) bash string loop with `grep -boa` on binary data — orders of magnitude faster
- `output_json`: add `json_str()` escaper for all interpolated values — previously produced invalid JSON on special characters
- `detect_disk`: fix `$?` after command substitution swallowing errors with pipefail
- `detect_strings` dedup: replace space-delimited array scan with associative array lookup — fixed false matches on strings containing spaces
- `contribute.sh` `macos_to_raw_device`: tighten regex from `^/dev/disk` to `^/dev/disk[0-9]`

### Changed
- Eliminate `SCRIPT_DIR` variable collisions — each module now uses a unique var name (`_STRINGS_DIR`, `_DTB_DIR`, `_DISK_DIR`, `_VERDICT_DIR`, `CONTRIBUTE_DIR`)
- Remove unnecessary `export -f` from `detect_strings.sh`
- Add `set -o pipefail` to all detection modules for consistency

### Documentation
- Rewrite `CLAUDE.md` as comprehensive engineering reference with architecture, module contract, variable naming table, critical patterns, test fixture provenance, and CI documentation
- Rewrite `CONTRIBUTING.md` with hard code standards, step-by-step guides for adding SoC vendors and verified devices, and verification requirements table
- Rewrite `docs/how-it-works.md` with pipeline diagram, platform function reference, implementation details, and Allwinner codename table
- Rewrite `docs/clone-guide.md` with hardware comparison table and marketplace context
- Rewrite `docs/known-devices.md` with signal reference tables
- Upgrade `SKILL.md` with full frontmatter, detection module API, verdict decision tree, edge cases, and troubleshooting

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
