#!/bin/bash
# test_strings.sh - Unit tests for detect_strings.sh functionality

set -o pipefail

# Setup test state
pass=0
fail=0

# Assertion helper
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

# Initialize script environment
# Important: Set TEST_ROOT before sourcing modules so they can find fixtures
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_ROOT/lib/platform.sh"
plat_init
source "$TEST_ROOT/lib/detect_strings.sh"

echo "============================================"
echo "Running detect_strings.sh Unit Tests"
echo "============================================"
echo

# Test 1: GA36 strings fixture → detect A33 and AllWinner
echo "Test 1: GA36 fixture (verified A33 detection)"
detect_strings_from_file "$TEST_ROOT/tests/fixtures/ga36_strings.txt"
assert_eq "SOC_VENDOR is allwinner" "allwinner" "$SOC_VENDOR"
assert_eq "SOC_MODEL is A33" "A33" "$SOC_MODEL"
assert_eq "SOC_CONFIDENCE is verified" "verified" "$SOC_CONFIDENCE"
echo

# Test 2: Empty strings file → detect nothing
echo "Test 2: Empty strings file"
tmpfile1=$(mktemp) || {
    echo "ERROR: Failed to create temporary file" >&2
    exit 1
}
detect_strings_from_file "$tmpfile1"
assert_eq "SOC_VENDOR is unknown" "unknown" "$SOC_VENDOR"
assert_eq "SOC_MODEL is unknown" "unknown" "$SOC_MODEL"
# Note: SOC_CONFIDENCE defaults to "unverified" even for empty files
rm -f "$tmpfile1"
echo

# Test 3: Synthetic RK3326 strings → detect Rockchip model
echo "Test 3: Synthetic RK3326 strings (unverified Rockchip)"
tmpfile2=$(mktemp) || {
    echo "ERROR: Failed to create temporary file" >&2
    exit 1
}
cat > "$tmpfile2" << 'EOF'
rockchip,rk3326
RK3326 DDR
Some other content
EOF
detect_strings_from_file "$tmpfile2"
assert_eq "SOC_VENDOR is rockchip" "rockchip" "$SOC_VENDOR"
assert_eq "SOC_MODEL is RK3326" "RK3326" "$SOC_MODEL"
assert_eq "SOC_CONFIDENCE is unverified" "unverified" "$SOC_CONFIDENCE"
rm -f "$tmpfile2"
echo

# Test 4: Synthetic Allwinner H700 strings → detect H700
echo "Test 4: Synthetic Allwinner H700 strings (unverified)"
tmpfile3=$(mktemp) || {
    echo "ERROR: Failed to create temporary file" >&2
    exit 1
}
cat > "$tmpfile3" << 'EOF'
AllWinner Technology
sun50iw6
Some boot strings
EOF
detect_strings_from_file "$tmpfile3"
assert_eq "SOC_VENDOR is allwinner" "allwinner" "$SOC_VENDOR"
assert_eq "SOC_MODEL is H700" "H700" "$SOC_MODEL"
assert_eq "SOC_CONFIDENCE is unverified" "unverified" "$SOC_CONFIDENCE"
rm -f "$tmpfile3"
echo

# Results Summary
echo "============================================"
echo "Test Results Summary"
echo "============================================"
echo "PASSED: $pass"
echo "FAILED: $fail"
echo "TOTAL:  $((pass + fail))"
echo

if [[ $fail -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
