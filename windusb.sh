#!/usr/bin/env bash
#
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

# Configuration
USB_MOUNT_POINT=$(mktemp -d -t windusb_usb_XXXX)
ISO_MOUNT_DIR=$(mktemp -d -t windusb_iso_XXXX)

# Global variables to store user selections
SELECTED_DRIVE=""
SELECTED_ISO_PATH=""

# Install missing packages
DEBIAN_PACKAGES=("curl" "rsync" "wget" "gdisk" "wimtools")
FEDORA_PACKAGES=("curl" "rsync" "wget" "gdisk" "wimlib-utils")
ARCH_PACKAGES=("curl" "rsync" "wget" "gptfdisk" "wimlib")

# Log errors and exit
log_error() {
    local message="$1"
    printf "ERROR: %s\n" "$message"
    exit 1
}

# Display banner
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

cleanup() {
    umount "$USB_MOUNT_POINT" 2>/dev/null
    umount "$ISO_MOUNT_DIR" 2>/dev/null
    rm -rf "$USB_MOUNT_POINT" "$ISO_MOUNT_DIR"
}

# Welcome the user and ask for root password
get_root() {
    clear
    banner
    if [[ "$(whoami)" != "root" ]]; then
        printf "Please enter your password to continue:\n"
        exec sudo -- "$0" "$@"
    fi
}

# Check for internet connectivity
check_for_internet() {
    clear
    banner
    if ! ping -q -c 1 -W 1 google.com >/dev/null; then
        log_error "No internet connection. Unable to download dependencies."
    fi
}

