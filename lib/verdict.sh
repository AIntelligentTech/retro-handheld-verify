#!/bin/bash
# verdict.sh - Combines signals from detection modules into a final verdict
# This module should be sourced, not executed directly

set -o pipefail

# Source platform.sh (required for base functionality)
_VERDICT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${_VERDICT_DIR}/platform.sh" || {
    echo "ERROR: Failed to source platform.sh" >&2
    return 1
}

# Global variables set by compute_verdict
VERDICT=""
VERDICT_CONFIDENCE=""
VERDICT_SIGNALS=""
VERDICT_NOTES=""

# compute_verdict
# Analyzes all detection module globals to produce a final verdict
# Expects these globals to be set by detection modules:
#   - BOOTLOADER_TYPE, BOOTLOADER_CONFIDENCE
#   - SOC_VENDOR, SOC_MODEL, SOC_CONFIDENCE
#   - DTB_COUNT, DTB_FILES
#   - PARTITION_TYPES
#   - DISK_SIZE_BYTES, DISK_READ_SPEED
# Sets globals:
#   - VERDICT: GA36_CLONE, ALLWINNER_UNKNOWN, ROCKCHIP, AMLOGIC, UNKNOWN
#   - VERDICT_CONFIDENCE: high, medium, low, none
#   - VERDICT_SIGNALS: newline-separated signal list with confidence
#   - VERDICT_NOTES: any caveats or notes
compute_verdict() {
    local signals=()
    local signal_strength=0

    # Initialize output variables
    VERDICT="UNKNOWN"
    VERDICT_CONFIDENCE="none"
    VERDICT_SIGNALS=""
    VERDICT_NOTES=""

    # Validate bootloader signals
    if [[ -n "${BOOTLOADER_TYPE}" && "${BOOTLOADER_TYPE}" != "unknown" ]]; then
        signals+=("Bootloader: ${BOOTLOADER_TYPE} (${BOOTLOADER_CONFIDENCE})")
        if [[ "${BOOTLOADER_CONFIDENCE}" == "verified" ]]; then
            signal_strength=$((signal_strength + 2))
        elif [[ "${BOOTLOADER_CONFIDENCE}" == "unverified" ]]; then
            signal_strength=$((signal_strength + 1))
        fi
    fi

    # Validate SoC signals
    if [[ -n "${SOC_VENDOR}" && "${SOC_VENDOR}" != "unknown" ]]; then
        signals+=("SoC: ${SOC_VENDOR} ${SOC_MODEL} (${SOC_CONFIDENCE})")
        if [[ "${SOC_CONFIDENCE}" == "verified" ]]; then
            signal_strength=$((signal_strength + 2))
        elif [[ "${SOC_CONFIDENCE}" == "unverified" ]]; then
            signal_strength=$((signal_strength + 1))
        fi
    fi

    # Validate partition signals
    if [[ -n "${PARTITION_TYPES}" ]]; then
        local partition_summary="${PARTITION_TYPES}"
        signals+=("Partitions: ${partition_summary}")
    fi

    # Validate DTB signals
    if [[ ${DTB_COUNT} -gt 0 ]]; then
        signals+=("DTB files: ${DTB_COUNT} found")
    fi

    # Validate disk signals
    if [[ ${DISK_SIZE_BYTES} -gt 0 ]]; then
        local size_gb
        size_gb=$(echo "scale=1; ${DISK_SIZE_BYTES} / 1073741824" | bc 2>/dev/null || echo "unknown")
        signals+=("Disk: ${size_gb} GB, ${DISK_READ_SPEED} MB/s")
    fi

    # Build VERDICT_SIGNALS output
    if [[ ${#signals[@]} -gt 0 ]]; then
        VERDICT_SIGNALS=$(printf '%s\n' "${signals[@]}")
    fi

    # Decision tree: produce verdict
    if [[ "${BOOTLOADER_TYPE}" == "allwinner_egon" ]]; then
        if [[ "${SOC_MODEL}" == "A33" ]]; then
            # Allwinner EGON + A33 = GA36 clone with high confidence
            VERDICT="GA36_CLONE"
            VERDICT_CONFIDENCE="high"
        else
            # Allwinner EGON + other SoC = unknown Allwinner
            VERDICT="ALLWINNER_UNKNOWN"
            VERDICT_CONFIDENCE="medium"
        fi
    elif [[ "${BOOTLOADER_TYPE}" == "rockchip_idb" ]]; then
        VERDICT="ROCKCHIP"
        VERDICT_CONFIDENCE="low"
        VERDICT_NOTES="Rockchip detection is documented but unverified"
    elif [[ "${SOC_VENDOR}" == "amlogic" ]]; then
        VERDICT="AMLOGIC"
        VERDICT_CONFIDENCE="low"
        VERDICT_NOTES="Amlogic detection is unverified"
    else
        VERDICT="UNKNOWN"
        VERDICT_CONFIDENCE="none"
    fi

    return 0
}
