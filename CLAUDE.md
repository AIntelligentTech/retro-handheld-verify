# retro-handheld-verify

SD card forensics tool for retro handheld gaming devices. Pure bash, zero dependencies beyond `dd`, `strings`, `xxd`, and `grep`. Reads raw sectors, extracts bootloader signatures and SoC identifiers, matches against a verified database of hardware-tested devices.

## Philosophy

**Only ship what we can prove.** Every entry in `signatures/devices.json` was tested on physical hardware with full attribution. Detection logic for untested platforms exists but is explicitly marked `"unverified"`. The tool reports data — never opinions about speed, price, or quality.

## Architecture

```
verify.sh                      Entry point. Parses args, sources all modules, runs pipeline, outputs.
contribute.sh                  Interactive data collector → JSON report for GitHub issue submission.

lib/
├── platform.sh                Cross-platform abstraction. macOS (character devices, diskutil, md5)
│                              vs Linux (block devices, blockdev, md5sum). All I/O goes through here.
├── detect_bootloader.sh       Reads magic bytes at sector 16 offset +4 (Allwinner eGON) and
│                              sector 64 offset +0 (Rockchip idbloader). Two entry points:
│                              detect_bootloader(DEVICE) and detect_bootloader_from_file(FILE, SECTOR).
├── detect_strings.sh          Extracts ASCII strings from first 32MB via dd|strings. Pattern-matches
│                              SoC identifiers ([ND]A33, AllWinner, RK3326, amlogic, sun8iw5, etc).
│                              Verified A33 detection; everything else marked unverified.
├── detect_dtb.sh              Discovers .dtb files on mounted partitions (find + md5). Falls back
│                              to binary grep for DTB magic (0xd00dfeed) in raw boot area.
├── detect_disk.sh             Disk size (diskutil/blockdev), model name, sequential read speed
│                              (parsed from dd's own timing output — no date +%s%N on macOS).
├── detect_partitions.sh       Reads MBR partition table. Extracts type bytes at offsets 450/466/482/498
│                              in the hex dump. Reports partition types as uppercase hex (0C, 06, 85).
└── verdict.sh                 Decision tree: eGON+A33→GA36_CLONE(high), eGON+other→ALLWINNER_UNKNOWN
                               (medium), idbloader→ROCKCHIP(low), amlogic→AMLOGIC(low), else→UNKNOWN(none).

signatures/
├── devices.json               Verified device database. schema_version 1.0.0. One entry: GA36.
└── verified/                  Individual device reports (JSON from contribute.sh).

tests/
├── test_bootloader.sh         8 assertions — GA36 fixture, synthetic Rockchip, all-zeros.
├── test_strings.sh            11 assertions — GA36 fixture, empty, synthetic RK3326, synthetic H700.
├── test_verdict.sh            10 assertions — all 5 verdict branches.
├── test_json.sh               6 assertions — JSON validity, schema, required fields.
└── fixtures/
    ├── ga36_sector16.bin       512 bytes. Real sector 16 from GA36 clone SD card.
    ├── ga36_sector64.bin       512 bytes. Real sector 64 (all 0xff — no Rockchip).
    └── ga36_strings.txt        23,878 lines. Real strings output from first 32MB.
```

## Module Contract

Every `lib/detect_*.sh` module follows the same contract:

1. Sources `platform.sh` via its own `_<MODULE>_DIR` variable (never `SCRIPT_DIR` — that collides across modules)
2. Declares global result variables at file scope (e.g., `BOOTLOADER_TYPE=""`)
3. Exposes `detect_<name>(DEVICE)` for live devices and `detect_<name>_from_file(FILE)` for testing
4. Sets globals on return — caller reads them directly
5. Returns 0 on success (even if detection found nothing), 1 on error (bad input, I/O failure)
6. Each signal carries a confidence: `verified`, `unverified`, or `none`
7. `set -o pipefail` at top of every module

## Variable Naming

Each module uses a unique directory variable to prevent collision when sourced together:

| Module | Variable |
|--------|----------|
| `verify.sh` | `VERIFY_DIR` |
| `contribute.sh` | `CONTRIBUTE_DIR` |
| `detect_strings.sh` | `_STRINGS_DIR` |
| `detect_dtb.sh` | `_DTB_DIR` |
| `detect_disk.sh` | `_DISK_DIR` |
| `verdict.sh` | `_VERDICT_DIR` |
| `detect_bootloader.sh` | (inline `$(dirname ...)`) |
| `detect_partitions.sh` | (inline `$(dirname ...)`) |

Never use `SCRIPT_DIR` in any file.

## Critical Patterns

### Block-aligned reads

`plat_readbytes` auto-selects `bs=4096`, `bs=512`, or `bs=1` based on alignment. The DTB module reads 10MB — that's 10 million syscalls at `bs=1`. Always prefer aligned reads.

