#!/usr/bin/env bash

# Author: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

# Function to welcome user and check if running as root
welcome() {
	clear
	cat <<"EOF"
########################
#  Welcome to WindUSB  #
########################
Please enter your password!
EOF
# Check if running as root
if [[ "$(whoami)" != "root" ]]; then
	exec sudo -- "$0" "$@"
fi

  # Set shell to exit on error
  set -e
}

# Function to prompt user to select a USB drive
getthedrive() {
	clear
	cat <<"EOF"
################################################
#  Select a USB Drive from the Following List  #
################################################
Please select the USB drive!
EOF

  # Get a list of USB drives connected to the system
  readarray -t lines < <(lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb")

  # Prompt user to select a USB drive from the list
  select choice in "${lines[@]}"; do
	  # Check if selection is valid
	  [[ -n $choice ]] || {
		  printf ">>> Invalid selection!\n" >&2
			    continue
		    }
		    break
	    done

  # Extract the drive name from the user's selection
  read -r drive _ <<<"$choice"

  # Check if no USB drive was selected
  if [[ -z "$choice" ]]; then
	  printf "No USB drive found. Please insert the USB drive and try again.\n"
	  exit 1
  fi
}

# Function to install required dependencies for WindUSB
dependencies() {
	clear
	cat <<"EOF"
#############################
#  Installing Dependencies  #
#############################
EOF

  # Check which Linux distribution is being used and install dependencies accordingly
  if [[ -f /etc/debian_version ]]; then
	  apt install -y ntfs-3g p7zip-full
  elif [[ -f /etc/fedora-release ]]; then
	  dnf install -y ntfs-3g p7zip-plugins
  elif [[ -f /etc/arch-release ]]; then
	  pacman -Sy --noconfirm --needed ntfs-3g p7zip
  else
	  printf "Your distro is not supported!'\n"
	  exit 1
  fi
}

# Function to format the selected USB drive and create a NTFS partition
partformat() {
	clear
	cat <<"EOF"
#########################
#  Formatting the Drive #
#########################
EOF
printf "Formatting the selected USB drive and creating a NTFS partition...\n"

  # Unmount any partitions on the selected drive
  umount "$drive"* || :

  # Wipe all existing filesystem signatures from the selected drive
  wipefs -af "$drive"

  # Create a new partition on the selected drive
  sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe

  # Wait 3 seconds to ensure the new partition is available
  sleep 3s

# Unmount any partitions on the selected drive
umount "$drive"* || :

# Format the new partition with the NTFS filesystem and label it as "WINDUSB"
mkntfs -Q -L WINDUSB "$drive"1



  # Mount the new partition on /run/media/wind21192t/
  usb_mount_point="/run/media/wind21192/" 
  mkdir -p "$usb_mount_point"
  mount "$drive"1 "$usb_mount_point"
}

# Function that prompts the user to confirm if they want to erase the disk, install dependencies, and format the partition
format_drive() {
	while true; do
		# Using printf to format the prompt string, allowing the variable $drive to be included in the string
		printf " Disk %s will be erased\n ntfs-3g & p7zip will be installed\n Do you wish to continue [y/n]? " "$drive"
		read -r yn
		case $yn in
			# If the user types "y" or "Y", run the dependencies() and partformat() functions, and break out of the loop
			[Yy]*)
			dependencies "$@"
			partformat "$@"
			break
			;;
			# If the user types "n" or "N", exit the script
			[Nn]*)
			exit
			;;
			# If the user types anything else, print an error message and loop back to the top of the loop
			*)
			printf "Please answer yes or no.\n"
			;;
	esac
done
}

# Function that extracts the contents of a Windows ISO to a specified location
extract() {
	clear
	cat <<"EOF"
#####################################
#  Extracting the ISO to the Drive  #
#####################################
EOF
# here we use 7zip to extract the iso because mounting it cause a lot of issues if we cancel the script 
# for any reason
7z x -bso0 -bsp1 Win*.iso -aoa -o"$usb_mount_point"

# Unmount the Windows ISO file and remove the temporary directory
clear
cat <<"EOF"
########################################################
#  Synchronizing Do Not Remove the Drive or Cancel it  #
#  This Will Take a Long Time!                         #
########################################################
EOF

# Unmount the drive partition
printf "Synchronizing drive partition %s1...\n" "$drive"
umount "$drive"1
rm -rf "$usb_mount_point"

  # Print a message indicating that the installation has finished
  clear
  cat <<"EOF"
############################
#  Installation Finished!  #
############################
EOF
}

main() {
	welcome "$@"
	getthedrive "$@"
	format_drive "$@"
	extract "$@"
}

main "$@"
