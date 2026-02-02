# Known Devices

## Verified (hardware-tested)

| Device | SoC | Type | Bootloader | CFW | Verified by | Date |
|--------|-----|------|------------|-----|-------------|------|
| GA36 | Allwinner A33 | Clone | eGON.BT0 (`65474F4E`) | None | [@tonydeverill](https://github.com/tonydeverill) | 2026-02-02 |

**Verified** means the tool was run against a physical SD card from that device and the signals were confirmed to be accurate and reproducible.

## Documented but Unverified

These have detection logic in the codebase but no hardware-confirmed entries in the database. A single device report from real hardware would promote them to verified.

| Expected Device | Expected SoC | Expected Bootloader | Detection logic |
|----------------|-------------|--------------------|----|
| R36S (genuine) | Rockchip RK3326 | idbloader (`3B8CDCFC`) | `detect_bootloader.sh` sector 64 + `detect_strings.sh` RK pattern |
| R36S clone variants | Allwinner H700/H616 | Likely eGON | `detect_strings.sh` H700/H616 patterns |
| RG35XX series | Allwinner H700 | Likely eGON | `detect_strings.sh` H700 pattern |
| Amlogic-based handhelds | Amlogic S905/S912 | Unknown | `detect_strings.sh` amlogic/meson patterns |

## Signal Reference

### Bootloader magic bytes

| Magic | ASCII | Location | Vendor | Confidence |
|-------|-------|----------|--------|------------|
| `65474F4E` | `eGON` | Sector 16, offset +4 | Allwinner | Verified |
| `3B8CDCFC` | (binary) | Sector 64, offset +0 | Rockchip | Unverified |

### String identifiers

| String | Vendor | Model | Confidence |
|--------|--------|-------|------------|
| `[ND]A33` | Allwinner | A33 | Verified |
| `sun8iw5` | Allwinner | A33 | Verified |
| `H700` / `sun50iw6` | Allwinner | H700 | Unverified |
| `H616` / `sun50iw9` | Allwinner | H616 | Unverified |
| `H3` / `sun8iw7` | Allwinner | H3 | Unverified |
| `RK3326` / `RK3566` / `RK3588` | Rockchip | (extracted) | Unverified |
| `amlogic` / `aml_` / `meson` | Amlogic | Unknown | Unverified |

### Allwinner platform codenames

| Codename | SoC | Architecture |
|----------|-----|-------------|
| `sun8iw5` | A33 | Cortex-A7 |
| `sun8iw7` | H3 | Cortex-A7 |
| `sun50iw6` | H700 | Cortex-A53 |
| `sun50iw9` | H616 | Cortex-A53 |

## How to add a device

Run `sudo ./contribute.sh /dev/YOUR_DEVICE` and submit the output as a [device report](https://github.com/AIntelligentTech/retro-handheld-verify/issues/new?template=device-report.yml).

See [CONTRIBUTING.md](../CONTRIBUTING.md) for full verification standards.
