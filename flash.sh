#!/bin/bash

# Flash Buildroot SD card image to SD card
# Usage: ./flash.sh /dev/sdX

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default image path
IMAGE_PATH="output/images/sdcard.img"

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [-y] <device> [image_path]"
    echo ""
    echo "Options:"
    echo "  -y          Skip confirmation prompt (automatic yes)"
    echo ""
    echo "Arguments:"
    echo "  device      Path to SD card device (e.g., /dev/sdb, /dev/mmcblk0)"
    echo "  image_path  Path to image file (default: sdcard.img)"
    echo ""
    echo "Examples:"
    echo "  $0 /dev/sdb"
    echo "  $0 /dev/mmcblk0 output/images/sdcard.img"
    echo "  $0 -y /dev/sdb sdcard.img"
    exit 1
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if device is removable (likely SD card or USB)
is_removable() {
    local device=$1
    local device_name=$(basename "$device")
    
    # For mmcblk devices, check the device itself
    if [[ "$device_name" =~ ^mmcblk[0-9]+p?[0-9]*$ ]]; then
        device_name=$(echo "$device_name" | sed 's/p[0-9]*$//')
    fi
    
    # For sd devices, remove partition number
    if [[ "$device_name" =~ ^sd[a-z][0-9]*$ ]]; then
        device_name=$(echo "$device_name" | sed 's/[0-9]*$//')
    fi
    
    # Check if removable flag is set
    local removable_file="/sys/block/${device_name}/removable"
    if [ -f "$removable_file" ]; then
        local removable=$(cat "$removable_file")
        if [ "$removable" = "1" ]; then
            return 0  # Is removable
        fi
    fi
    
    # Additional check: SD cards often show up in specific subsystems
    local device_path="/sys/block/${device_name}/device"
    if [ -d "$device_path" ]; then
        # Check if it's an MMC/SD device
        if readlink -f "$device_path" | grep -q "mmc"; then
            return 0  # Is MMC/SD device
        fi
        
        # Check if it's a USB device
        if readlink -f "$device_path" | grep -q "usb"; then
            return 0  # Is USB device (could be USB card reader)
        fi
    fi
    
    return 1  # Not removable
}

# Get human-readable device info
get_device_info() {
    local device=$1
    local device_name=$(basename "$device")
    
    # Remove partition number if present
    if [[ "$device_name" =~ ^mmcblk[0-9]+p?[0-9]*$ ]]; then
        device_name=$(echo "$device_name" | sed 's/p[0-9]*$//')
    elif [[ "$device_name" =~ ^sd[a-z][0-9]*$ ]]; then
        device_name=$(echo "$device_name" | sed 's/[0-9]*$//')
    fi
    
    # Get model and size info
    local model_file="/sys/block/${device_name}/device/model"
    local size_file="/sys/block/${device_name}/size"
    
    local model="Unknown"
    local size_bytes=0
    
    if [ -f "$model_file" ]; then
        model=$(cat "$model_file" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    
    if [ -f "$size_file" ]; then
        # Size is in 512-byte sectors
        size_bytes=$(($(cat "$size_file") * 512))
    fi
    
    # Convert to GB
    local size_gb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1024/1024/1024}")
    
    echo "Model: $model, Size: ${size_gb}GB"
}

# Validate device path
validate_device() {
    local device=$1
    
    # Check if device exists
    if [ ! -b "$device" ]; then
        print_error "Device $device does not exist or is not a block device"
        exit 1
    fi
    
    # Get device information
    local device_info=$(get_device_info "$device")
    print_info "Device info: $device_info"
    
    # Check if device is removable (SD card or USB)
    if ! is_removable "$device"; then
        print_error "Device $device does not appear to be a removable device (SD card or USB)"
        print_error "This safety check prevents accidentally flashing internal drives"
        print_warning "If you are certain this is correct, you can modify the script to bypass this check"
        exit 1
    fi
    
    print_success "Device $device appears to be a removable device (SD card/USB)"
}

# Validate image file
validate_image() {
    local image=$1
    
    if [ ! -f "$image" ]; then
        print_error "Image file $image does not exist"
        exit 1
    fi
    
    if [ ! -r "$image" ]; then
        print_error "Image file $image is not readable"
        exit 1
    fi
}

# Unmount all partitions of the device
unmount_device() {
    local device=$1
    
    print_info "Checking for mounted partitions on $device..."
    
    # Handle both /dev/sdX and /dev/mmcblkX naming schemes
    if [[ "$device" == *"mmcblk"* ]] || [[ "$device" == *"loop"* ]]; then
        # For mmcblk devices, partitions are named like mmcblk0p1, mmcblk0p2
        partitions=$(lsblk -ln -o NAME "$device" | tail -n +2 | sed "s|^|/dev/|")
    else
        # For sd devices, partitions are named like sdb1, sdb2
        partitions=$(lsblk -ln -o NAME "$device" | tail -n +2 | sed "s|^|/dev/|")
    fi
    
    # Unmount each partition
    for partition in $partitions; do
        if mountpoint -q "$partition" 2>/dev/null || grep -qs "$partition" /proc/mounts; then
            print_info "Unmounting $partition..."
            if ! umount "$partition" 2>/dev/null; then
                print_warning "Failed to unmount $partition, trying lazy unmount..."
                umount -l "$partition" || true
            fi
        fi
    done
    
    # Give the system a moment to release the device
    sleep 1
    
    print_success "All partitions unmounted"
}

# Flash the image
flash_image() {
    local device=$1
    local image=$2
    
    # Perform the flash operation
    print_info "Writing image..."
    if command -v pv &> /dev/null; then
        # Use pv for progress if available
        pv "$image" | dd of="$device" bs=4M conv=fsync status=none
    else
        # Fall back to dd with progress
        dd if="$image" of="$device" bs=4M conv=fsync status=progress
    fi
    
    # Ensure all data is written
    print_info "Syncing filesystem..."
    sync
    
    print_success "Image successfully flashed to $device!"
}

# Main script execution
main() {
    local skip_confirm="no"
    local device=""
    local image=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y)
                skip_confirm="yes"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                if [ -z "$device" ]; then
                    device=$1
                elif [ -z "$image" ]; then
                    image=$1
                else
                    print_error "Too many arguments"
                    usage
                fi
                shift
                ;;
        esac
    done
    
    # Check if device was provided
    if [ -z "$device" ]; then
        usage
    fi
    
    # Set default image if not provided
    image=${image:-$IMAGE_PATH}
    
    print_info "================================"
    print_info "Buildroot SD Card Flash Script"
    print_info "================================"
    print_info "Device: $device"
    print_info "Image:  $image"
    print_info ""
    
    # Run checks
    check_root
    validate_device "$device"
    validate_image "$image"
    
    # Get user confirmation before unmounting
    # (unmount will happen in flash_image after confirmation)
    local image_size=$(stat -c%s "$image")
    local image_size_mb=$((image_size / 1024 / 1024))
    
    print_info "Ready to flash $image (${image_size_mb} MB) to $device"
    print_warning "This will DESTROY all data on $device!"
    
    if [ "$skip_confirm" != "yes" ]; then
        read -p "Continue? [y/N] " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Aborted by user"
            exit 0
        fi
    else
        print_info "Skipping confirmation due to -y flag"
    fi
    
    # Now unmount the device after confirmation
    unmount_device "$device"
    
    # Flash image
    flash_image "$device" "$image"
    
    print_info ""
    print_success "✓ Flashing complete!"
    print_info "You can now safely remove the SD card"
}

# Run main function
main "$@"
