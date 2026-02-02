# Clone Detection Guide

## What is a clone?

A clone is a retro handheld that looks identical to a known brand but uses different — usually cheaper — hardware inside. The most common example: devices sold as "R36S" that actually contain an Allwinner A33 instead of the genuine Rockchip RK3326.

## Why it matters

The hardware difference isn't just cosmetic:

| | Genuine R36S (RK3326) | Clone (Allwinner A33) |
|-|----------------------|----------------------|
| Custom firmware | Yes (ArkOS, JELOS, etc.) | No |
| CPU cores | 4x Cortex-A35 @ 1.5GHz | 4x Cortex-A7 @ 1.2GHz |
| GPU | Mali-G31 | Mali-400 MP2 |
| PS1/N64 emulation | Playable | Mostly unplayable |
| Community support | Active | Minimal |

The clone still plays retro games on its stock firmware. But if you bought it expecting to run custom firmware, you're stuck.

## How to tell

You can't tell from the outside. The cases, screens, buttons, and packaging are often identical. But the SD card tells you everything:

```bash
sudo ./verify.sh /dev/disk6
```

If you see `GA36_CLONE (confidence: high)` with `allwinner_egon` bootloader and `A33` SoC — it's a clone.

If you see `ROCKCHIP` with `rockchip_idb` bootloader — it's likely genuine (though Rockchip detection is currently unverified in our database; we need community reports to confirm).

## How clones end up in your hands

1. **Intentional fraud** — seller knows it's a clone, lists it as genuine
2. **Supply chain confusion** — seller sources from a factory that switched to cheaper chips mid-production
3. **Ambiguous listings** — listing never claims "RK3326" but shows photos of a device that looks like an R36S

## What to do if you have a clone

1. **Run `contribute.sh`** and submit a device report — your data helps others avoid the same situation
2. The device still works with its stock firmware for basic retro gaming
3. If the listing was fraudulent, consider filing a dispute with the marketplace
4. Check [docs/known-devices.md](known-devices.md) for what's known about your specific hardware

## Known clone variants

| Sold as | Actual SoC | Bootloader | Detection status |
|---------|-----------|------------|-----------------|
| "R36S" / "GA36" | Allwinner A33 | eGON.BT0 | **Verified** |
| "R36S" variant | Allwinner H700 | Unknown | Unverified — need reports |
| "R36S" variant | Allwinner H616 | Unknown | Unverified — need reports |

This table grows as the community submits device reports. [Submit yours.](https://github.com/AIntelligentTech/retro-handheld-verify/issues/new?template=device-report.yml)