### dd | xxd pipe (never xxd -s on devices)

On macOS, `xxd -s <offset>` fails on raw character devices (`/dev/rdiskN`) with "Invalid argument". The bootloader detector uses `dd if=device bs=512 skip=N count=1 | xxd -p -s <offset_within_sector> -l 4` instead.

### grep -F for literal brackets

The A33 identifier string `[ND]A33` contains literal brackets. Using `grep "[ND]A33"` treats `[ND]` as a character class matching `N` or `D`. Must use `grep -F "[ND]A33"` for fixed-string matching.

### Command substitution exit codes

With `set -o pipefail`, `VAR=$(cmd)` followed by `if [[ $? -ne 0 ]]` is unreliable — `$?` captures the assignment, not the subshell. Use `if ! VAR=$(cmd)` instead. See `detect_disk.sh` for the correct pattern.

### Associative array dedup

String dedup in `detect_strings.sh` uses `local -A seen_map=()` with `${seen_map["${str}"]+x}` existence checks. The previous pattern `[[ ! " ${seen[*]} " == *" ${str} "* ]]` broke on strings containing spaces (e.g., "AllWinner Technology" partially matching other entries).

### JSON escaping

`verify.sh` output_json uses `json_str()` which escapes `\`, `"`, `\n`, `\r`, `\t`. The `contribute.sh` `json_escape()` function does the same. Never use raw `printf '%s'` for user-influenced values in JSON output.

### Platform variable guard

`platform.sh` declares `PLATFORM="${PLATFORM:-}"` — the `:-` guard prevents resetting when the file is re-sourced by multiple modules in the same shell.

### macOS disk conversion

`verify.sh` converts `/dev/diskN` → `/dev/rdiskN` (raw character device) for performance. The regex must be `^/dev/disk[0-9]` — using `^/dev/disk` would also match paths like `/dev/diskutil`.

### DTB binary search

`_search_dtb_magic` uses `grep -boa` (byte-offset, text-mode, binary-ok) to find `\xd0\x0d\xfe\xed` in a temp file. This is orders of magnitude faster than the previous approach of converting 10MB to hex and iterating character-by-character in bash.

## Testing

```bash
# Run all tests (35 assertions across 4 files)
for t in tests/test_*.sh; do bash "$t"; done

# Lint (library-pattern exceptions required)
shellcheck -x -e SC2034 -e SC1090 -e SC1091 verify.sh contribute.sh lib/*.sh

# Syntax check
bash -n verify.sh contribute.sh lib/*.sh
```

### Shellcheck exceptions

| Code | Reason |
|------|--------|
| SC2034 | Library modules declare globals that are consumed by the caller, not locally |
| SC1090 | Dynamic `source` paths (`"${VERIFY_DIR}/lib/..."`) can't be followed statically |
| SC1091 | Same — shellcheck can't resolve sourced file paths |

### Test fixture provenance

All fixtures in `tests/fixtures/` were extracted from a real GA36 clone SD card (AliExpress, 64GB, stock firmware) on 2026-02-02:

- `ga36_sector16.bin` — `dd if=/dev/rdisk6 bs=512 skip=16 count=1`
- `ga36_sector64.bin` — `dd if=/dev/rdisk6 bs=512 skip=64 count=1`
- `ga36_strings.txt` — `dd if=/dev/rdisk6 bs=1M count=32 | strings`

## Signature Database

`signatures/devices.json` — schema version 1.0.0.

### Required fields per device

```
name, type, soc_vendor, soc_model, signals{}, verification{}
```

### Verification requirements

Every device entry must have `verification.method` = `"physical_hardware_test"` with `verified_by` (GitHub username), `verified_date` (ISO 8601), and `test_description` (free text describing the hardware and source).

### What does NOT go in the database

- DTB hashes from GitHub repos (unless independently verified on hardware)
- Speed thresholds or price judgments
- Anonymous or unattributed entries

## CI/CD

Two GitHub Actions workflows:

1. **ci.yml** — runs on push to main and all PRs:
   - `shellcheck` lint with library exceptions
   - `bash -n` syntax check
   - Unit tests on `ubuntu-latest` and `macos-latest`

2. **validate-signatures.yml** — runs on changes to `signatures/`:
   - JSON validity check via `python3`
   - Schema validation via `test_json.sh`

## Adding Code

1. Every function uses `local` for all variables
2. Every module has `set -o pipefail`
3. Use `_from_file()` variants for testability — never test against live devices in CI
4. Confidence must be `"unverified"` until hardware-tested
5. Run `shellcheck` and all tests before committing
6. Commit messages: `fix:`, `feat:`, `refactor:`, `docs:`, `test:` prefixes
