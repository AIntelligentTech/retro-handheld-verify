#!/bin/bash
# Detects and hashes Device Tree Blob (DTB) files on mounted partitions
# Sources: lib/platform.sh for platform detection utilities

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/platform.sh"

# Global variables set by detection functions
DTB_FILES=""
DTB_COUNT=0
DTB_NOTE="No verified DTB fingerprints in database. Hashes reported for community reference only."

# detect_dtb DEVICE
# Discovers DTB files on mounted partitions and hashes them
# Args:
#   DEVICE: device path (e.g., /dev/sda, /dev/mmcblk0)
# Sets globals: DTB_FILES, DTB_COUNT, DTB_NOTE
detect_dtb() {
  local device="$1"
  local mounted_partitions=()
  local dtb_found=()
  local count=0

  # Validate device
  if [[ -z "${device}" ]]; then
    DTB_FILES=""
    DTB_COUNT=0
    return 1
  fi

  # Find mounted partitions for this device
  if [[ "${PLATFORM}" == "macos" ]]; then
    mounted_partitions=( $(mount | grep "^${device}" | awk '{print $3}') )
  elif [[ "${PLATFORM}" == "linux" ]]; then
    mounted_partitions=( $(lsblk -no MOUNTPOINT "${device}" 2>/dev/null | grep -v "^$") )
  fi

  # If no mounted partitions, try searching raw boot area for DTB magic bytes
  if [[ ${#mounted_partitions[@]} -eq 0 ]]; then
    _search_dtb_magic "${device}"
    return $?
  fi

  # Search each mounted partition for DTB files
  for mount_point in "${mounted_partitions[@]}"; do
    if [[ -d "${mount_point}" ]]; then
      while IFS= read -r dtb_file; do
        if [[ -f "${dtb_file}" ]]; then
          local hash
          hash=$(plat_md5 "${dtb_file}" 2>/dev/null)
          if [[ $? -eq 0 && -n "${hash}" ]]; then
            dtb_found+=("${dtb_file}:${hash}")
            ((count++))
          fi
        fi
      done < <(find "${mount_point}" -name "*.dtb" -type f 2>/dev/null)
    fi
  done

  # Set global variables
  DTB_FILES="${dtb_found[*]}"
  DTB_COUNT=$count

  return 0
}

# _search_dtb_magic DEVICE
# Internal function to search for DTB magic bytes (0xd00dfeed) in raw boot area
# If found, attempts to extract and hash DTB content
# Sets globals: DTB_FILES, DTB_COUNT, DTB_NOTE
_search_dtb_magic() {
  local device="$1"
  local dtb_found=()
  local count=0
  local boot_size=$((10 * 1024 * 1024))  # Search first 10MB
  local search_step=$((1024 * 1024))     # Search every 1MB
  local magic_hex="d00dfeed"
  local offset=0

  # Read boot area and search for DTB magic bytes
  local boot_data
  boot_data=$(plat_readbytes "${device}" 0 "${boot_size}" 2>/dev/null | xxd -p)

  if [[ -z "${boot_data}" ]]; then
    DTB_FILES=""
    DTB_COUNT=0
    return 1
  fi

  # Search for DTB magic in hex string
  local search_pos=0
  while [[ ${search_pos} -lt ${#boot_data} ]]; do
    local hex_chunk="${boot_data:${search_pos}:8}"
    if [[ "${hex_chunk}" == "${magic_hex}" ]]; then
      # Found DTB magic at this position
      local byte_offset=$((search_pos / 2))
      dtb_found+=("raw@${byte_offset}:magic_found")
      ((count++))
    fi
    ((search_pos += 2))  # Move 1 byte (2 hex chars)
  done

  # Set global variables
  DTB_FILES="${dtb_found[*]}"
  DTB_COUNT=$count

  return 0
}
