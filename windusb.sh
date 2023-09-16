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
set -e
}

# Prompt the user to select a USB drive
get_the_drive() {
	clear
	cat <<"EOF"
################################################
#  Select a USB Drive from the Following List  #
################################################
Please select the USB drive!
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
		printf "No USB drive found. Please insert the USB drive and try again.\n"
		exit 1
	fi
}

# Install required dependencies for WindUSB
install_dependencies() {
	clear
	cat <<"EOF"
#############################
#  Installing Dependencies  #
#############################
EOF
if [[ -f /etc/debian_version ]]; then
	apt install -y ntfs-3g p7zip-full gdisk
elif [[ -f /etc/fedora-release ]]; then
	dnf install -y ntfs-3g p7zip-plugins gdisk
elif [[ -f /etc/arch-release ]]; then
	pacman -Sy --noconfirm --needed ntfs-3g p7zip gptfdisk
else
	printf "Your distro is not supported!'\n"
	exit 1
fi
}

# Check for Windows ISO files (Win*.iso) in the current directory
get_the_iso() {
	iso_files=(Win*.iso)

	if [ ${#iso_files[@]} -eq 0 ]; then
		clear
		printf "No Windows ISO files found in the current directory.\n"
		exit 1
	fi

	if [ ${#iso_files[@]} -eq 1 ]; then
		iso_path="${iso_files[0]}"
	else
		clear
		printf "Multiple Windows ISO files found:\n"

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

# Format the selected USB drive and create an NTFS partition
format_drive() {
	clear
	cat <<"EOF"
#########################
#  Formatting the Drive #
#########################
EOF
printf "Formatting the selected USB drive and creating a NTFS partition...\n"
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

# Get everything ready for the Windows installation
prepare_for_installation() {
	while true; do
		printf " Disk %s will be erased\n ntfs-3g & p7zip will be installed\n Do you wish to continue [y/n]? " "$drive"
		read -r yn
		case $yn in
			[Yy]*)
				get_the_iso "$@"
				install_dependencies "$@"
				format_drive "$@"
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

# Extract the contents of a Windows ISO to a specified location
extract_iso() {
	clear
	cat <<"EOF"
#####################################
#  Extracting the ISO to the Drive  #
#####################################
EOF
7z x -bso0 -bsp1 "${iso_path[@]}" -aoa -o"$usb_mount_point"
clear
cat <<"EOF"
########################################################
#  Synchronizing Do Not Remove the Drive or Cancel it  #
#  This Will Take a Long Time!                         #
########################################################
EOF
printf "Synchronizing drive partition %s1...\n" "$drive"
umount "$drive"1
rm -rf "$usb_mount_point"
clear
cat <<"EOF"
############################
#  Installation Finished!  #
############################
EOF
}

main() {
	welcome "$@"
	get_the_drive "$@"
	prepare_for_installation "$@"
	extract_iso "$@"
}
main "$@"
