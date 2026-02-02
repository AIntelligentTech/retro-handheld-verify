#!/bin/bash
# contribute.sh - Collect community device contributions
# Runs all detection modules against a device and outputs a structured JSON report
# suitable for submitting as a GitHub issue to add a new device to the database.
#
# Usage: contribute.sh DEVICE
#   DEVICE: Device path (e.g., /dev/disk2, /dev/sdb)
#
# Example: sudo ./contribute.sh /dev/disk2

set -o pipefail

# Script directory for sourcing lib modules
CONTRIBUTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${CONTRIBUTE_DIR}/lib"

# Global variables
DEVICE=""
DEVICE_CONVERTED=""
DEVICE_NAME=""
PURCHASE_SOURCE=""
DEVICE_NOTES=""

# Function to print usage
show_usage() {
    cat << 'USAGE'
Usage: contribute.sh DEVICE

Collect device information and generate a structured JSON report for community
contribution to the retro-handheld-verify database.

Arguments:
  DEVICE          Device path (e.g., /dev/disk2, /dev/sdb, /dev/mmcblk0)

Environment:
  This script requires root/sudo privileges to read device data.

Example:
  sudo ./contribute.sh /dev/disk2

The script will:
  1. Validate the device
  2. Prompt you for device information (name, purchase source, notes)
  3. Run all detection modules (bootloader, strings, DTB, disk, partitions)
  4. Output a JSON report suitable for GitHub issue submission

USAGE
}

# Function to convert macOS disk device to raw device
macos_to_raw_device() {
    local device="$1"
    if [[ "$device" =~ ^/dev/disk[0-9] ]]; then
        # Convert /dev/diskN to /dev/rdiskN
        device="${device/disk/rdisk}"
    fi
    echo "$device"
}

# Function to prompt user for device information
prompt_device_info() {
    echo ""
    echo "=== Device Information Collection ==="
    echo ""
    echo "Please provide information about this device:"
    echo ""

    # Device name
    read -rp "Device name (e.g., 'R36S', 'GA36', 'PSP 1000'): " DEVICE_NAME
    if [[ -z "$DEVICE_NAME" ]]; then
        DEVICE_NAME="unknown"
    fi

    # Purchase source
    read -rp "Where was it purchased? (e.g., 'AliExpress', 'Amazon', 'eBay'): " PURCHASE_SOURCE
    if [[ -z "$PURCHASE_SOURCE" ]]; then
        PURCHASE_SOURCE="unknown"
    fi

    # Additional notes
    read -rp "Any additional notes (optional, press Enter to skip): " DEVICE_NOTES
    if [[ -z "$DEVICE_NOTES" ]]; then
        DEVICE_NOTES=""
    fi
}

# Function to source a detection module and run detection function
run_detection_module() {
    local module_name="$1"
    local detect_func="$2"

    if [[ ! -f "${LIB_DIR}/${module_name}.sh" ]]; then
        echo "ERROR: Detection module ${module_name}.sh not found" >&2
        return 1
    fi

    # Source the module
    if ! source "${LIB_DIR}/${module_name}.sh"; then
        echo "ERROR: Failed to source ${module_name}.sh" >&2
        return 1
    fi

    # Run the detection function
    if ! "$detect_func" "$DEVICE_CONVERTED"; then
        # Function failed, but we continue with empty/default values
        return 0
    fi

    return 0
}

# Function to escape JSON string values
json_escape() {
    local value="$1"
    # Escape backslashes, quotes, newlines
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    echo "$value"
}

# Function to build JSON array from string
json_array_from_string() {
    local str="$1"
    local delimiter="${2:-' '}"

    if [[ -z "$str" ]]; then
        echo "[]"
        return
    fi

    local items=()
    IFS="$delimiter" read -ra items <<< "$str"

    printf '['
    local first=true
    for item in "${items[@]}"; do
        if [[ -z "$item" ]]; then
            continue
        fi
        if [[ "$first" == true ]]; then
            first=false
        else
            printf ','
        fi
        printf '"%s"' "$(json_escape "$item")"
    done
    printf ']'
}

