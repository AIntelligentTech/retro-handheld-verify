---
name: retro-handheld-verify
description: Verify retro handheld SD cards against known device signatures using sector-level bootloader magic, SoC string analysis, and DTB fingerprinting
version: 0.1.0
context: fork
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Task
  - WebSearch
---

# retro-handheld-verify

## What This Skill Does

Identifies retro handheld gaming devices by analyzing SD card boot area signatures. Reads raw sectors from an SD card, extracts magic bytes, bootloader strings, and device tree blobs, then matches against a verified signature database.

**Currently verified:** GA36 Allwinner A33 clone (high confidence)
**Documented but unverified:** Rockchip (RK3326/3566/3588), Allwinner H700/H616/H3, Amlogic

## When to Use

- User wants to check if their retro handheld SD card matches a known device
- User wants to contribute their device data to the community database
- User wants to add detection logic for a new SoC or device family
- User wants to understand what's on their SD card at the bootloader level

## Quick Reference

```bash
# Verify a device (requires sudo for raw device access)
sudo ./verify.sh /dev/rdisk6        # macOS (auto-converts diskN → rdiskN)
sudo ./verify.sh /dev/mmcblk0       # Linux

# JSON output for scripting
sudo ./verify.sh --json /dev/rdisk6

# Contribute device data (interactive prompts)
sudo ./contribute.sh /dev/rdisk6

# Run all tests
for t in tests/test_*.sh; do bash "$t"; done

# Lint
shellcheck -x -e SC2034 -e SC1090 -e SC1091 verify.sh contribute.sh lib/*.sh
```

## Architecture

Modular detection pipeline — each `lib/detect_*.sh` module is independently sourceable and testable:

```
verify.sh                  → Entry point, orchestrator
├── lib/platform.sh        → Cross-platform abstractions (macOS/Linux)
├── lib/detect_bootloader  → Sector 16/64 magic byte detection
├── lib/detect_strings     → Boot area string analysis (SoC ID)
├── lib/detect_dtb         → Device Tree Blob discovery + MD5 hashing
├── lib/detect_disk        → Disk size, model, read speed
├── lib/detect_partitions  → MBR partition table analysis
└── lib/verdict.sh         → Signal combination → verdict + confidence

contribute.sh              → Community data collection (JSON output)
signatures/devices.json    → Verified device database
```

### Detection Module API

Each detection module follows the same pattern:

1. **Source:** `source lib/detect_<name>.sh`
2. **Call:** `detect_<name> DEVICE` (live) or `detect_<name>_from_file FILE` (test)
3. **Read results:** Module sets uppercase global variables (e.g., `BOOTLOADER_TYPE`, `SOC_VENDOR`)
4. **Confidence:** Each signal carries `verified`, `unverified`, or `none`

### Verdict Decision Tree

```
eGON magic + A33 strings       → GA36_CLONE     (high)
eGON magic + other strings      → ALLWINNER_UNKNOWN (medium)
Rockchip idbloader magic        → ROCKCHIP       (low, unverified)
Amlogic strings                 → AMLOGIC        (low, unverified)
Nothing matched                 → UNKNOWN        (none)
```

## Development Guide

### Adding a New Verified Device

1. Run `sudo ./contribute.sh /dev/<device>` to collect all signals
2. Create `signatures/verified/<device-name>.json` with the full report
3. Add entry to `signatures/devices.json` with:
   - All signal data (bootloader magic, strings, partition types)
   - Verification metadata (method: `physical_hardware_test`, verified_by, date, description)
4. Add detection logic in the appropriate `lib/detect_*.sh` module
5. Add test cases in `tests/test_*.sh` using real fixture data
6. Update `docs/known-devices.md`

### Adding Detection for a New SoC Family

1. Research the bootloader magic bytes and sector locations
2. Add detection in `lib/detect_bootloader.sh` with `BOOTLOADER_CONFIDENCE="unverified"`
3. Add string patterns in `lib/detect_strings.sh`
4. Add verdict branch in `lib/verdict.sh`
5. Add unit tests with synthetic fixtures
6. Mark everything as "documented but unverified" until hardware-tested

### Testing

Tests are pure bash, no framework. Each `tests/test_*.sh` is self-contained:

- `test_bootloader.sh` — Magic byte parsing against GA36 fixtures + synthetic data
- `test_strings.sh` — SoC string matching against real GA36 strings
- `test_verdict.sh` — Signal combination → verdict for all code paths
- `test_json.sh` — Signature database schema validation

Test fixtures in `tests/fixtures/` are extracted from a real GA36 card.

### CI

GitHub Actions runs on every push/PR:
- `shellcheck` lint (with library-pattern exceptions: SC2034, SC1090, SC1091)
- Unit tests on ubuntu-latest and macos-latest
- Signature database validation on changes to `signatures/`

## Critical Edge Cases

- **macOS raw devices:** `xxd -s` fails on `/dev/rdiskN` — always use `dd | xxd` pipe
- **Platform variable reset:** `lib/platform.sh` uses `PLATFORM="${PLATFORM:-}"` guard to survive re-sourcing
- **Literal brackets in strings:** `[ND]A33` requires `grep -F` (fixed-string), not regex
- **No nanosecond timestamps on macOS:** `date +%s%N` unsupported — speed measurement uses dd's timing output
- **SCRIPT_DIR collision:** `verify.sh` uses `VERIFY_DIR` to avoid collision with lib module `SCRIPT_DIR`
- **Sector file vs disk image:** `detect_bootloader_from_file` checks file size to determine offset calculation

## Signature Database Schema

`signatures/devices.json` contains only hardware-verified entries:

```json
{
  "schema_version": "1.0.0",
  "devices": {
    "<device-id>": {
      "name": "Human-readable name",
      "type": "clone|genuine|unknown",
      "soc_vendor": "allwinner|rockchip|amlogic",
      "soc_model": "A33|RK3326|...",
      "signals": {
        "sector16_magic": "hex string",
        "sector64_magic": "hex string",
        "boot_strings": ["array", "of", "matches"],
        "partition_types": ["0C", "06", "85"]
      },
      "verification": {
        "method": "physical_hardware_test",
        "verified_by": "github_username",
        "verified_date": "YYYY-MM-DD",
        "test_description": "Free text"
      }
    }
  }
}
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "not a character device" on macOS | Using `/dev/diskN` instead of `/dev/rdiskN` | verify.sh auto-converts, or pass `/dev/rdiskN` directly |
| "requires root privileges" | SD card raw access needs sudo | Run with `sudo` |
| All signals "unknown" | SD card may not have a bootloader in standard locations | Normal for some devices — contribute data for analysis |
| DTB count 0 | No mounted partitions and no DTB magic in boot area | Expected for many devices — DTB detection is best-effort |
| shellcheck SC2034 warnings | Library globals appear unused in the defining file | Suppressed in CI with `-e SC2034` |
