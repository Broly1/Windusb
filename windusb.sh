#!/usr/bin/env bash
#
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

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
    banner "$@"
    printf "Please enter your password:\n"
    if [[ "$(whoami)" != "root" ]]; then
        exec sudo -- "$0" "$@"
    fi
}

check_for_internet() {
    clear
    banner "$@"

    # Check for internet connectivity
    if ping -q -c 1 -W 1 google.com >/dev/null; then
        :
    else
        printf "No internet connection. Unable to download dependencies.\n"
        exit 1
    fi
}

# Get the USB drive selected by the user.
get_the_drive() {
    clear
    banner "$@"
    while true; do
        printf "Please Select the USB Drive\nFrom the Following List!\n"
        readarray -t lines < <(lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb")
        for ((i=0; i<${#lines[@]}; i++)); do
            printf "%d) %s\n" "$((i+1))" "${lines[i]}"
        done
        printf "r) Refresh\n"
        read -r -p "#? " choice
        clear
        banner "$@"
        if [ "$choice" == "r" ]; then
            printf "Refreshing USB Drive List...\n"
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
        banner "$@"
        printf "No Windows ISO found in the current directory.\n"
        exit 1
    fi

    if [ ${#iso_files[@]} -eq 1 ]; then
        iso_path="${iso_files[0]}"
    else
        clear
        banner "$@"
        printf "Multiple Windows ISO files found \nPlease select one:\n"

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

# Ask user to confirm and continue with installation
confirm_continue() {
    clear
    banner "$@"
    while true; do
        printf "Warning the drive below will be erased: \n'%s' \n\nThe following tools will be installed: \nwget ntfs-3g & gdisk.\nDo you want to proceed? [y/n]: " "$selected_drive_line"
        read -r yn
        case $yn in
        [Yy]*)
            break
            ;;
        [Nn]*)
            exit
            ;;
        *)
            printf "Please answer yes or no.\n"
            ;;
        esac
    done
}

# Install the missing packages if we don't have them
install_missing_packages() {
    clear
    banner "$@"

    debian_packages=("curl" "wget" "ntfs-3g" "gdisk")
    fedora_packages=("curl" "wget" "ntfs-3g" "gdisk")
    arch_packages=("curl" "wget" "ntfs-3g" "gptfdisk")

    printf "Installing dependencies\n"

    if [[ -f /etc/debian_version ]]; then
        for package in "${debian_packages[@]}"; do
            if ! dpkg -s "$package" >/dev/null 2>&1; then
                apt update && apt install -y "$package"
            else
                printf "Package %s is already installed (APT).\n" "$package"
            fi
        done

    elif [[ -f /etc/fedora-release ]]; then
        for package in "${fedora_packages[@]}"; do
            if ! rpm -q "$package" >/dev/null 2>&1; then
                dnf install -y "$package"
            else
                printf "Package %s is already installed (DNF).\n" "$package"
            fi
        done

    elif [[ -f /etc/arch-release ]]; then
        for package in "${arch_packages[@]}"; do
            if ! pacman -Q "$package" >/dev/null 2>&1; then
                pacman -Sy --noconfirm --needed "$package"
            else
                printf "Package %s is already installed (Pacman).\n" "$package"
            fi
        done
    else
        printf "Your distro is not supported!\n"
        exit 1
    fi
}

# Format the selected USB drive and create an NTFS partition
format_drive() {
    clear
    banner "$@"

    printf "Formatting the drive and creating a NTFS partition:\n"
    umount "$drive"* || :
    wipefs -af "$drive"
    sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe
    sleep 3s
    umount "$drive"* || :
    mkntfs -Q -L WINDUSB "$drive"1
    usb_mount_point="/run/media/wind21192/"
    mkdir -p "$usb_mount_point"
    mount "$drive"1 "$usb_mount_point"
}

# Download latest 7zip binary
BASE_URL="https://sourceforge.net/projects/sevenzip/files/7-Zip/"

get_latest_version_7z() {
    page_content=$(curl -s "$BASE_URL")
    latest_version=$(echo "$page_content" | grep -oP '(?<=href="/projects/sevenzip/files/7-Zip/)[0-9]+\.[0-9]+' | sort -V | tail -n 1)
    printf "%s\n" "$latest_version"
}

download_and_extract_7zz() {
    latest_version=$(get_latest_version_7z)
    if [ -z "$latest_version" ]; then
        printf "Could not find the latest version.\n"
        exit 1
    fi
    file_url="${BASE_URL}${latest_version}/7z${latest_version//./}-linux-x64.tar.xz"
    printf "Downloading 7z%slinux-x64.tar.xz...\n" "${latest_version//./}-"
    curl -LO "$file_url"
    printf "Extracting the 7zz binary...\n"
    tar -xJf "7z${latest_version//./}-linux-x64.tar.xz" 7zz
    rm "7z${latest_version//./}-linux-x64.tar.xz"
    printf "Extracted 7zz binary for version %s\n" "$latest_version"
}

# Extract the contents of a Windows ISO to a specified location
extract_iso() {
    clear
    banner "$@"

    printf "Downloading 7zip:\n"
    check_for_internet "$@"
    download_and_extract_7zz "$@"

    if [[ ! -f 7zz ]]; then
        printf "Error: 7zz was not downloaded or is missing.\n"
        exit 1
    fi

    chmod +x 7zz
    clear
    banner "$@"

    printf "Installing Windows iso to the Drive:\n"
    if ! ./7zz x -bso0 -bsp1 "${iso_path[@]}" -aoa -o"$usb_mount_point"; then
        printf "Error: Failed to extract the ISO file.\n"
        rm -rf 7zz
        exit 1
    fi

    rm -rf 7zz
    clear
    banner "$@"

    cat <<"EOF"

>  Synchronizing, Do Not Remove  <
>  The Drive or Cancel it        <
>  This Will Take a Long Time!   <

EOF

    printf "Synchronizing Drive partition %s1...\n" "$drive"
    if ! umount "$drive"1; then
        printf "Error: Failed to unmount the drive.\n"
        exit 1
    fi

    rm -rf "$usb_mount_point"
    clear
    banner "$@"
    printf "Installation finished\n"
}

main() {
    get_root "$@"
    check_for_internet "$@"
    get_the_drive "$@"
    get_the_iso "$@"
    confirm_continue "$@"
    install_missing_packages "$@"
    format_drive "$@"
    extract_iso "$@"
}

main "$@"
