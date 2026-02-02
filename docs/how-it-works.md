# How retro-handheld-verify Works

## Overview

The tool reads raw bytes from an SD card, extracts multiple independent signals, and combines them into a confidence-weighted verdict. Each signal is produced by an independent detection module that can be tested in isolation.

```
SD Card → [bootloader] → [strings] → [dtb] → [disk] → [partitions] → [verdict] → Output
              ↓              ↓          ↓        ↓           ↓              ↓
          magic bytes    SoC ID     .dtb hash  size/speed  MBR types    GA36_CLONE
          at sector 16   from 32MB  from mount             from hex     (high conf)
```

## Stage 1: Platform Initialization

`lib/platform.sh` detects macOS vs Linux and validates that required tools exist (`dd`, `strings`, `xxd`, `md5`/`md5sum`). All device I/O goes through platform abstraction functions:

| Function | Purpose |
|----------|---------|
| `plat_readbytes` | Read raw bytes with auto block-size selection |
| `plat_md5` | MD5 hash (macOS `md5 -q` vs Linux `md5sum`) |
| `plat_diskinfo` | Disk size in bytes (macOS `diskutil` vs Linux `blockdev`) |
| `plat_readspeed` | Sequential read speed from dd timing output |
| `plat_check_device` | Validate device type (character on macOS, block on Linux) |

On macOS, `verify.sh` automatically converts `/dev/diskN` → `/dev/rdiskN` for raw character device access.

## Stage 2: Bootloader Detection

**Module:** `lib/detect_bootloader.sh`

Reads magic bytes at known sector offsets. Each SoC vendor places its bootloader at a specific location:

| Sector | Byte Offset | Magic Bytes | Meaning | Confidence |
|--------|-------------|-------------|---------|------------|
| 16 | +4 | `65474F4E` | Allwinner eGON.BT0 header | **Verified** — tested on GA36 |
| 64 | +0 | `3B8CDCFC` | Rockchip idbloader | Unverified — documented only |

The eGON magic bytes decode to ASCII `eGON` — the Allwinner boot ROM header format. Byte offset +4 skips the jump instruction at the start of the sector.

**Implementation detail:** On macOS raw devices, `xxd -s <offset>` fails with "Invalid argument". The module uses `dd bs=512 skip=<sector> count=1 | xxd -p -s <offset> -l 4` to pipe through dd first. This is documented in CLAUDE.md under "dd | xxd pipe".

## Stage 3: String Analysis

**Module:** `lib/detect_strings.sh`

Extracts all printable ASCII strings from the first 32MB of the device:

```
dd if=device bs=1M count=32 | strings
```

Then pattern-matches against known SoC identifiers:

| Pattern | Vendor | Model | Confidence |
|---------|--------|-------|------------|
| `[ND]A33` (literal, grep -F) | Allwinner | A33 | **Verified** |
| `sun8iw5` | Allwinner | A33 | **Verified** |
| `AllWinner` + `H700`/`sun50iw6` | Allwinner | H700 | Unverified |
| `AllWinner` + `H616`/`sun50iw9` | Allwinner | H616 | Unverified |
| `AllWinner` + `H3`/`sun8iw7` | Allwinner | H3 | Unverified |
| `rockchip` / `RK3326` / `RK3566` | Rockchip | (extracted) | Unverified |
| `amlogic` / `aml_` / `meson` | Amlogic | Unknown | Unverified |

The `sun8iwN` identifiers are Allwinner's internal platform codenames. `sun8iw5` = A33, `sun50iw6` = H700, etc.

Detection priority: Allwinner A33 (verified) → other Allwinner → Rockchip → Amlogic. First match wins within each priority level.

U-Boot version is also extracted if present (regex: `U-Boot [0-9]+\.[0-9]+[^ ]*`).

## Stage 4: DTB Discovery

**Module:** `lib/detect_dtb.sh`

Device Tree Blobs describe hardware layout. If the SD card has mounted partitions, the module searches them with `find -name "*.dtb"` and hashes each file with MD5.

If no partitions are mounted, it falls back to scanning the raw boot area (first 10MB) for the DTB magic bytes `0xd00dfeed` using `grep -boa` on the raw binary data.

DTB hashes are reported but **not matched** — the database has no verified DTB fingerprints yet. This is data collection for future use.

## Stage 5: Disk & Partition Analysis

**Module:** `lib/detect_disk.sh` — size, model name, sequential read speed.

**Module:** `lib/detect_partitions.sh` — reads the MBR (first 512 bytes) and extracts partition type bytes from the four partition table entries at byte offsets 450, 466, 482, 498. Reports types as uppercase hex (e.g., `0C` = FAT32 LBA, `06` = FAT16, `85` = Linux extended).

## Stage 6: Verdict

**Module:** `lib/verdict.sh`

Combines all signals using a decision tree:

```
                         ┌── SOC_MODEL == A33 ──→ GA36_CLONE (high)
BOOTLOADER == egon ──────┤
                         └── SOC_MODEL != A33 ──→ ALLWINNER_UNKNOWN (medium)

BOOTLOADER == idb ───────────────────────────────→ ROCKCHIP (low, unverified)

SOC_VENDOR == amlogic ───────────────────────────→ AMLOGIC (low, unverified)

else ────────────────────────────────────────────→ UNKNOWN (none)
```

### Confidence levels

| Level | Meaning |
|-------|---------|
| **high** | Multiple verified signals match a known device in the database |
| **medium** | Verified bootloader but unverified or unknown SoC model |
| **low** | Detection logic exists but has never been tested on physical hardware |
| **none** | No signals matched anything |

## Output

`verify.sh` outputs human-readable text by default, or JSON with `--json`:

```bash
sudo ./verify.sh /dev/disk6           # Human-readable
sudo ./verify.sh --json /dev/disk6    # Machine-readable JSON
```

JSON output escapes all string values through `json_str()` to handle special characters safely.

## Data Collection

`contribute.sh` runs all detection modules and outputs a structured JSON report suitable for pasting into a GitHub issue. It prompts for device name, purchase source, and optional notes, then includes all signals in a single JSON object.
