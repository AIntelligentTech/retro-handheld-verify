# retro-handheld-verify

[![CI](https://github.com/AIntelligentTech/retro-handheld-verify/actions/workflows/ci.yml/badge.svg)](https://github.com/AIntelligentTech/retro-handheld-verify/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Verified Devices](https://img.shields.io/badge/verified_devices-1-green.svg)](signatures/devices.json)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

**Bought a retro handheld and wondering if it's genuine or a clone?** This tool reads your device's SD card at the sector level and tells you exactly what hardware made it — no guesswork, no opinions, just verified signatures.

> **We need your help.** The database currently has **1 verified device**. Every handheld you test and report makes this tool more useful for the entire community. See [How to Contribute](#-how-to-contribute) below.

## The Problem

Retro handhelds like the R36S are [widely cloned](https://retrohandhelds.gg/multiplicity-of-deception-r36-clones-flood-market/). Sellers on AliExpress and Amazon ship devices that look identical but use completely different (usually cheaper) hardware inside. A genuine R36S uses a Rockchip RK3326 — but many "R36S" units actually contain an Allwinner A33, which can't run custom firmware designed for the real device.

**You can't tell from the outside.** But you can tell from the SD card.

## Quick Start

```bash
git clone https://github.com/AIntelligentTech/retro-handheld-verify.git
cd retro-handheld-verify

# macOS (insert your SD card, check disk number with `diskutil list`)
sudo ./verify.sh /dev/disk6

# Linux
sudo ./verify.sh /dev/mmcblk0
```

### Example Output

```
═══════════════════════════════════════════════════════
  Retro Handheld SD Card Verifier v0.1.0
═══════════════════════════════════════════════════════

VERDICT: ✓ GA36_CLONE (confidence: high)

─── Bootloader ───────────────────────────────────────
  Type:       allwinner_egon
  Magic:      65474F4E (eGON.BT0)
  Confidence: verified

─── SoC ──────────────────────────────────────────────
  Vendor:     allwinner
  Model:      A33
  Confidence: verified

─── Disk ─────────────────────────────────────────────
  Size:       52.0 GB
  Read Speed: 22.87 MB/s

─── Partitions ───────────────────────────────────────
  Types: 0C 06 85
  Count: 3

═══════════════════════════════════════════════════════
```

Machine-readable output is also available:

```bash
sudo ./verify.sh --json /dev/disk6
```

## What It Detects

| Signal | Status | How |
|--------|--------|-----|
| Allwinner eGON bootloader | **Verified** | Magic bytes `65474F4E` at sector 16 |
| Allwinner A33 SoC | **Verified** | `[ND]A33` in boot strings |
| GA36 clone | **Verified** | Both signals above match |
| Rockchip idbloader | Documented, unverified | Magic `3B8CDCFC` at sector 64 |
| Rockchip models (RK3326, RK3566) | Documented, unverified | String matching |
| Allwinner H700/H616/H3 | Documented, unverified | String matching |
| Amlogic SoCs | Documented, unverified | String matching |
| DTB files | Data collection only | Discovery + MD5 hash |
| SD card speed | Data collection only | Sequential read |

**"Verified"** means tested on real hardware. **"Documented, unverified"** means the detection logic exists but nobody has confirmed it against a physical device yet. This is where you come in.

## Philosophy

**Only ship what we can prove.** Unlike other tools that ship large databases of unverified hashes from GitHub repos, every entry in our [signature database](signatures/devices.json) was tested on physical hardware with full attribution — who verified it, when, and with what device.

We don't make judgments about speed ("slow"), price ("cheap"), or quality. The tool reports data. You decide what it means.

## 🤝 How to Contribute

**The single most valuable thing you can do is test your device and submit the results.** It takes about 2 minutes.

### Step 1: Run the data collector

```bash
sudo ./contribute.sh /dev/disk6    # macOS
sudo ./contribute.sh /dev/mmcblk0  # Linux
```

### Step 2: Submit a device report

Open a [device report issue](https://github.com/AIntelligentTech/retro-handheld-verify/issues/new?template=device-report.yml) and paste the JSON output.

### Step 3: That's it

A maintainer will review and add your device to the verified database.

### Devices We Especially Need

We have detection logic ready but no verified hardware for:

- **R36S (genuine)** — Rockchip RK3326. If you have a confirmed genuine R36S, your report would unlock Rockchip verification.
- **R36S clones** — various Allwinner variants (H700, H616). Multiple clone types exist.
- **RG35XX** series — Allwinner H700-based devices
- **Any Amlogic-based handheld** — detection logic exists but is completely untested
- **Trimui, Miyoo, Anbernic** devices — expand coverage to other brands

Even if your device matches an existing entry, duplicate reports from different sellers/batches strengthen confidence.

### Other Ways to Help

- **Star the repo** — helps others find it
- **Report bugs** — [open an issue](https://github.com/AIntelligentTech/retro-handheld-verify/issues/new?template=bug-report.yml)
- **Improve detection** — PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for code guidelines
- **Spread the word** — share with your retro handheld community

## How It Works

The tool reads raw sectors from your SD card and analyzes multiple signals:

1. **Bootloader detection** — reads magic bytes at known sector offsets
2. **String analysis** — extracts SoC identifiers from the first 32MB
3. **DTB discovery** — finds and hashes Device Tree Blob files
4. **Partition analysis** — reads the MBR partition table
5. **Verdict engine** — combines signals into a confidence-weighted result

Each detection module is independent and testable. See [docs/how-it-works.md](docs/how-it-works.md) for the full pipeline.

## Requirements

- bash 4+
- Standard Unix tools: `dd`, `strings`, `xxd`
- Root/sudo access (to read raw device sectors)
- macOS or Linux

No external dependencies. No Python, no Node, no package managers. Just bash and standard Unix tools.

## Project Status

This is v0.1.0 — early but functional. The tool works, the architecture is solid, and the test suite passes on both macOS and Linux. What it needs most is **device data from the community**.

| Metric | Status |
|--------|--------|
| Verified devices | 1 (GA36 clone) |
| Detection modules | 6 (bootloader, strings, DTB, disk, partitions, verdict) |
| Unit tests | 35 passing |
| Platforms | macOS + Linux |
| CI | GitHub Actions (ubuntu + macos) |

## License

MIT — see [LICENSE](LICENSE)

---

Built with frustration after buying a clone R36S that couldn't run custom firmware. If this tool saves you the same confusion, [submit your device data](https://github.com/AIntelligentTech/retro-handheld-verify/issues/new?template=device-report.yml) so it can help the next person too.
