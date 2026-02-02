#!/bin/bash
# detect_strings.sh - Analyze boot area strings to identify SoC vendor and model
# Sources lib/platform.sh for platform-specific operations

set -o pipefail

# Source platform.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform.sh" || {
    echo "ERROR: Failed to source platform.sh" >&2
    return 1
}

# Global variables for detection results
SOC_VENDOR=""
SOC_MODEL=""
SOC_CONFIDENCE=""
UBOOT_VERSION=""
BOOT_STRINGS_RAW=""

# detect_strings_from_file FILE - Analyze a text file of pre-extracted strings
# Args: FILE - path to file containing strings (one per line)
# Returns: 0 on success, sets global variables
detect_strings_from_file() {
    local file="$1"

    if [[ -z "${file}" ]]; then
        echo "ERROR: File path not provided" >&2
        return 1
    fi

    if [[ ! -f "${file}" ]]; then
        echo "ERROR: File ${file} does not exist" >&2
        return 1
    fi

    # Initialize global variables
    SOC_VENDOR="unknown"
    SOC_MODEL="unknown"
    SOC_CONFIDENCE="unverified"
    UBOOT_VERSION="unknown"
    BOOT_STRINGS_RAW=""

    local matched_strings=()

    # Check for Allwinner A33 (VERIFIED)
    if grep -qF "[ND]A33" "${file}" || grep -q "sun8iw5" "${file}"; then
        SOC_VENDOR="allwinner"
        SOC_MODEL="A33"
        SOC_CONFIDENCE="verified"
        while IFS= read -r line; do
            matched_strings+=("$line")
        done < <(grep -F "[ND]A33" "${file}" 2>/dev/null; grep "sun8iw5" "${file}" 2>/dev/null)
    fi

    # Check for other Allwinner variants (UNVERIFIED)
    if [[ "${SOC_VENDOR}" != "allwinner" ]]; then
        if grep -q "AllWinner\|sunxi" "${file}"; then
            SOC_VENDOR="allwinner"
            
            # Try to identify specific model
            if grep -q "H700\|sun50iw6" "${file}"; then
                SOC_MODEL="H700"
                while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "H700\|sun50iw6" "${file}")
            elif grep -q "H616\|sun50iw9" "${file}"; then
                SOC_MODEL="H616"
                while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "H616\|sun50iw9" "${file}")
            elif grep -q "H3\|sun8iw7" "${file}"; then
                SOC_MODEL="H3"
                while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "H3\|sun8iw7" "${file}")
            else
                SOC_MODEL="unknown_allwinner"
            fi

            SOC_CONFIDENCE="unverified"
            while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "AllWinner\|sunxi" "${file}")
        fi
    fi

    # Check for Rockchip (UNVERIFIED)
    if [[ "${SOC_VENDOR}" != "allwinner" ]] && grep -q "rockchip\|rk3\|RK3" "${file}"; then
        SOC_VENDOR="rockchip"
        SOC_CONFIDENCE="unverified"
        while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "rockchip\|rk3\|RK3" "${file}")
        
        # Extract model number (RK3326, RK3566, RK3588, etc.)
        local model_match
        model_match=$(grep -oE "RK[0-9]{4,}" "${file}" | head -1)
        if [[ -n "${model_match}" ]]; then
            SOC_MODEL="${model_match}"
        else
            SOC_MODEL="unknown_rockchip"
        fi
    fi

    # Check for Amlogic (UNVERIFIED)
    if [[ "${SOC_VENDOR}" != "allwinner" && "${SOC_VENDOR}" != "rockchip" ]] && grep -q "amlogic\|aml_\|meson" "${file}"; then
        SOC_VENDOR="amlogic"
        SOC_CONFIDENCE="unverified"
        while IFS= read -r line; do matched_strings+=("$line"); done < <(grep "amlogic\|aml_\|meson" "${file}")
        SOC_MODEL="unknown_amlogic"
    fi

    # Check for U-Boot version
    local uboot_match
    uboot_match=$(grep -oE "U-Boot [0-9]+\.[0-9]+[^ ]*" "${file}" | head -1)
    if [[ -n "${uboot_match}" ]]; then
        UBOOT_VERSION="${uboot_match}"
        matched_strings+=("${uboot_match}")
    fi

    # Collect all matched strings, removing duplicates while preserving order
    local unique_strings=()
    local seen=()
    for str in "${matched_strings[@]}"; do
        if [[ ! " ${seen[*]} " == *" ${str} "* ]]; then
            unique_strings+=("${str}")
            seen+=("${str}")
        fi
    done

    # Store as newline-separated string
    if [[ ${#unique_strings[@]} -gt 0 ]]; then
        BOOT_STRINGS_RAW=$(printf '%s\n' "${unique_strings[@]}")
    else
        BOOT_STRINGS_RAW=""
    fi

    return 0
}

# detect_strings DEVICE - Extract strings from first 32MB of device, then analyze
# Args: DEVICE - device path to analyze
# Returns: 0 on success, sets global variables
detect_strings() {
    local device="$1"

    if [[ -z "${device}" ]]; then
        echo "ERROR: Device path not provided" >&2
        return 1
    fi

    # Verify device exists
    if ! plat_check_device "${device}"; then
        return 1
    fi

    # Extract strings from first 32MB using dd and strings
    local strings_output
    if ! strings_output=$(dd if="${device}" bs=1M count=32 2>/dev/null | strings); then
        echo "ERROR: Failed to read strings from ${device}" >&2
        return 1
    fi

    # Create temporary file for analysis
    local temp_file
    temp_file=$(mktemp) || {
        echo "ERROR: Failed to create temporary file" >&2
        return 1
    }

    echo "${strings_output}" > "${temp_file}"
    local result

    # Analyze the extracted strings
    detect_strings_from_file "${temp_file}"
    result=$?

    rm -f "${temp_file}"
    return ${result}
}

# Export functions for use as a library
export -f detect_strings_from_file
export -f detect_strings

