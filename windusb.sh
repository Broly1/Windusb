#!/usr/bin/env bash
#
# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

# Welcome the user and check if running as root
welcome() {
	clear

	cat <<"EOF"
########################
#  Welcome to WindUSB  #
########################

Please enter your password!
EOF

	if [[ "$(whoami)" != "root" ]]; then
		exec sudo -- "$0" "$@"
	fi

}

check_for_internet() {
    clear

    # Check for internet connectivity
    if ping -q -c 1 -W 1 google.com >/dev/null; then
        printf "Internet connection available.\n"
    else
        printf "No internet connection. Unable to download dependencies.\n"
		exit 1
    fi
}

# Prompt the user to select a USB drive
get_the_drive() {
	clear

	cat <<"EOF"
#################################
#  Please Select the USB Drive  #
#  From the Following List!     #
#################################

EOF

	readarray -t lines < <(lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb")
	select choice in "${lines[@]}"; do
		[[ -n $choice ]] || {
			printf ">>> Invalid selection!\n" >&2
			continue
		}
		break
	done
	read -r drive _ <<<"$choice"

	if [[ -z "$choice" ]]; then
		printf "No USB drive found. Please insert the USB Drive and try again.\n"
		exit 1
	fi
}

# Check for Windows ISO files (Win*.iso) in the current directory
get_the_iso() {
	iso_files=(Win*.iso)

	if [ ! -e "${iso_files[0]}" ]; then
		clear
		printf "No Windows ISO found in the current directory.\n"
		exit 1
	fi

	if [ ${#iso_files[@]} -eq 1 ]; then
		iso_path="${iso_files[0]}"
	else
		clear
		printf "Multiple Windows ISO files found\n Please select one:\n"

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
	while true; do
		printf " Disk %s will be formatted,\n wget ntfs-3g & gdisk will be installed.\n Do you want to continue? [y/n]: " "$drive"
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

	debian_packages=("wget" "ntfs-3g" "gdisk")
	fedora_packages=("wget" "ntfs-3g" "gdisk")
	arch_packages=("wget" "ntfs-3g" "gptfdisk")

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

# Extract the contents of a Windows ISO to a specified location
extract_iso() {
	clear

	printf "Downloading 7zip:\n"
	check_for_internet "$@"
	wget -O - "https://sourceforge.net/projects/sevenzip/files/7-Zip/23.01/7z2301-linux-x64.tar.xz" | tar -xJf - 7zz
	chmod +x 7zz
	clear

	printf "Installing Windows iso to the Drive:\n"
	./7zz x -bso0 -bsp1 "${iso_path[@]}" -aoa -o"$usb_mount_point"
	rm -rf 7zz
	clear

	cat <<"EOF"
##################################
#  Synchronizing, Do Not Remove  #
#  The Drive or Cancel it        #
#  This Will Take a Long Time!   #
##################################
EOF

	printf "Synchronizing Drive partition %s1...\n" "$drive"
	umount "$drive"1
	rm -rf "$usb_mount_point"
	clear
	printf "Installation finished\n"
}

main() {
	welcome "$@"
	check_for_internet "$@"
	get_the_drive "$@"
	get_the_iso "$@"
	confirm_continue "$@"
	install_missing_packages "$@"
	format_drive "$@"
	extract_iso "$@"
}
main "$@"
