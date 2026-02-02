# Contributing to retro-handheld-verify

## Adding a New Device

The most valuable contribution is a verified device report. Here's how:

### 1. Run the data collector

```bash
sudo ./contribute.sh /dev/YOUR_DEVICE
```

### 2. Submit a device report

Open a [device report issue](../../issues/new?template=device-report.yml) and paste the JSON output.

### 3. What happens next

A maintainer will review your report and, if the signals are clear, add it to `signatures/devices.json` with full verification metadata.

## Verification Standards

For a device to be added to the verified database:

1. **Physical hardware test** — someone must run the tool against a real card from that device
2. **Reproducible signals** — bootloader magic and string patterns must be consistent
3. **Full metadata** — who verified it, when, and from what source

We do NOT accept:
- DTB hashes from GitHub repos (unless independently verified on hardware)
- Speed-based judgments or price-based classification
- Unattributed or anonymous bulk entries

## Code Contributions

1. Fork the repo
2. Create a feature branch
3. Ensure `shellcheck` passes: `shellcheck verify.sh contribute.sh lib/*.sh`
4. Ensure all tests pass: `for t in tests/test_*.sh; do bash "$t"; done`
5. Submit a PR

## Code Style

- Pure bash (no external dependencies beyond standard Unix tools)
- All functions use `local` variables
- Detection modules are independently sourceable and testable
- Each signal reports its own confidence level
