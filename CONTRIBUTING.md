# Contributing to retro-handheld-verify

## Device Reports (No Code Required)

The most valuable contribution is a verified device report. This takes about 2 minutes and requires no programming knowledge.

### Step 1: Collect data

```bash
# Insert your SD card and find the device path
diskutil list              # macOS — look for your SD card size
lsblk                     # Linux — look for your SD card

# Run the data collector
sudo ./contribute.sh /dev/disk6        # macOS
sudo ./contribute.sh /dev/mmcblk0      # Linux
```

### Step 2: Submit

Open a [device report issue](../../issues/new?template=device-report.yml) and paste the JSON output.

### Step 3: Done

A maintainer will review the signals and add your device to the verified database with full attribution.

### What makes a report useful

- Run against the **stock SD card** that came with the device (not a reflashed card)
- Include the **device name** as printed on the box or listing
- Include **where you bought it** (AliExpress store name, Amazon listing, etc.)
- Note anything unusual (multiple SD cards included, device looks different from listing photos, etc.)

### Devices we especially need

We have detection logic ready but no verified hardware for:

| Device | Expected SoC | What it unlocks |
|--------|-------------|-----------------|
| R36S (genuine) | Rockchip RK3326 | First Rockchip verification |
| R36S clones | Allwinner H700/H616 | Clone variant identification |
| RG35XX series | Allwinner H700 | Anbernic device coverage |
| Any Amlogic handheld | Amlogic S905/S912 | Amlogic vendor verification |
| Trimui, Miyoo devices | Various | Brand coverage expansion |

Even duplicate reports from different sellers/batches strengthen confidence.

---

## Code Contributions

### Before you start

1. Read `CLAUDE.md` — it documents every architectural decision, critical pattern, and known gotcha
2. Run the existing tests: `for t in tests/test_*.sh; do bash "$t"; done`
3. Run shellcheck: `shellcheck -x -e SC2034 -e SC1090 -e SC1091 verify.sh contribute.sh lib/*.sh`

### Development workflow

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/retro-handheld-verify.git
cd retro-handheld-verify

# Create a branch
git checkout -b feat/rockchip-verification

# Make changes...

# Verify
bash -n verify.sh contribute.sh lib/*.sh          # Syntax check
shellcheck -x -e SC2034 -e SC1090 -e SC1091 \
  verify.sh contribute.sh lib/*.sh                 # Lint
for t in tests/test_*.sh; do bash "$t"; done       # Tests

# Commit and push
git add <specific files>
git commit -m "feat: add verified RK3326 detection from R36S hardware test"
git push origin feat/rockchip-verification
```

### Code standards

**These are hard requirements, not guidelines. PRs that violate them will be rejected.**

#### Shell discipline

- `set -o pipefail` at the top of every module
- `local` for every variable inside functions — no accidental globals
- Never use `SCRIPT_DIR` — use a module-specific name (see CLAUDE.md variable naming table)
- Never use `$?` after command substitution with pipefail — use `if ! VAR=$(cmd)` pattern
- Always `rm -f` temp files, even on error paths

#### Platform safety

- Never use `xxd -s` directly on device files — always `dd | xxd` pipe
- Never use `date +%s%N` — not supported on macOS
- Never use `grep` without `-F` on strings containing regex metacharacters (`[`, `]`, `.`, `*`)
- Test on both macOS and Linux (CI covers this, but verify locally if possible)

#### Detection modules

- Follow the module contract: source platform.sh, declare globals, expose `detect_<name>()` and `detect_<name>_from_file()`
- New detection must have confidence `"unverified"` until hardware-tested
- Add test cases using synthetic fixtures for unverified detection
- Add test cases using real fixtures when hardware-verified

#### JSON output

- All string interpolation must go through `json_str()` (verify.sh) or `json_escape()` (contribute.sh)
- Never raw `printf '%s'` with user-influenced or device-extracted values

#### Commit messages

```
feat: add verified RK3326 detection from R36S hardware test
fix: handle empty partition table without crashing
refactor: replace byte-by-byte DTB search with grep -boa
docs: add Rockchip to known devices table
test: add verdict test for RK3326 + idbloader combo
```

### Adding a new SoC vendor

This is a multi-file change. Here's the exact sequence:

1. **`lib/detect_bootloader.sh`** — Add magic byte check at the correct sector/offset. Set `BOOTLOADER_CONFIDENCE="unverified"`.

2. **`lib/detect_strings.sh`** — Add string patterns in a new `if` block after existing vendor checks. Follow the existing priority chain (allwinner first, then rockchip, then amlogic, then new vendor). Set `SOC_CONFIDENCE="unverified"`.

3. **`lib/verdict.sh`** — Add an `elif` branch in `compute_verdict()`. Use `VERDICT_CONFIDENCE="low"` and set `VERDICT_NOTES` explaining the detection is unverified.

4. **`tests/test_bootloader.sh`** — Add a test with a synthetic sector fixture (512 bytes, magic at correct offset).

5. **`tests/test_strings.sh`** — Add a test with synthetic strings in a temp file.

6. **`tests/test_verdict.sh`** — Add a test calling `compute_verdict` with the new globals set.

7. **`docs/how-it-works.md`** — Add the new magic bytes to the bootloader table and the new verdict to the decision tree.

8. **`CLAUDE.md`** — If any new patterns or gotchas emerged, document them.

### Adding a verified device (hardware-tested)

1. Run `sudo ./contribute.sh /dev/<device>` and save the JSON output
2. Save the full report to `signatures/verified/<device-name>.json`
3. Add the device to `signatures/devices.json` with all signal data and `verification.method: "physical_hardware_test"`
4. If this is the first verified instance of an unverified vendor/model, update confidence from `"unverified"` to `"verified"` in the relevant detection modules
5. Extract test fixtures from the real card and add them to `tests/fixtures/`
6. Add test cases that use the real fixtures
7. Update `docs/known-devices.md`

### Verification standards

For a device to enter the verified database:

| Requirement | Non-negotiable |
|-------------|----------------|
| Tested on physical hardware | Yes |
| Stock SD card (not reflashed) | Yes |
| Reproducible signals | Yes — bootloader magic and string patterns must be consistent |
| Full attribution | Yes — who verified, when, from what source |
| contribute.sh output attached | Yes |

We do **not** accept:
- DTB hashes harvested from GitHub repos
- Speed-based or price-based classification
- Unattributed entries
- Entries based on "should work" reasoning
