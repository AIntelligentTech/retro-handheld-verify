#!/bin/bash
# verify.sh - Main entry point for retro-handheld SD card verification
# Usage: verify.sh [--json] DEVICE

set -o pipefail

# Configuration
VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_OUTPUT=false
DEVICE=""

# Function to display usage
show_usage() {
    cat << 'USAGE'
Retro Handheld SD Card Verifier v0.1.0

Usage: verify.sh [--json] DEVICE

Arguments:
  DEVICE     Device path (e.g., /dev/sda, /dev/disk0, /dev/mmcblk0)
  --json     Output results in JSON format
  --help     Show this help message

Examples:
  # Human-readable output
  verify.sh /dev/disk0

  # JSON output
  verify.sh --json /dev/disk0

  # On Linux with root
  sudo verify.sh /dev/sda
USAGE
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "${DEVICE}" ]]; then
                DEVICE="$1"
            else
                echo "ERROR: Multiple devices specified" >&2
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Show usage if no device provided
if [[ -z "${DEVICE}" ]]; then
    show_usage
    exit 1
fi

# Function to output human-readable results
output_human() {
    local verdict_icon=""
    case "${VERDICT}" in
        GA36_CLONE)
            verdict_icon="✓"
            ;;
        *)
            verdict_icon="○"
            ;;
    esac

    printf '%s\n' "═══════════════════════════════════════════════════════"
    printf '%s\n' "  Retro Handheld SD Card Verifier v0.1.0"
    printf '%s\n' "═══════════════════════════════════════════════════════"
    printf '\n'
    printf '%s\n' "VERDICT: ${verdict_icon} ${VERDICT} (confidence: ${VERDICT_CONFIDENCE})"
    if [[ -n "${VERDICT_NOTES}" ]]; then
        printf '%s\n' "Note: ${VERDICT_NOTES}"
    fi
    printf '\n'

    # Bootloader section
    printf '%s\n' "─── Bootloader ───────────────────────────────────────"
    printf '%s\n' "  Type:       ${BOOTLOADER_TYPE:-unknown}"
    printf '%s\n' "  Magic:      ${BOOTLOADER_MAGIC:-N/A}"
    printf '%s\n' "  Confidence: ${BOOTLOADER_CONFIDENCE:-none}"
    printf '\n'

    # SoC section
    printf '%s\n' "─── SoC ──────────────────────────────────────────────"
    printf '%s\n' "  Vendor:     ${SOC_VENDOR:-unknown}"
    printf '%s\n' "  Model:      ${SOC_MODEL:-unknown}"
    printf '%s\n' "  Confidence: ${SOC_CONFIDENCE:-none}"
    if [[ -n "${UBOOT_VERSION}" && "${UBOOT_VERSION}" != "unknown" ]]; then
        printf '%s\n' "  U-Boot:     ${UBOOT_VERSION}"
    fi
    printf '\n'

    # DTB section
    printf '%s\n' "─── DTB Files ────────────────────────────────────────"
    printf '%s\n' "  Found: ${DTB_COUNT}"
    if [[ ${DTB_COUNT} -eq 0 ]]; then
        printf '%s\n' "  Note: No verified DTB fingerprints in database"
    else
        printf '%s\n' "  Files: ${DTB_FILES}"
    fi
    printf '\n'

    # Disk section
    printf '%s\n' "─── Disk ─────────────────────────────────────────────"
    if [[ ${DISK_SIZE_BYTES} -gt 0 ]]; then
        local size_gb
        size_gb=$(echo "scale=1; ${DISK_SIZE_BYTES} / 1073741824" | bc 2>/dev/null || printf "%.1f" "$(echo "${DISK_SIZE_BYTES} / 1073741824" | awk '{printf "%.1f", $0}')")
        printf '%s\n' "  Size:       ${size_gb} GB"
    else
        printf '%s\n' "  Size:       unknown"
    fi
    printf '%s\n' "  Read Speed: ${DISK_READ_SPEED:-unknown} MB/s"
    if [[ -n "${DISK_MODEL}" && "${DISK_MODEL}" != "unknown" ]]; then
        printf '%s\n' "  Model:      ${DISK_MODEL}"
    fi
    printf '\n'

    # Partitions section
    printf '%s\n' "─── Partitions ───────────────────────────────────────"
    printf '%s\n' "  Types: ${PARTITION_TYPES:-none detected}"
    printf '%s\n' "  Count: ${PARTITION_COUNT}"
    printf '\n'

    printf '%s\n' "═══════════════════════════════════════════════════════"
}

