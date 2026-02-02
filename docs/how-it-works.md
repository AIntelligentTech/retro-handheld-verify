# How retro-handheld-verify Works

## Detection Pipeline

The tool reads raw sectors from an SD card and analyzes multiple signals:

### 1. Bootloader Detection (`lib/detect_bootloader.sh`)

Reads specific sectors and checks for known magic bytes:

| Sector | Offset | Magic | Meaning | Status |
|--------|--------|-------|---------|--------|
| 16 | +4 bytes | `65474F4E` | Allwinner eGON.BT0 | **Verified** |
| 64 | +0 bytes | `3B8CDCFC` | Rockchip idbloader | Unverified |

### 2. String Analysis (`lib/detect_strings.sh`)

Extracts ASCII strings from the first 32MB and matches against known SoC identifiers:

- `[ND]A33` → Allwinner A33 (**verified**)
- `AllWinner Technology` → Allwinner vendor
- `rockchip` / `RK3326` → Rockchip (unverified)

### 3. DTB Discovery (`lib/detect_dtb.sh`)

Searches mounted partitions for Device Tree Blob files and hashes them. Currently reports only — no verified fingerprints in the database.

### 4. Verdict (`lib/verdict.sh`)

Combines signals into a final verdict with confidence level:

| Signals | Verdict | Confidence |
|---------|---------|------------|
| eGON + A33 | GA36_CLONE | High |
| eGON + other | ALLWINNER_UNKNOWN | Medium |
| idbloader | ROCKCHIP | Low |
| amlogic strings | AMLOGIC | Low |
| Nothing matches | UNKNOWN | None |

## Confidence Levels

- **High** — Multiple verified signals match a known device
- **Medium** — Verified bootloader but unverified SoC model
- **Low** — Unverified detection logic (documented but never tested on hardware)
- **None** — No signals matched
