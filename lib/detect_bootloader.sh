#!/bin/bash
# Detects bootloader type by reading magic bytes from specific sectors
# Sources: lib/platform.sh for platform detection utilities

set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

# Global variables set by detection functions
BOOTLOADER_TYPE=""
BOOTLOADER_MAGIC=""
BOOTLOADER_CONFIDENCE=""

# detect_bootloader_from_file FILE SECTOR
# Detects bootloader type from a 512-byte sector file
# Args:
#   FILE: path to file or sector image
#   SECTOR: sector number (16 or 64)
# Sets globals: BOOTLOADER_TYPE, BOOTLOADER_MAGIC, BOOTLOADER_CONFIDENCE
detect_bootloader_from_file() {
  local file="$1"
  local sector="${2:-16}"

  # Validate inputs
  if [[ ! -f "$file" ]]; then
    BOOTLOADER_TYPE="unknown"
    BOOTLOADER_MAGIC=""
    BOOTLOADER_CONFIDENCE="none"
    return 1
  fi

  # Determine read offset within the file
  # If file is 512 bytes, it's a single sector dump — read at appropriate offset within it
  # If file is larger, treat as full disk image and seek to sector position
  local file_size
  file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

  local read_offset
  if (( file_size <= 512 )); then
    # Single sector file: for sector 16 check offset 4, for sector 64 check offset 0
    if [[ "$sector" == "16" ]]; then
      read_offset=4
    else
      read_offset=0
    fi
  else
    # Full disk image: seek to sector position
    if [[ "$sector" == "16" ]]; then
      read_offset=$(( 16 * 512 + 4 ))
    else
      read_offset=$(( 64 * 512 ))
    fi
  fi

  if (( file_size < read_offset + 4 )); then
    BOOTLOADER_TYPE="unknown"
    BOOTLOADER_MAGIC=""
    BOOTLOADER_CONFIDENCE="none"
    return 1
  fi

  # Extract magic bytes using xxd
  local magic_hex
  magic_hex=$(xxd -p -s "$read_offset" -l 4 "$file" 2>/dev/null | tr '[:lower:]' '[:upper:]')

  BOOTLOADER_MAGIC="$magic_hex"

  # Check for known bootloader signatures
  case "$magic_hex" in
    65474F4E)
      # Allwinner EGON bootloader (sector 16, offset 4)
      BOOTLOADER_TYPE="allwinner_egon"
      BOOTLOADER_CONFIDENCE="verified"
      ;;
    3B8CDCFC)
      # Rockchip IDB bootloader (sector 64, offset 0)
      BOOTLOADER_TYPE="rockchip_idb"
      BOOTLOADER_CONFIDENCE="unverified"
      # documented but never tested against real Rockchip hardware
      ;;
    *)
      BOOTLOADER_TYPE="unknown"
      BOOTLOADER_CONFIDENCE="none"
      ;;
  esac

  return 0
}

# detect_bootloader DEVICE
# Detects bootloader type from a live device
# Args:
#   DEVICE: device path (e.g., /dev/sda, /dev/mmcblk0)
# Sets globals: BOOTLOADER_TYPE, BOOTLOADER_MAGIC, BOOTLOADER_CONFIDENCE
detect_bootloader() {
  local device="$1"

  # Validate device
  if [[ ! -b "$device" && ! -c "$device" ]]; then
    BOOTLOADER_TYPE="unknown"
    BOOTLOADER_MAGIC=""
    BOOTLOADER_CONFIDENCE="none"
    return 1
  fi

  # Try sector 16 first (Allwinner EGON)
  # Use dd to read sector, then xxd to extract magic (xxd -s fails on raw devices on macOS)
  local magic_hex
  magic_hex=$(dd if="$device" bs=512 skip=16 count=1 2>/dev/null | xxd -p -s 4 -l 4 2>/dev/null | tr '[:lower:]' '[:upper:]')
  BOOTLOADER_MAGIC="$magic_hex"

  if [[ "$magic_hex" == "65474F4E" ]]; then
    BOOTLOADER_TYPE="allwinner_egon"
    BOOTLOADER_CONFIDENCE="verified"
    return 0
  fi

  # Try sector 64 (Rockchip IDB)
  magic_hex=$(dd if="$device" bs=512 skip=64 count=1 2>/dev/null | xxd -p -s 0 -l 4 2>/dev/null | tr '[:lower:]' '[:upper:]')
  BOOTLOADER_MAGIC="$magic_hex"

  if [[ "$magic_hex" == "3B8CDCFC" ]]; then
    BOOTLOADER_TYPE="rockchip_idb"
    BOOTLOADER_CONFIDENCE="unverified"
    # documented but never tested against real Rockchip hardware
    return 0
  fi

  # No known bootloader found
  BOOTLOADER_TYPE="unknown"
  BOOTLOADER_CONFIDENCE="none"
  return 1
}