# Function to output JSON results
output_json() {
    # Use printf to build JSON (no jq dependency)
    printf '{'
    printf '"verdict":"%s",' "${VERDICT}"
    printf '"confidence":"%s",' "${VERDICT_CONFIDENCE}"
    printf '"notes":"%s",' "${VERDICT_NOTES}"
    printf '"bootloader":{'
    printf '"type":"%s",' "${BOOTLOADER_TYPE}"
    printf '"magic":"%s",' "${BOOTLOADER_MAGIC}"
    printf '"confidence":"%s"' "${BOOTLOADER_CONFIDENCE}"
    printf '},'
    printf '"soc":{'
    printf '"vendor":"%s",' "${SOC_VENDOR}"
    printf '"model":"%s",' "${SOC_MODEL}"
    printf '"confidence":"%s",' "${SOC_CONFIDENCE}"
    printf '"uboot_version":"%s"' "${UBOOT_VERSION}"
    printf '},'
    printf '"dtb":{'
    printf '"count":%d,' "${DTB_COUNT}"
    printf '"files":"%s"' "${DTB_FILES}"
    printf '},'
    printf '"disk":{'
    printf '"size_bytes":%d,' "${DISK_SIZE_BYTES}"
    printf '"size_gb":"%.1f",' "$(echo "scale=1; ${DISK_SIZE_BYTES} / 1073741824" | bc 2>/dev/null || echo 0)"
    printf '"read_speed_mbps":"%s",' "${DISK_READ_SPEED}"
    printf '"model":"%s"' "${DISK_MODEL}"
    printf '},'
    printf '"partitions":{'
    printf '"count":%d,' "${PARTITION_COUNT}"
    printf '"types":"%s"' "${PARTITION_TYPES}"
    printf '}'
    printf '}'
}

# === Main execution ===

# Source platform.sh and validate environment
source "${VERIFY_DIR}/lib/platform.sh" || {
    echo "ERROR: Failed to source platform.sh" >&2
    exit 1
}

# Initialize platform
if ! plat_init; then
    echo "ERROR: Failed to initialize platform" >&2
    exit 1
fi

# Check if root is required and available
if ! plat_requires_root; then
    echo "ERROR: This tool requires root/sudo privileges to access the device" >&2
    exit 1
fi

# Convert /dev/diskN to /dev/rdiskN on macOS for raw access
if [[ "${PLATFORM}" == "macos" && "${DEVICE}" =~ ^/dev/disk[0-9]+$ ]]; then
    DEVICE="/dev/r${DEVICE#/dev/}"
fi

# Verify device exists and is accessible
if ! plat_check_device "${DEVICE}"; then
    echo "ERROR: Device check failed for ${DEVICE}" >&2
    exit 1
fi

# Source all detection modules
source "${VERIFY_DIR}/lib/detect_bootloader.sh" || {
    echo "ERROR: Failed to source detect_bootloader.sh" >&2
    exit 1
}

source "${VERIFY_DIR}/lib/detect_strings.sh" || {
    echo "ERROR: Failed to source detect_strings.sh" >&2
    exit 1
}

source "${VERIFY_DIR}/lib/detect_dtb.sh" || {
    echo "ERROR: Failed to source detect_dtb.sh" >&2
    exit 1
}

source "${VERIFY_DIR}/lib/detect_disk.sh" || {
    echo "ERROR: Failed to source detect_disk.sh" >&2
    exit 1
}

source "${VERIFY_DIR}/lib/detect_partitions.sh" || {
    echo "ERROR: Failed to source detect_partitions.sh" >&2
    exit 1
}

# Run detection modules
if ! detect_bootloader "${DEVICE}"; then
    BOOTLOADER_TYPE="unknown"
    BOOTLOADER_CONFIDENCE="none"
fi

if ! detect_strings "${DEVICE}"; then
    SOC_VENDOR="unknown"
    SOC_MODEL="unknown"
    SOC_CONFIDENCE="none"
fi

if ! detect_dtb "${DEVICE}"; then
    DTB_COUNT=0
    DTB_FILES=""
fi

if ! detect_disk "${DEVICE}"; then
    DISK_SIZE_BYTES=0
    DISK_READ_SPEED="unknown"
fi

if ! detect_partitions "${DEVICE}"; then
    PARTITION_TYPES=""
    PARTITION_COUNT=0
fi

# Source verdict module and compute final verdict
source "${VERIFY_DIR}/lib/verdict.sh" || {
    echo "ERROR: Failed to source verdict.sh" >&2
    exit 1
}

if ! compute_verdict; then
    echo "ERROR: Failed to compute verdict" >&2
    exit 1
fi

# Output results
if [[ "${JSON_OUTPUT}" == "true" ]]; then
    output_json
else
    output_human
fi

exit 0
