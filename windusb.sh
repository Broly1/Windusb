#!/usr/bin/env bash
#
# This script handles automated dependency resolution, GPT/FAT32 partitioning,
# and WIM splitting to bypass UEFI limitations.
#
# Author: Broly
# License: GNU General Public License v3.0
# Repository: https://github.com/broly/windusb

# -----------------------------------------------------------------------------
# Configuration & Global Constants
# -----------------------------------------------------------------------------

# Use mktemp to ensure unique, non-conflicting mount points in /tmp
USB_MOUNT_POINT=$(mktemp -d -t windusb_usb_XXXX)
ISO_MOUNT_DIR=$(mktemp -d -t windusb_iso_XXXX)

# State variables for user-selected hardware and source files
SELECTED_DRIVE=""
SELECTED_ISO_PATH=""

# Dependency manifests categorized by package manager
DEBIAN_PACKAGES=("curl" "rsync" "wget" "gdisk" "wimtools")
FEDORA_PACKAGES=("curl" "rsync" "wget" "gdisk" "wimlib-utils")
ARCH_PACKAGES=("curl" "rsync" "wget" "gptfdisk" "wimlib")

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Logs error messages to stderr and terminates the script with a non-zero status.
log_error() {
    local message="$1"
    printf "ERROR: %s\n" "$message" >&2
    exit 1
}

# Renders the ASCII branding banner.
banner() {

    cat <<"EOF"
              __                __                   __
             |  \              |  \                 |  \
 __   __   __ \▓▓_______   ____| ▓▓__    __  _______| ▓▓____
|  \ |  \ |  \  \       \ /      ▓▓  \  |  \/       \ ▓▓    \
| ▓▓ | ▓▓ | ▓▓ ▓▓ ▓▓▓▓▓▓▓\  ▓▓▓▓▓▓▓ ▓▓  | ▓▓  ▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓\
| ▓▓ | ▓▓ | ▓▓ ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓\▓▓    \| ▓▓  | ▓▓
| ▓▓_/ ▓▓_/ ▓▓ ▓▓ ▓▓  | ▓▓ ▓▓__| ▓▓ ▓▓__/ ▓▓_\▓▓▓▓▓▓\ ▓▓__/ ▓▓
 \▓▓   ▓▓   ▓▓ ▓▓ ▓▓  | ▓▓\▓▓    ▓▓\▓▓    ▓▓       ▓▓ ▓▓    ▓▓
  \▓▓▓▓▓\▓▓▓▓ \▓▓\▓▓   \▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓
  
EOF
}

# Ensures temporary mount points and directories are cleaned up on exit.
cleanup() {
    umount "$USB_MOUNT_POINT" 2>/dev/null
    umount "$ISO_MOUNT_DIR" 2>/dev/null
    rm -rf "$USB_MOUNT_POINT" "$ISO_MOUNT_DIR"
}

# -----------------------------------------------------------------------------
# User Interaction & Validation
# -----------------------------------------------------------------------------

# Elevates privileges to root if the script is run as a standard user.
get_root() {
    clear
    banner
    if (( EUID != 0 )); then
        printf "Administrative privileges required. Re-running with sudo...\n"
        exec sudo -- "$0" "$@"
    fi
}

