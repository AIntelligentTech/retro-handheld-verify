#!/bin/bash
# test_verdict.sh - Unit tests for verdict.sh module
# Pure bash implementation with assertion pattern

set -o pipefail

# Counter variables
pass=0
fail=0

# assert_eq - Simple equality assertion
# Args: description, expected, actual
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

# Setup: source the modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/platform.sh" || {
    echo "ERROR: Failed to source platform.sh" >&2
    exit 1
}

plat_init || {
    echo "ERROR: plat_init failed" >&2
    exit 1
}

source "$SCRIPT_DIR/lib/verdict.sh" || {
    echo "ERROR: Failed to source verdict.sh" >&2
    exit 1
}

# Initialize globals that compute_verdict expects
# These are normally set by the detection modules
reset_globals() {
    BOOTLOADER_TYPE=""
    BOOTLOADER_CONFIDENCE=""
    SOC_VENDOR=""
    SOC_MODEL=""
    SOC_CONFIDENCE=""
    DTB_COUNT=0
    DTB_FILES=""
    PARTITION_TYPES=""
    DISK_SIZE_BYTES=0
    DISK_READ_SPEED="0"
}

# Test 1: eGON + A33 → GA36_CLONE
echo "Test 1: eGON + A33 → GA36_CLONE"
reset_globals
BOOTLOADER_TYPE="allwinner_egon"
BOOTLOADER_CONFIDENCE="verified"
SOC_VENDOR="allwinner"
SOC_MODEL="A33"
SOC_CONFIDENCE="verified"
compute_verdict
assert_eq "GA36 clone verdict" "GA36_CLONE" "$VERDICT"
assert_eq "GA36 clone confidence" "high" "$VERDICT_CONFIDENCE"

# Test 2: eGON + unknown SoC → ALLWINNER_UNKNOWN
echo "Test 2: eGON + unknown SoC → ALLWINNER_UNKNOWN"
reset_globals
BOOTLOADER_TYPE="allwinner_egon"
BOOTLOADER_CONFIDENCE="verified"
SOC_VENDOR="allwinner"
SOC_MODEL="unknown_allwinner"
SOC_CONFIDENCE="unverified"
compute_verdict
assert_eq "Allwinner unknown verdict" "ALLWINNER_UNKNOWN" "$VERDICT"
assert_eq "Allwinner unknown confidence" "medium" "$VERDICT_CONFIDENCE"

# Test 3: Rockchip idb + RK3326 → ROCKCHIP
echo "Test 3: Rockchip idb + RK3326 → ROCKCHIP"
reset_globals
BOOTLOADER_TYPE="rockchip_idb"
BOOTLOADER_CONFIDENCE="unverified"
SOC_VENDOR="rockchip"
SOC_MODEL="RK3326"
SOC_CONFIDENCE="unverified"
compute_verdict
assert_eq "Rockchip verdict" "ROCKCHIP" "$VERDICT"
assert_eq "Rockchip confidence" "low" "$VERDICT_CONFIDENCE"

# Test 4: No bootloader → UNKNOWN
echo "Test 4: No bootloader → UNKNOWN"
reset_globals
BOOTLOADER_TYPE="unknown"
BOOTLOADER_CONFIDENCE="none"
SOC_VENDOR="unknown"
SOC_MODEL="unknown"
SOC_CONFIDENCE="none"
compute_verdict
assert_eq "Unknown verdict" "UNKNOWN" "$VERDICT"
assert_eq "Unknown confidence" "none" "$VERDICT_CONFIDENCE"

# Test 5: Amlogic (strings only, no bootloader match) → AMLOGIC
echo "Test 5: Amlogic (strings only, no bootloader match) → AMLOGIC"
reset_globals
BOOTLOADER_TYPE="unknown"
BOOTLOADER_CONFIDENCE="none"
SOC_VENDOR="amlogic"
SOC_MODEL="unknown"
SOC_CONFIDENCE="unverified"
compute_verdict
assert_eq "Amlogic verdict" "AMLOGIC" "$VERDICT"
assert_eq "Amlogic confidence" "low" "$VERDICT_CONFIDENCE"

# Results summary
echo ""
echo "========================================"
echo "Test Results Summary"
echo "========================================"
echo "PASSED: $pass"
echo "FAILED: $fail"
echo "TOTAL:  $((pass + fail))"
echo "========================================"

# Exit with failure if any tests failed
if [[ $fail -gt 0 ]]; then
    exit 1
fi

exit 0
