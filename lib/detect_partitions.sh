#!/bin/bash
# Detects partition types from MBR
# Sources: lib/platform.sh for platform detection utilities

source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

# Global variables set by detection functions
PARTITION_TYPES=""
PARTITION_COUNT=0

# detect_partitions DEVICE
# Lists partition types from MBR on a live device
# Args:
#   DEVICE: device path (e.g., /dev/sda, /dev/mmcblk0)
# Sets globals: PARTITION_TYPES, PARTITION_COUNT
detect_partitions() {
  local device="$1"

  # Validate device
  if [[ ! -b "$device" && ! -c "$device" ]]; then
    PARTITION_TYPES=""
    PARTITION_COUNT=0
    return 1
  fi

  # Read MBR and parse partitions
  _parse_mbr_partitions "$device"
  return $?
}

# detect_partitions_from_file FILE
# Lists partition types from MBR in a file (for testing)
# Args:
#   FILE: path to file containing MBR (first 512 bytes)
# Sets globals: PARTITION_TYPES, PARTITION_COUNT
detect_partitions_from_file() {
  local file="$1"

  # Validate file
  if [[ ! -f "$file" ]]; then
    PARTITION_TYPES=""
    PARTITION_COUNT=0
    return 1
  fi

  # Read MBR and parse partitions
  _parse_mbr_partitions "$file"
  return $?
}

# _parse_mbr_partitions DEVICE_OR_FILE
# Internal function to parse partition table from MBR
# Reads first 512 bytes, extracts partition type bytes at offsets 450, 466, 482, 498
# Sets globals: PARTITION_TYPES, PARTITION_COUNT
_parse_mbr_partitions() {
  local source="$1"
  local mbr_hex
  local types=()
  local count=0

  # Read first 512 bytes as hex, remove newlines
  mbr_hex=$(xxd -p -l 512 "$source" 2>/dev/null | tr -d '\n')

  if [[ -z "$mbr_hex" || ${#mbr_hex} -lt 1024 ]]; then
    PARTITION_TYPES=""
    PARTITION_COUNT=0
    return 1
  fi

  # Parse partition table entries
  # Partition entries start at offset 446 (0x1BE)
  # Each entry is 16 bytes, type byte is at offset 4 within entry
  # Entry 1: offset 446 + 4 = 450 (type byte position)
  # Entry 2: offset 462 + 4 = 466 (type byte position)
  # Entry 3: offset 478 + 4 = 482 (type byte position)
  # Entry 4: offset 494 + 4 = 498 (type byte position)
  #
  # In hex string (2 chars per byte):
  # Offset 450 = character position 900
  # Offset 466 = character position 932
  # Offset 482 = character position 964
  # Offset 498 = character position 996

  local offsets=(900 932 964 996)

  for offset_char in "${offsets[@]}"; do
    # Extract 2-character hex pair (1 byte) from position offset_char
    local type_byte="${mbr_hex:$offset_char:2}"

    # Skip empty partitions (type 0x00)
    if [[ "$type_byte" != "00" && -n "$type_byte" ]]; then
      types+=("$(echo "$type_byte" | tr '[:lower:]' '[:upper:]')")
      ((count++))
    fi
  done

  # Set global variables
  PARTITION_TYPES="${types[*]}"
  PARTITION_COUNT=$count

  return 0
}