# Get the USB drive selected by the user
get_the_drive() {
    local lines i choice selected_drive_line
    clear
    banner
    while true; do
        printf "Please select the USB drive from the following list:\n"
        readarray -t lines < <(lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb")
        for ((i=0; i<${#lines[@]}; i++)); do
            printf "%d) %s\n" "$((i+1))" "${lines[i]}"
        done
        printf "r) Refresh\n"
        read -r -p "#? " choice
        clear
        banner
        if [[ "$choice" == "r" ]]; then
            printf "Refreshing USB drive list...\n"
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#lines[@]}" ]]; then
            selected_drive_line="${lines[$((choice-1))]}"
            SELECTED_DRIVE=$(echo "$selected_drive_line" | awk '{print $1}')
            break
        else
            printf "Invalid selection. Please try again.\n"
        fi
    done
}

# Check for Windows ISO files (Win*.iso) in the current directory
get_the_iso() {
    local iso_files=(Win*.iso)
    local iso_choice

    if [[ ! -e "${iso_files[0]}" ]]; then
        clear
        banner
        log_error "No Windows ISO found in the current directory."
    fi

    if [[ ${#iso_files[@]} -eq 1 ]]; then
        SELECTED_ISO_PATH="${iso_files[0]}"
    else
        clear
        banner
        printf "Multiple Windows ISO files found. Please select one:\n"
        select iso_choice in "${iso_files[@]}"; do
            if [[ -n "$iso_choice" ]]; then
                printf "Selected Windows ISO: %s\n" "$iso_choice"
                SELECTED_ISO_PATH="$iso_choice"
                break
            else
                printf "Invalid selection. Please choose a valid option.\n"
            fi
        done
    fi
}

# Install missing packages
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

# Format the selected USB drive as FAT32
format_drive() {
    clear
    banner
    printf "Formatting the drive as FAT32 (for WIM splitting compatibility)...\n"
    umount "$SELECTED_DRIVE"* 2>/dev/null || :
    wipefs -af "$SELECTED_DRIVE" || log_error "Failed to wipe filesystem"
    if ! sgdisk -e "$SELECTED_DRIVE" --new=0:0: -t 0:0700 && partprobe; then
        log_error "Failed to create partition"
    fi
    sleep 3
    mkfs.fat -F32 "${SELECTED_DRIVE}1" || log_error "Failed to format as FAT32"
    mount "${SELECTED_DRIVE}1" "$USB_MOUNT_POINT" || log_error "Failed to mount USB"
}

get_dirty_kb() {
    grep -E "^(Dirty|Writeback):" /proc/meminfo | awk '{sum+=$2} END {print sum}'
}

extract_iso() {
    local i max_retries=3 attached_loops loop upid spin='-\|/' 
    local cur_dirty rem_txt prog initial_dirty ref_kb

    # (Functionality logic preserved: ensuring ISO path is ready)
    if [[ -z "$SELECTED_ISO_PATH" ]]; then
        get_the_iso
    fi

    # Forcefully unmount the mount point if mounted
    if mountpoint -q "$ISO_MOUNT_DIR"; then
        printf "Unmounting existing mount...\n"
        umount -f "$ISO_MOUNT_DIR" || {
            printf "Force unmount failed, trying lazy unmount...\n"
            umount -l "$ISO_MOUNT_DIR"
        }
    fi

    attached_loops=$(losetup -j "$SELECTED_ISO_PATH" 2>/dev/null | cut -d: -f1)
    if [[ -n "$attached_loops" ]]; then
        printf "Detaching existing loop devices for the ISO...\n"
        for loop in $attached_loops; do
            losetup -d "$loop"
        done
    fi

    for ((i=1; i<=max_retries; i++)); do
        if mount -o loop,ro "$SELECTED_ISO_PATH" "$ISO_MOUNT_DIR"; then
            break
        else
            if [[ $i -eq max_retries ]]; then
                log_error "Failed to mount ISO after $max_retries attempts"
            fi
            sleep 1
            printf "Retrying mount (%d/%d)...\n" "$i" "$max_retries"
        fi
    done

    # Split the install.wim file to fit into the FAT32 limitation
    printf "Splitting install.wim...\n"
    mkdir -p "$USB_MOUNT_POINT/sources"
    wimlib-imagex split "$ISO_MOUNT_DIR/sources/install.wim" \
        "$USB_MOUNT_POINT/sources/install.swm" 3400 || log_error "Failed to split WIM"
    printf "Rsyncing remaining files...\n"
    rsync -rltD --no-owner --no-group --modify-window=1 --info=progress2 --human-readable \
        --exclude="sources/install.wim" \
        "$ISO_MOUNT_DIR/" "$USB_MOUNT_POINT/" 2>&1 || {
        
        local r_err=$?
        if [[ $r_err -eq 23 ]]; then
            printf "\nNote: Some attributes not preserved (normal for FAT32)\n"
        else
            log_error "File copy failed with exit code $r_err"
        fi
    }

    printf "Synchronizing drive partition %s1...\n" "$SELECTED_DRIVE"
    
    initial_dirty=$(get_dirty_kb)
    ref_kb=$initial_dirty
    if (( ref_kb < 1024 )); then ref_kb=1024; fi

    umount "$USB_MOUNT_POINT" &
    upid=$!
    i=0

    while kill -0 "$upid" 2>/dev/null; do
        cur_dirty=$(get_dirty_kb)
        
        # Human readable math
        if (( cur_dirty > 1048576 )); then
            rem_txt=$(awk "BEGIN {printf \"%.2f GB\", $cur_dirty/1048576}")
        else
            rem_txt=$(awk "BEGIN {printf \"%.1f MB\", $cur_dirty/1024}")
        fi

        # Percentage math (clamped between 92 and 99.8)
        prog=$(awk "BEGIN {p = 92 + ((1.0 - ($cur_dirty / $ref_kb)) * 7.8); if (p > 99.8) p=99.8; if (p < 92) p=92; printf \"%.1f\", p}")
        
        # Logic for when buffer is essentially clear but umount is still busy
        if (( cur_dirty <= 512 )); then
            i=$(( (i+1) % 4 ))
            printf "\r\033[KFinalizing... %s [99.9%%]" "${spin:$i:1}"
        else
            printf "\r\033[KFlushing Cache: %s remaining [%s%%]" "$rem_txt" "$prog"
        fi
        
        sleep 0.1
    done
    
    if ! wait "$upid"; then
        log_error "Failed to unmount the drive."
    fi
    
    printf "\r\033[KFinalizing... 100%% Done!\n"
    printf "\nWindows installation completed successfully!\n"
}

main() {
    trap cleanup EXIT
    get_root "$@"
    check_for_internet "$@"
    get_the_drive "$@"
    get_the_iso "$@"
    install_missing_packages "$@"
    format_drive "$@"
    extract_iso "$@"
}

main "$@"