# Function to output JSON report to stdout
output_json_report() {
    local current_date
    current_date=$(date +%Y-%m-%d)

    # Build JSON output using printf
    printf '{\n'
    printf '  "device_report": {\n'
    printf '    "name": "%s",\n' "$(json_escape "$DEVICE_NAME")"
    printf '    "purchase_source": "%s",\n' "$(json_escape "$PURCHASE_SOURCE")"
    printf '    "notes": "%s",\n' "$(json_escape "$DEVICE_NOTES")"
    printf '    "date": "%s",\n' "$current_date"
    printf '    "reporter": "anonymous"\n'
    printf '  },\n'

    printf '  "signals": {\n'
    printf '    "bootloader_type": "%s",\n' "$(json_escape "$BOOTLOADER_TYPE")"
    printf '    "bootloader_magic": "%s",\n' "$(json_escape "$BOOTLOADER_MAGIC")"
    printf '    "bootloader_confidence": "%s",\n' "$(json_escape "$BOOTLOADER_CONFIDENCE")"
    printf '    "soc_vendor": "%s",\n' "$(json_escape "$SOC_VENDOR")"
    printf '    "soc_model": "%s",\n' "$(json_escape "$SOC_MODEL")"
    printf '    "soc_confidence": "%s",\n' "$(json_escape "$SOC_CONFIDENCE")"
    printf '    "uboot_version": "%s",\n' "$(json_escape "$UBOOT_VERSION")"
    printf '    "dtb_count": %d,\n' "$DTB_COUNT"
    printf '    "dtb_files": %s,\n' "$(json_array_from_string "$DTB_FILES" ' ')"
    printf '    "disk_size_bytes": %d,\n' "$DISK_SIZE_BYTES"
    printf '    "disk_size_human": "%s",\n' "$(json_escape "$DISK_SIZE_HUMAN")"
    printf '    "disk_read_speed": "%s",\n' "$(json_escape "$DISK_READ_SPEED")"
    printf '    "disk_model": "%s",\n' "$(json_escape "$DISK_MODEL")"
    printf '    "partition_types": "%s",\n' "$(json_escape "$PARTITION_TYPES")"
    printf '    "partition_count": %d\n' "$PARTITION_COUNT"
    printf '  }\n'
    printf '}\n'
}

# Main script logic
main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        return 1
    fi

    DEVICE="$1"

    # Source platform.sh first
    if [[ ! -f "${LIB_DIR}/platform.sh" ]]; then
        echo "ERROR: lib/platform.sh not found" >&2
        return 1
    fi

    if ! source "${LIB_DIR}/platform.sh"; then
        echo "ERROR: Failed to source platform.sh" >&2
        return 1
    fi

    # Initialize platform
    if ! plat_init; then
        echo "ERROR: Failed to initialize platform" >&2
        return 1
    fi

    # Check for root/sudo privileges
    if ! plat_requires_root; then
        echo "ERROR: This script requires root/sudo privileges to read device data" >&2
        return 1
    fi

    # Validate device exists
    if ! plat_check_device "$DEVICE"; then
        echo "ERROR: Device validation failed for $DEVICE" >&2
        return 1
    fi

    # Convert device path if on macOS
    if [[ "$PLATFORM" == "macos" ]]; then
        DEVICE_CONVERTED=$(macos_to_raw_device "$DEVICE")
        echo "Info: Converted device path from $DEVICE to $DEVICE_CONVERTED"
    else
        DEVICE_CONVERTED="$DEVICE"
    fi

    # Prompt user for device information
    prompt_device_info

    # Run detection modules
    echo ""
    echo "=== Running Detection Modules ==="
    echo ""

    echo "Running bootloader detection..."
    run_detection_module "detect_bootloader" "detect_bootloader" || true

    echo "Running string analysis..."
    run_detection_module "detect_strings" "detect_strings" || true

    echo "Running DTB detection..."
    run_detection_module "detect_dtb" "detect_dtb" || true

    echo "Running disk analysis..."
    run_detection_module "detect_disk" "detect_disk" || true

    echo "Running partition detection..."
    run_detection_module "detect_partitions" "detect_partitions" || true

    echo ""
    echo "=== Detection Complete ==="
    echo ""
    echo "JSON Report:"
    echo "============"

    # Output JSON report to stdout
    output_json_report

    return 0
}

# Execute main function
main "$@"
exit $?
