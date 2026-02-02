# retro-handheld-verify

A verification tool for retro handheld gaming devices. Identifies whether an SD card came from a genuine or clone device by analyzing bootloader signatures, SoC identifiers, and device tree blobs.

## Philosophy

**Only ship what we can prove.** The signature database contains exclusively verified entries — devices tested on real hardware. Unverified detection logic is clearly marked.

## Quick Start

```bash
# macOS
sudo ./verify.sh /dev/rdisk6

# Linux
sudo ./verify.sh /dev/mmcblk0

# JSON output for scripting
sudo ./verify.sh --json /dev/rdisk6
```

## What It Detects

### Verified (tested on real hardware)
- **Allwinner eGON bootloader** — magic bytes at sector 16
- **Allwinner A33 SoC** — from U-Boot boot strings
- **GA36 clone** — when both Allwinner eGON + A33 match

### Documented but Unverified
- Rockchip idbloader at sector 64
- Rockchip SoC models (RK3326, RK3566, etc.) from strings
- Allwinner H700/H616/H3 from strings
- Amlogic SoCs from strings

### Data Collection Only (no verdict)
- DTB file discovery and MD5 hashing
- Partition type listing
- SD card read speed

## Contributing Device Data

```bash
sudo ./contribute.sh /dev/rdisk6
```

This collects all signals from your device and outputs JSON you can submit as a [device report issue](../../issues/new?template=device-report.yml).

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## How It Works

See [docs/how-it-works.md](docs/how-it-works.md) for the full detection pipeline.

## Requirements

- bash 4+
- Standard Unix tools: dd, strings, xxd
- Root/sudo access (to read raw device sectors)
- macOS or Linux

## License

MIT — see [LICENSE](LICENSE)
