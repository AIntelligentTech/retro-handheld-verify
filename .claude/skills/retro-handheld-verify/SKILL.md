---
name: retro-handheld-verify
description: Verify retro handheld SD cards against known device signatures
version: 0.1.0
---

# retro-handheld-verify

## What This Does

Identifies retro handheld gaming devices by analyzing SD card bootloader signatures, SoC identifiers, and device metadata. Currently supports verified detection of GA36 Allwinner A33 clones.

## When to Use

- User wants to check if their retro handheld is genuine or clone
- User has an SD card from a retro handheld and wants to identify the hardware
- User wants to contribute device data to the project

## How to Run

```bash
# Verify a device
cd ~/retro-handheld-verify
sudo ./verify.sh /dev/rdisk6        # macOS
sudo ./verify.sh /dev/mmcblk0       # Linux

# JSON output
sudo ./verify.sh --json /dev/rdisk6

# Contribute device data
sudo ./contribute.sh /dev/rdisk6
```

## Development

```bash
# Run tests
for t in tests/test_*.sh; do bash "$t"; done

# Lint
shellcheck verify.sh contribute.sh lib/*.sh
```
