#!/bin/bash
# test_bootloader.sh - Unit tests for bootloader detection
# Pure bash tests, no framework needed

# Setup SCRIPT_DIR to go up one level from tests/ to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Counter variables
pass=0
fail=0

# assert_eq - Simple assertion helper
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
    ((pass++))
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
    ((fail++))
  fi
}

# Test setup: source required libraries
if ! source "$SCRIPT_DIR/lib/platform.sh"; then
  echo "ERROR: Failed to source lib/platform.sh"
  exit 1
fi

if ! plat_init; then
  echo "ERROR: plat_init failed"
  exit 1
fi

if ! source "$SCRIPT_DIR/lib/detect_bootloader.sh"; then
  echo "ERROR: Failed to source lib/detect_bootloader.sh"
  exit 1
fi

# ============================================================================
# Test 1: Parse GA36 sector 16 fixture → detect eGON magic
# ============================================================================
echo "Test 1: GA36 sector 16 (eGON magic)"
detect_bootloader_from_file "$SCRIPT_DIR/tests/fixtures/ga36_sector16.bin" 16
assert_eq "BOOTLOADER_TYPE == allwinner_egon" "allwinner_egon" "$BOOTLOADER_TYPE"
assert_eq "BOOTLOADER_MAGIC == 65474F4E" "65474F4E" "$BOOTLOADER_MAGIC"
assert_eq "BOOTLOADER_CONFIDENCE == verified" "verified" "$BOOTLOADER_CONFIDENCE"

# ============================================================================
# Test 2: Parse GA36 sector 64 fixture → detect empty (no Rockchip)
# ============================================================================
echo ""
echo "Test 2: GA36 sector 64 (empty, no magic)"
detect_bootloader_from_file "$SCRIPT_DIR/tests/fixtures/ga36_sector64.bin" 64
assert_eq "BOOTLOADER_TYPE == unknown" "unknown" "$BOOTLOADER_TYPE"
assert_eq "BOOTLOADER_CONFIDENCE == none" "none" "$BOOTLOADER_CONFIDENCE"

# ============================================================================
# Test 3: Parse synthetic Rockchip sector 64 → detect idbloader
# ============================================================================
echo ""
echo "Test 3: Synthetic Rockchip sector 64 (idbloader magic)"
tmpfile=$(mktemp)
# Create file: Rockchip idbloader magic (3b8cdcfc) + 508 zero bytes
printf '\x3b\x8c\xdc\xfc' > "$tmpfile"
dd if=/dev/zero bs=1 count=508 >> "$tmpfile" 2>/dev/null

detect_bootloader_from_file "$tmpfile" 64
assert_eq "BOOTLOADER_TYPE == rockchip_idb" "rockchip_idb" "$BOOTLOADER_TYPE"
assert_eq "BOOTLOADER_CONFIDENCE == unverified" "unverified" "$BOOTLOADER_CONFIDENCE"
rm -f "$tmpfile"

# ============================================================================
# Test 4: Parse all-zeros file → detect nothing
# ============================================================================
echo ""
echo "Test 4: All-zeros file (no magic)"
tmpzero=$(mktemp)
dd if=/dev/zero bs=1 count=512 of="$tmpzero" 2>/dev/null

detect_bootloader_from_file "$tmpzero" 16
assert_eq "BOOTLOADER_TYPE == unknown (zeros)" "unknown" "$BOOTLOADER_TYPE"
rm -f "$tmpzero"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
echo "Results: $pass passed, $fail failed"
echo "============================================================================"

[[ $fail -eq 0 ]] || exit 1
