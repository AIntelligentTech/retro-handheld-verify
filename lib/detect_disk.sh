#!/bin/bash
# Detects disk metadata and measures read speed
# Sources: lib/platform.sh for platform detection utilities

set -o pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/platform.sh"

# Global variables set by detection functions
DISK_SIZE_BYTES=0
DISK_SIZE_HUMAN=""
DISK_READ_SPEED=0
DISK_MODEL="unknown"

# detect_disk DEVICE
# Gathers disk metadata and measures sequential read speed
# Args:
#   DEVICE: device path (e.g., /dev/sda, /dev/mmcblk0)
# Sets globals: DISK_SIZE_BYTES, DISK_SIZE_HUMAN, DISK_READ_SPEED, DISK_MODEL
detect_disk() {
  local device="$1"

  # Validate device
  if [[ -z "${device}" ]]; then
    DISK_SIZE_BYTES=0
    DISK_SIZE_HUMAN=""
    DISK_READ_SPEED=0
    DISK_MODEL="unknown"
    return 1
  fi

  # Get disk size in bytes
  DISK_SIZE_BYTES=$(plat_diskinfo "${device}" 2>/dev/null)
  if [[ $? -ne 0 || -z "${DISK_SIZE_BYTES}" ]]; then
    DISK_SIZE_BYTES=0
    DISK_SIZE_HUMAN=""
    DISK_READ_SPEED=0
    DISK_MODEL="unknown"
    return 1
  fi

  # Convert size to human readable format
  _format_disk_size "${DISK_SIZE_BYTES}"

  # Get disk model
  _get_disk_model "${device}"

  # Measure read speed
  DISK_READ_SPEED=$(plat_readspeed "${device}" 2>/dev/null)
  if [[ $? -ne 0 || -z "${DISK_READ_SPEED}" ]]; then
    DISK_READ_SPEED=0
  fi

  return 0
}

# _format_disk_size BYTES
# Internal function to convert bytes to human readable format
# Args:
#   BYTES: size in bytes
# Sets globals: DISK_SIZE_HUMAN
_format_disk_size() {
  local bytes="$1"

  if [[ -z "${bytes}" || ${bytes} -eq 0 ]]; then
    DISK_SIZE_HUMAN=""
    return 1
  fi

  # If greater than 1GB, show in GB
  if [[ ${bytes} -gt $((1024 * 1024 * 1024)) ]]; then
    local gb
    gb=$(echo "scale=1; ${bytes} / (1024 * 1024 * 1024)" | bc)
    DISK_SIZE_HUMAN="${gb} GB"
  else
    # Otherwise show in MB
    local mb
    mb=$(echo "scale=1; ${bytes} / (1024 * 1024)" | bc)
    DISK_SIZE_HUMAN="${mb} MB"
  fi

  return 0
}

# _get_disk_model DEVICE
# Internal function to retrieve disk model string
# Uses diskutil on macOS, udevadm on Linux
# Args:
#   DEVICE: device path
# Sets globals: DISK_MODEL
_get_disk_model() {
  local device="$1"
  local model=""

  case "${PLATFORM}" in
    macos)
      # Use diskutil to get disk model on macOS
      model=$(diskutil info "${device}" 2>/dev/null | grep "Device / Media Name:" | sed 's/^.*: //')
      if [[ -z "${model}" ]]; then
        model=$(diskutil info "${device}" 2>/dev/null | grep "Disk Identifier:" | sed 's/^.*: //')
      fi
      ;;
    linux)
      # Use udevadm to get disk model on Linux
      if command -v udevadm &> /dev/null; then
        model=$(udevadm info --query=all --name="${device}" 2>/dev/null | grep "ID_MODEL=" | sed 's/ID_MODEL=//')
      fi
      # Fallback to reading from sysfs
      if [[ -z "${model}" ]]; then
        local devname
        devname=$(basename "${device}")
        if [[ -f "/sys/block/${devname}/device/model" ]]; then
          model=$(cat "/sys/block/${devname}/device/model" 2>/dev/null)
        fi
      fi
      ;;
  esac

  if [[ -n "${model}" ]]; then
    DISK_MODEL="${model}"
  else
    DISK_MODEL="unknown"
  fi

  return 0
}
