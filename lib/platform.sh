#!/bin/bash
# platform.sh - Cross-platform abstraction layer for macOS and Linux
# Provides unified interface for device operations, hashing, and system checks

set -o pipefail

# Platform detection (preserve if already set by a prior source)
PLATFORM="${PLATFORM:-}"

# plat_init - Detect platform and validate required tools
plat_init() {
    local uname_output
    uname_output=$(uname -s)

    case "${uname_output}" in
        Darwin)
            PLATFORM="macos"
            ;;
        Linux)
            PLATFORM="linux"
            ;;
        *)
            echo "ERROR: Unsupported platform: ${uname_output}" >&2
            return 1
            ;;
    esac

    # Validate required tools exist
    local required_tools=("dd" "strings" "xxd")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "ERROR: Missing required tools: ${missing_tools[*]}" >&2
        return 1
    fi

    # Validate md5 tools
    case "${PLATFORM}" in
        macos)
            if ! command -v md5 &> /dev/null; then
                echo "ERROR: md5 command not found on macOS" >&2
                return 1
            fi
            ;;
        linux)
            if ! command -v md5sum &> /dev/null; then
                echo "ERROR: md5sum command not found on Linux" >&2
                return 1
            fi
            ;;
    esac

    return 0
}

# plat_requires_root - Check if running as root/sudo
plat_requires_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "ERROR: This operation requires root privileges" >&2
        return 1
    fi
    return 0
}

# plat_check_device - Verify device exists and is a block device
# Args: DEVICE
# Returns: 0 if valid, 1 if invalid
plat_check_device() {
    local device="$1"

    if [[ -z "${device}" ]]; then
        echo "ERROR: Device path not provided" >&2
        return 1
    fi

    case "${PLATFORM}" in
        macos)
            # On macOS, check for character device (raw device)
            if [[ ! -c "${device}" ]]; then
                echo "ERROR: Device ${device} does not exist or is not a character device" >&2
                return 1
            fi
            ;;
        linux)
            # On Linux, check for block device
            if [[ ! -b "${device}" ]]; then
                echo "ERROR: Device ${device} does not exist or is not a block device" >&2
                return 1
            fi
            ;;
    esac

    return 0
}

# plat_readbytes - Read raw bytes from device
# Args: DEVICE SKIP_BYTES COUNT
# Returns: raw bytes on stdout
plat_readbytes() {
    local device="$1"
    local skip_bytes="$2"
    local count="$3"

    if [[ -z "${device}" || -z "${skip_bytes}" || -z "${count}" ]]; then
        echo "ERROR: plat_readbytes requires DEVICE SKIP_BYTES COUNT" >&2
        return 1
    fi

    # Use block-aligned reads where possible for performance
    # bs=1 is catastrophically slow for large reads
    if (( count >= 4096 && skip_bytes % 4096 == 0 )); then
        dd if="${device}" bs=4096 skip="$((skip_bytes / 4096))" count="$((count / 4096))" 2>/dev/null
    elif (( count >= 512 && skip_bytes % 512 == 0 )); then
        dd if="${device}" bs=512 skip="$((skip_bytes / 512))" count="$((count / 512))" 2>/dev/null
    else
        dd if="${device}" bs=1 skip="${skip_bytes}" count="${count}" 2>/dev/null
    fi
    return $?
}

# plat_md5 - Calculate MD5 hash of file
# Args: FILE
# Returns: MD5 hash only (no filename)
plat_md5() {
    local file="$1"

    if [[ -z "${file}" ]]; then
        echo "ERROR: File path not provided" >&2
        return 1
    fi

    if [[ ! -f "${file}" ]]; then
        echo "ERROR: File ${file} does not exist" >&2
        return 1
    fi

    case "${PLATFORM}" in
        macos)
            md5 -q "${file}"
            ;;
        linux)
            md5sum "${file}" | awk '{print $1}'
            ;;
    esac

    return $?
}

# plat_strings - Extract strings from a device region
# Args: DEVICE OFFSET LENGTH
# Returns: strings from that region on stdout
plat_strings() {
    local device="$1"
    local offset="$2"
    local length="$3"

    if [[ -z "${device}" || -z "${offset}" || -z "${length}" ]]; then
        echo "ERROR: plat_strings requires DEVICE OFFSET LENGTH" >&2
        return 1
    fi

    dd if="${device}" bs=1 skip="${offset}" count="${length}" 2>/dev/null | strings
    return $?
}

# plat_diskinfo - Print disk size in bytes
# Args: DEVICE
# Returns: size in bytes on stdout
plat_diskinfo() {
    local device="$1"
    local size

    if [[ -z "${device}" ]]; then
        echo "ERROR: Device path not provided" >&2
        return 1
    fi

    case "${PLATFORM}" in
        macos)
            # On macOS, use diskutil to get size
            size=$(diskutil info "${device}" 2>/dev/null | grep "Disk Size:" | sed -E 's/.*\(([0-9]+) Bytes\).*/\1/')
            if [[ -z "${size}" ]]; then
                echo "ERROR: Could not determine disk size for ${device}" >&2
                return 1
            fi
            echo "${size}"
            ;;
        linux)
            # On Linux, use blockdev to get size in bytes
            if ! size=$(blockdev --getsize64 "${device}" 2>/dev/null); then
                echo "ERROR: Could not determine disk size for ${device}" >&2
                return 1
            fi
            echo "${size}"
            ;;
    esac

    return 0
}

# plat_readspeed - Read 10MB from device and report MB/s
# Args: DEVICE
# Returns: speed in MB/s on stdout
plat_readspeed() {
    local device="$1"
    local speed

    if [[ -z "${device}" ]]; then
        echo "ERROR: Device path not provided" >&2
        return 1
    fi

    # Use dd's own timing output to calculate speed
    local dd_output
    dd_output=$(dd if="${device}" bs=1048576 count=10 of=/dev/null 2>&1)
    # dd outputs something like "10485760 bytes transferred in 0.423197 secs (24778531 bytes/sec)"
    # or on Linux: "10485760 bytes (10 MB, 10 MiB) copied, 0.423 s, 24.8 MB/s"
    local bytes_per_sec
    bytes_per_sec=$(echo "${dd_output}" | grep -oE '[0-9]+ bytes/sec' | grep -oE '[0-9]+')
    if [[ -n "${bytes_per_sec}" ]]; then
        speed=$(echo "scale=2; ${bytes_per_sec} / 1048576" | bc)
    else
        # Try Linux format
        speed=$(echo "${dd_output}" | grep -oE '[0-9.]+ MB/s' | grep -oE '[0-9.]+')
    fi
    if [[ -z "${speed}" ]]; then
        speed="0"
    fi
    echo "${speed}"

    return 0
}

# Only run plat_init if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    plat_init
fi
