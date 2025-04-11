#!/usr/bin/env bash
#
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

# Configuration
log="windusb_log.txt"
usb_mount_point=$(mktemp -d -t windusb_usb_XXXX)
iso_mount_dir=$(mktemp -d -t windusb_iso_XXXX)

# Install missing packages
debian_packages=("curl" "rsync" "wget" "gdisk" "wimtools")
fedora_packages=("curl" "rsync" "wget" "gdisk" "wimlib-utils")
arch_packages=("curl" "rsync" "wget" "gptfdisk" "wimlib")

# Log errors and exit
log_error() {
    local message="$1"
    printf "ERROR: %s\n" "$message" | tee -a "$log"
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
  umount "$usb_mount_point" 2>/dev/null
  umount "$iso_mount_dir" 2>/dev/null
  rm -rf "$usb_mount_point" "$iso_mount_dir"
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
            drive=$(echo "$selected_drive_line" | awk '{print $1}')
            break
        else
            printf "Invalid selection. Please try again.\n"
        fi
    done
}

# Check for Windows ISO files (Win*.iso) in the current directory
get_the_iso() {
    iso_files=(Win*.iso)

    if [ ! -e "${iso_files[0]}" ]; then
        clear
        banner
        log_error "No Windows ISO found in the current directory."
    fi

    if [ ${#iso_files[@]} -eq 1 ]; then
        iso_path="${iso_files[0]}"
    else
        clear
        banner
        printf "Multiple Windows ISO files found. Please select one:\n"

        select iso_path in "${iso_files[@]}"; do
            if [ -n "$iso_path" ]; then
                printf "Selected Windows ISO: %s\n" "$iso_path"
                break
            else
                printf "Invalid selection. Please choose a valid option.\n"
            fi
        done
    fi
}

# Install missing packages
install_missing_packages() {
    clear
    banner
    printf "Installing dependencies...\n"

    if [[ -f /etc/debian_version ]]; then
        for package in "${debian_packages[@]}"; do
            if ! dpkg -s "$package" >/dev/null 2>&1; then
                if ! apt-get update || ! apt-get install -y "$package"; then
                    log_error "Failed to install $package"
                fi
            else
                printf "Package %s is already installed (APT).\n" "$package"
            fi
        done

    elif [[ -f /etc/fedora-release ]]; then
        for package in "${fedora_packages[@]}"; do
            if ! rpm -q "$package" >/dev/null 2>&1; then
                if ! dnf install -y "$package"; then
                    log_error "Failed to install $package"
                fi
            else
                printf "Package %s is already installed (DNF).\n" "$package"
            fi
        done

    elif [[ -f /etc/arch-release ]]; then
        for package in "${arch_packages[@]}"; do
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
    umount "$drive"* 2>/dev/null || :
    wipefs -af "$drive" || log_error "Failed to wipe filesystem"
    if ! sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe; then
        log_error "Failed to create partition"
    fi
    sleep 3
    mkfs.fat -F32 "${drive}1" || log_error "Failed to format as FAT32"
    mount "${drive}1" "$usb_mount_point" || log_error "Failed to mount USB"
}

extract_iso() {
    iso_files=(Win*.iso)
    if [ ! -e "${iso_files[0]}" ]; then
        clear
        banner
        log_error "No Windows ISO found in the current directory."
    fi
    if [ ${#iso_files[@]} -eq 1 ]; then
        iso_path="${iso_files[0]}"
    else
        clear
        banner
        printf "Multiple Windows ISO files found. Please select one:\n"
        select iso_path in "${iso_files[@]}"; do
            [ -n "$iso_path" ] && break || printf "Invalid selection.\n"
        done
    fi

# Forcefully unmount the mount point if mounted
if mountpoint -q "$iso_mount_dir"; then
    printf "Unmounting existing mount...\n"
    umount -f "$iso_mount_dir" || {
        printf "Force unmount failed, trying lazy unmount...\n"
        umount -l "$iso_mount_dir"
    }
fi

attached_loops=$(losetup -j "$iso_path" 2>/dev/null | cut -d: -f1)
if [ -n "$attached_loops" ]; then
    printf "Detaching existing loop devices for the ISO...\n"
    for loop in $attached_loops; do
        losetup -d "$loop"
    done
fi

max_retries=3
for ((i=1; i<=max_retries; i++)); do
    if mount -o loop,ro "$iso_path" "$iso_mount_dir"; then
        break
    else
        if [[ $i -eq max_retries ]]; then
            log_error "Failed to mount ISO after $max_retries attempts"
            exit 1
        fi
        sleep 1
        printf "Retrying mount (%d/%d)...\n" "$i" "$max_retries"
    fi
done

    # Split the install.wim file to fit into the FAT32 limitation
    printf "Splitting install.wim...\n"
    mkdir -p "$usb_mount_point/sources"
    wimlib-imagex split "$iso_mount_dir/sources/install.wim" \
        "$usb_mount_point/sources/install.swm" 3800 || log_error "Failed to split WIM"
    clear
    banner
    printf "Copying files...\n"
    rsync -rltD --no-owner --no-group --modify-window=1 --info=progress2 --human-readable \
        --exclude="sources/install.wim" \
        "$iso_mount_dir/" "$usb_mount_point/" 2>&1 || {
        if [ $? -eq 23 ]; then
            printf "\nNote: Some attributes not preserved (normal for FAT32)\n"
        else
            log_error "File copy failed"
        fi
    }

    cat <<"EOF"

>  Important: Copying Windows Files to USB Drive  <
>  Do Not Remove the Drive or Interrupt the Process  <

    This process involves copying a large amount of data to the USB drive. 
    On slower USB 2.0 drives, it can take up to 20 to 30 minutes to complete. 
    Using a USB 3.0 drive or an external SSD will significantly reduce the time required.

    Please be patient and ensure the drive remains connected throughout the process 
    to avoid data corruption or an incomplete installation.

EOF

    printf "Synchronizing drive partition %s1...\n" "$drive"
    umount "$drive"1 &
    umount_pid=$!
    bar_size=40
    progress=""
    while kill -0 $umount_pid 2>/dev/null; do
        progress+="="
        if [[ ${#progress} -ge $bar_size ]]; then
            progress=""
        fi
        printf "\r\033[K[%s]" "$(printf "%-${bar_size}s" "$progress")"
        sleep 0.2
    done
    printf "\r[%s] Done!\n" "$(printf "%-${bar_size}s" "$progress")"
    wait $umount_pid
    if ! wait $umount_pid; then
        log_error "Failed to unmount the drive."
    fi
    trap cleanup EXIT
    printf "\nWindows installation prepared successfully!\n"
}

main() {
    get_root "$@"
    check_for_internet "$@"
    get_the_drive "$@"
    get_the_iso "$@"
    install_missing_packages "$@"
    format_drive "$@"
    extract_iso "$@"
}

main "$@" | tee "$log"
