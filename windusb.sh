#!/usr/bin/env bash
#
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

# Configuration
log="windusb_log.txt"
usb_mount_point="/run/media/wind21192/"
base_url="https://sourceforge.net/projects/sevenzip/files/7-Zip/"

# Packages for different distributions
debian_packages=("curl" "wget" "ntfs-3g" "gdisk")
fedora_packages=("curl" "wget" "ntfs-3g" "gdisk")
arch_packages=("curl" "wget" "ntfs-3g" "gptfdisk")

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
                if ! apt update && apt install -y "$package"; then
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

# Format the selected USB drive and create an NTFS partition
format_drive() {
    clear
    banner

    printf "Formatting the drive and creating an NTFS partition...\n"
    umount "$drive"* 2>/dev/null || :
    wipefs -af "$drive" || log_error "Failed to wipe filesystem on $drive"
    if ! sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe; then
        log_error "Failed to create partition"
    fi
    sleep 3s
    umount "$drive"* 2>/dev/null || :
    mkntfs -Q -L WINDUSB "$drive"1 || log_error "Failed to create NTFS partition"
    mkdir -p "$usb_mount_point"
    mount "$drive"1 "$usb_mount_point" || log_error "Failed to mount $drive"
}

# Get the latest version of 7zip
get_latest_version_7z() {
    page_content=$(curl -s "$base_url") || log_error "Failed to fetch 7zip version"
    latest_version=$(echo "$page_content" | grep -oP '(?<=href="/projects/sevenzip/files/7-Zip/)[0-9]+\.[0-9]+' | sort -V | tail -n 1)
    printf "%s\n" "$latest_version"
}

# Download and extract 7zip
download_and_extract_7zz() {
    latest_version=$(get_latest_version_7z)
    if [ -z "$latest_version" ]; then
        log_error "Could not find the latest version of 7zip."
    fi
    file_url="${base_url}${latest_version}/7z${latest_version//./}-linux-x64.tar.xz"
    printf "Downloading 7z%slinux-x64.tar.xz...\n" "${latest_version//./}-"
    curl -LO "$file_url" || log_error "Failed to download 7zip"
    printf "Extracting the 7zz binary...\n"
    tar -xJf "7z${latest_version//./}-linux-x64.tar.xz" 7zz || log_error "Failed to extract 7zip"
    rm "7z${latest_version//./}-linux-x64.tar.xz"
    printf "Extracted 7zz binary for version %s\n" "$latest_version"
}

# Extract the contents of a Windows ISO to the USB drive
extract_iso() {
    clear
    banner

    printf "Downloading 7zip...\n"
    check_for_internet
    download_and_extract_7zz

    if [[ ! -f 7zz ]]; then
        log_error "7zz was not downloaded or is missing."
    fi

    chmod +x 7zz
    clear
    banner

    printf "Extracting Windows ISO...\n"
    if ! ./7zz x -bso0 -bsp1 "${iso_path[@]}" -aoa -o"$usb_mount_point"; then
        log_error "Failed to extract the ISO file."
    fi

    rm -rf 7zz
    clear
    banner

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

    rm -rf "$usb_mount_point"
    clear
    banner
    printf "\033[1;32mInstallation finished successfully!\033[0m\n"
}

# Main function
main() {
    get_root "$@"
    check_for_internet
    get_the_drive
    get_the_iso
    install_missing_packages
    format_drive
    extract_iso
}

# Execute the script
main "$@" | tee "$log"