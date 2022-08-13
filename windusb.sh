#!/bin/bash
# Autor: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt

welcome() {
	clear
	cat <<"EOF"
########################
#  WELCOME TO WINDUSB  #
########################

Please enter your password!
EOF
	[[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
	set -e
}

dependencies() {
	clear
	cat <<"EOF"
#############################
#  INSTALLING DEPENDENCIES  #
#############################

EOF
	if [[ -f /etc/debian_version ]]; then
		apt install -y wimtools rsync
	elif [[ -f /etc/fedora-release ]]; then
		dnf install -y wimlib-utils rsync
	elif [[ -f /etc/arch-release ]]; then
		pacman -Sy --noconfirm --needed wimlib rsync
	else
		printf "Your distro is not supported!'\n"
		exit 1
	fi
}

getthedrive(){
clear
cat <<"EOF"
################################################
#  WARNING: THE SELECTED DRIVE WILL BE ERASED  #
################################################

Please select the usb-drive!

EOF

readarray -t lines < <((lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb"))
select choice in "${lines[@]}"; do
[[ -n $choice ]] || {
	printf ">>> Invald selection!\n" >&2
	continue
	}
	break
	done
	read -r drive _ <<<"$choice"
	if [[ -z "$choice" ]]; then
	printf "No usb-drive found please insert the usb drive and try again.\n"
	exit 1
	fi
}

partformat() {
	clear
	cat <<"EOF"
#########################
#  FORMATING THE DRIVE  #
#########################

EOF
	umount "$drive"* || :
	wipefs -af "$drive"
	sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe
	sleep 3s
	umount "$drive"* || :
	mkfs.fat -F32 -n WINDUSB "$drive"1
	mount "$drive"1 /mnt/
}

formating(){
while true; do
	read -r -p "$(printf %s "Disk ""$drive"" will be erased wimlib and rsync will be installed, do you wish to continue [y/n]? ")" yn
	case $yn in
		[Yy]*)
			dependencies "$@"; partformat "$@"
			break
			;;
		[Nn]*) exit ;;
		*) printf "Please answer yes or no.\n" ;;
	esac
done
}

extract() {
	if [ ! -d "/run/media/winiso" ]; then
		mkdir /run/media/winiso
	else
		umount /run/media/winiso || :
		rm -rf /run/media/winiso
		mkdir /run/media/winiso
	fi
	mount -o loop Win*.iso /run/media/winiso
	clear
	cat <<"EOF"
#####################################################
#  RSYNCING EVERYTHING TO DRIVE EXCEPT INSTALL.WIM  # 
#####################################################

EOF
	rsync -a --info=progress2 --no-links --no-perms --no-owner --no-group --exclude sources/install.wim /run/media/winiso/ /mnt/

	clear
	cat <<"EOF"
#########################################################
#  COMPRESSING INSTALL.WIM THIS WILL TAKE A LONG TIME!  # 
#########################################################

EOF
	wimlib-imagex export /run/media/winiso/sources/install.wim all /mnt/sources/install.esd --solid
	umount /run/media/winiso || :
	rm -rf /run/media/winiso

	clear
	cat <<"EOF"
#####################################################
#  UMOUNTING THE DRIVE, DO NOT REMOVE IT OR CANCEL  #
#  THIS WILL TAKE A LONG TIME!                      #
#####################################################

EOF
	umount "$drive"1
	clear
	cat <<"EOF"
############################
#  INSTALLATION FINISHED!  #
############################

EOF
}

main() {
	welcome "$@"
	getthedrive "$@"
	formating "$@"
	extract "$@"
}

main "$@"
