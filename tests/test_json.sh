#!/bin/bash
# test_json.sh - Unit tests for signatures/devices.json validity
# Pure bash tests, no framework needed
# Uses python3 for JSON parsing (more portable than jq for CI environments)

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

# assert_true - Check if a condition is true
assert_true() {
  local desc="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS: $desc"
    ((pass++))
  else
    echo "  FAIL: $desc"
    ((fail++))
  fi
}

DEVICES_JSON="$SCRIPT_DIR/signatures/devices.json"

# Verify file exists
if [[ ! -f "$DEVICES_JSON" ]]; then
  echo "ERROR: $DEVICES_JSON not found"
  exit 1
fi

# ============================================================================
# Test 1: File is valid JSON
# ============================================================================
echo "Test 1: Valid JSON format"
json_valid=$(python3 -c "import json; json.load(open('$DEVICES_JSON')); print('true')" 2>/dev/null || echo "false")
assert_eq "JSON is valid" "true" "$json_valid"

# ============================================================================
# Test 2: schema_version field exists and matches semver pattern
# ============================================================================
echo ""
echo "Test 2: schema_version field"
schema_version=$(python3 << EOF
import json
with open('$DEVICES_JSON') as f:
    data = json.load(f)
    print(data.get('schema_version', ''))
EOF
)

assert_true "schema_version exists" "[[ -n '$schema_version' ]]"

# Check if schema_version matches semver pattern (X.Y.Z)
semver_regex='^[0-9]+\.[0-9]+\.[0-9]+$'
if [[ $schema_version =~ $semver_regex ]]; then
  echo "  PASS: schema_version matches semver pattern ($schema_version)"
  ((pass++))
else
  echo "  FAIL: schema_version '$schema_version' does not match semver pattern"
  ((fail++))
fi

# ============================================================================
# Test 3: All devices have required fields
# ============================================================================
echo ""
echo "Test 3: Device fields validation"
# Check that each device has: name, type, soc_vendor, soc_model, signals, verification
fields_valid=$(python3 << EOF
import json
with open('$DEVICES_JSON') as f:
    data = json.load(f)
    devices = data.get('devices', {})
    required_fields = ['name', 'type', 'soc_vendor', 'soc_model', 'signals', 'verification']
    for device_id, device_data in devices.items():
        for field in required_fields:
            if field not in device_data:
                print('false')
                exit(0)
    print('true')
EOF
)

assert_eq "All devices have required fields" "true" "$fields_valid"

# ============================================================================
# Test 4: All verification entries have method and verified_date
# ============================================================================
echo ""
echo "Test 4: Verification fields validation"
verification_valid=$(python3 << EOF
import json
with open('$DEVICES_JSON') as f:
    data = json.load(f)
    devices = data.get('devices', {})
    for device_id, device_data in devices.items():
        verification = device_data.get('verification', {})
        if 'method' not in verification or 'verified_date' not in verification:
            print('false')
            exit(0)
    print('true')
EOF
)

assert_eq "All verifications have method and verified_date" "true" "$verification_valid"

# ============================================================================
# Test 5: devices object is not empty
# ============================================================================
echo ""
echo "Test 5: Devices object not empty"
devices_count=$(python3 << EOF
import json
with open('$DEVICES_JSON') as f:
    data = json.load(f)
    devices = data.get('devices', {})
    print(len(devices))
EOF
)

if (( devices_count > 0 )); then
  echo "  PASS: Devices object contains $devices_count device(s)"
  ((pass++))
else
  echo "  FAIL: Devices object is empty"
  ((fail++))
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================================================"
echo "Results: $pass passed, $fail failed"
echo "============================================================================"

[[ $fail -eq 0 ]] || exit 1
