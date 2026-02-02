# retro-handheld-verify

Open-source tool for verifying retro handheld gaming device SD cards.

## Architecture

Modular detection pipeline — each module is independently testable:

```
verify.sh                  → Entry point, orchestrator
lib/platform.sh            → Cross-platform abstractions (macOS/Linux)
lib/detect_bootloader.sh   → Sector-level magic byte detection
lib/detect_strings.sh      → Boot area string analysis for SoC ID
lib/detect_dtb.sh          → Device Tree Blob discovery + hashing
lib/detect_disk.sh         → Disk info and speed measurement
lib/detect_partitions.sh   → MBR partition table analysis
lib/verdict.sh             → Signal combination → verdict
contribute.sh              → Community data collection tool
signatures/devices.json    → Verified device database (only proven entries)
```

## Key Conventions

- **Verified vs Unverified**: Only hardware-tested signatures go in devices.json. Detection logic for untested platforms is kept but marked "unverified"
- **No judgments**: Tool reports data (speed in MB/s, partition types), never opinions (fast/slow, genuine/fake)
- **Pure bash**: No external dependencies beyond standard Unix tools (dd, strings, xxd)
- **Testing**: `tests/test_*.sh` are self-contained bash scripts, no framework needed

## Running Tests

```bash
for t in tests/test_*.sh; do bash "$t"; done
```

## Linting

```bash
shellcheck verify.sh contribute.sh lib/*.sh
```

## Adding Detection Logic

1. Create/edit the appropriate `lib/detect_*.sh` module
2. Add corresponding tests in `tests/`
3. If adding a new verified device, update `signatures/devices.json` with full verification metadata
4. Run shellcheck and all tests before submitting

## Device Database

`signatures/devices.json` — only verified entries. Each device must have:
- Signal data (bootloader magic, strings, partitions)
- Verification metadata (method, verified_by, date, description)

## Edge Cases

- macOS uses /dev/rdiskN (raw character device), Linux uses /dev/sdX or /dev/mmcblk0 (block device)
- `date +%s%N` for nanoseconds doesn't work on macOS — platform.sh handles this
- Some SD cards may have no mounted partitions (raw image) — DTB detection handles gracefully
- The `[ND]A33` string contains literal brackets — grep needs `-F` flag for fixed-string matching