# Scans for USB transport devices and prompts the user for selection.
get_the_drive() {
    local lines choice confirm
    while true; do
        clear
        banner
        printf "===============================================\n"
        printf "           Select USB Drive Source             \n"
        printf "===============================================\n\n"
        printf "Please select the USB drive from the following list:\n"
        readarray -t lines < <(
            lsblk -dpno NAME,SIZE,MODEL,VENDOR,TRAN | awk '$NF=="usb"'
        )
        if [[ ${#lines[@]} -eq 0 ]]; then
            printf "No USB drives detected.\n"
            read -r -p "Press Enter to refresh..."
            continue
        fi

        for i in "${!lines[@]}"; do
            printf "%d) %s\n" "$((i+1))" "${lines[i]}"
        done
        printf "r) Refresh\n"
        read -r -p "#? " choice

        if [[ "$choice" == "r" ]]; then
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#lines[@]} ]]; then
            SELECTED_DRIVE=$(awk '{print $1}' <<< "${lines[$((choice-1))]}")

            printf "\nYou selected: %s\n" "$SELECTED_DRIVE"
            printf "WARNING: ALL DATA ON THIS DRIVE WILL BE DESTROYED\n\n"
            printf "Type y or YES to confirm and format this drive: "
            read -r confirm

            case "${confirm^^}" in
                Y|YES)
                    break
                    ;;
                N|NO)
                    printf "Operation cancelled by user.\n"
                    exit 1
                    ;;
                *)
                    printf "Confirmation failed. Please type YES to continue or NO to cancel.\n"
                    sleep 2
                    ;;
            esac
        else
            printf "Invalid selection.\n"
            sleep 1
        fi
    done
}

# Validates and mounts the Windows ISO to verify source integrity.
get_the_iso() {
    local ISO_PATH
    local attached_loops loop

    while true; do
        clear
        banner
        printf "===============================================\n"
        printf "           Select Windows ISO Source           \n"
        printf "===============================================\n"
        read -r -p "Path to ISO (or drag & drop): " ISO_PATH

        # Clean string from quotes/whitespace
        ISO_PATH="$(printf '%s' "$ISO_PATH" | xargs | tr -d '"' | tr -d "'")"

        if [[ ! -f "$ISO_PATH" ]]; then
            printf "\nError: File not found: %s\n" "$ISO_PATH"
            read -rp "Press Enter to try again..."
            continue
        fi

        # Cleanup existing mounts/loops for the same ISO to prevent locking
        mountpoint -q "$ISO_MOUNT_DIR" && umount -l "$ISO_MOUNT_DIR"
        attached_loops=$(losetup -j "$ISO_PATH" 2>/dev/null | cut -d: -f1)
        for loop in $attached_loops; do losetup -d "$loop" 2>/dev/null; done

        # Verify the ISO contains actual Windows installation media
        if mount -o loop,ro "$ISO_PATH" "$ISO_MOUNT_DIR" 2>/dev/null; then
            if [[ -f "$ISO_MOUNT_DIR/sources/install.wim" ]] || [[ -f "$ISO_MOUNT_DIR/sources/install.esd" ]]; then
                printf "\nWindows ISO validated successfully.\n"
                SELECTED_ISO_PATH="$ISO_PATH"
                break
            else
                umount "$ISO_MOUNT_DIR" 2>/dev/null
                printf "\nError: ISO lacks 'install.wim/esd'. Not a valid Windows installer.\n"
                read -rp "Press Enter to try again..."
            fi
        else
            printf "\nError: Could not mount ISO image.\n"
            read -rp "Press Enter to try again..."
        fi
    done
}

# -----------------------------------------------------------------------------
# System Preparation & Formatting
# -----------------------------------------------------------------------------

# Detects OS and installs/updates latest binaries for required tools.
install_missing_packages() {
    local package
    clear
    banner
    printf "Installing dependencies...\n"

    if [[ -f /etc/debian_version ]]; then
        for package in "${DEBIAN_PACKAGES[@]}"; do
            if ! dpkg -s "$package" >/dev/null 2>&1; then
                if ! apt-get update || ! apt-get install -y "$package"; then
                    log_error "Failed to install $package"
                fi
            else
                printf "Package %s is already installed (APT).\n" "$package"
            fi
        done
    elif [[ -f /etc/fedora-release ]]; then
        for package in "${FEDORA_PACKAGES[@]}"; do
            if ! rpm -q "$package" >/dev/null 2>&1; then
                if ! dnf install -y "$package"; then
                    log_error "Failed to install $package"
                fi
            else
                printf "Package %s is already installed (DNF).\n" "$package"
            fi
        done
    elif [[ -f /etc/arch-release ]]; then
        for package in "${ARCH_PACKAGES[@]}"; do
            if ! pacman -Q "$package" >/dev/null 2>&1; then
                if ! pacman -Sy --noconfirm --needed "$package"; then
                    log_error "Failed to install $package"
                fi
            else
                printf "Package %s is already installed (Pacman).\n" "$package"
            fi
        done
    else
        log_error "Your distro is not supported!"
    fi
}

# Prepares the USB stick using GPT and a single FAT32 partition.
format_drive() {
    clear
    banner
    printf "Initializing %s with GPT and FAT32...\n" "$SELECTED_DRIVE"
    
    # Force unmount all existing partitions on the target drive
    umount "$SELECTED_DRIVE"* 2>/dev/null || true
    
    # Wipe existing signatures to prevent partition table conflicts
    wipefs -af "$SELECTED_DRIVE"
    sgdisk --zap-all "$SELECTED_DRIVE"

    # Create a new Microsoft Basic Data partition (Type 0700)
    sgdisk --new=1:0:0 --typecode=1:0700 "$SELECTED_DRIVE"
    partprobe "$SELECTED_DRIVE"
    sleep 2 # Allow kernel time to register partition changes

    # Format the first partition as FAT32
    mkfs.fat -F32 "${SELECTED_DRIVE}1" || log_error "FAT32 format failed."
    mount "${SELECTED_DRIVE}1" "$USB_MOUNT_POINT" || log_error "Mounting USB failed."
}

# -----------------------------------------------------------------------------
# Data Transfer & Finalization
# -----------------------------------------------------------------------------

# Calculates total 'dirty' memory in KB to estimate write progress.
get_dirty_kb() {
    grep -E "^(Dirty|Writeback):" /proc/meminfo | awk '{sum+=$2} END {print sum}'
}

# Core logic: Splits the WIM and syncs files.
extract_iso() {
    local cur_dirty prog rem initial_dirty

    [[ -z "$SELECTED_ISO_PATH" ]] && get_the_iso

    printf "Splitting install.wim into 3.4GB chunks...\n"
    mkdir -p "$USB_MOUNT_POINT/sources"
    wimlib-imagex split "$ISO_MOUNT_DIR/sources/install.wim" \
        "$USB_MOUNT_POINT/sources/install.swm" 3400 || log_error "WIM split failed."

    printf "Copying installer files (rsync)...\n"
    rsync -rltD --no-owner --no-group --modify-window=1 --info=progress2 \
        --exclude="sources/install.wim" \
        "$ISO_MOUNT_DIR/" "$USB_MOUNT_POINT/" || log_error "File copy failed."

    printf "\nFinalizing writes to disk (approximate progress shown)...\n"

    initial_dirty=$(get_dirty_kb)
    initial_dirty=$(( initial_dirty < 1024 ? 1024 : initial_dirty ))

    while :; do
        cur_dirty=$(get_dirty_kb)
        
        if (( cur_dirty <= 512 )); then
            printf "\r\033[KFinalizing... [99.9%%]"
            break
        fi

        prog=$(awk "BEGIN{p=92+((1-($cur_dirty/$initial_dirty))*7.8); if(p>99.8)p=99.8; if(p<92)p=92; printf \"%.1f\", p}")
        rem=$(awk "BEGIN{if($cur_dirty>1048576) printf \"%.2f GB\", $cur_dirty/1048576; else printf \"%.1f MB\", $cur_dirty/1024}")
        
        printf "\r\033[KFlushing Cache: %s remaining [%s%%]" "$rem" "$prog"
        sleep 0.1
    done

    umount "$USB_MOUNT_POINT" || log_error "Drive unmount failed."
    mountpoint -q "$ISO_MOUNT_DIR" && umount -l "$ISO_MOUNT_DIR"

    printf "\r\033[KFinalizing... 100%% Done!\n"
    printf "\nSuccess: Windows Installation Media is ready.\n"
}

# -----------------------------------------------------------------------------
# Main Execution Flow
# -----------------------------------------------------------------------------

main() {
    trap cleanup EXIT
    get_root "$@"
    install_missing_packages "$@"
    get_the_drive "$@"
    get_the_iso "$@"
    format_drive "$@"
    extract_iso "$@"
}

main "$@"
