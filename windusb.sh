#!/bin/bash
# Autor: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt
installdepend(){
    if test ! "$(which brew)"; then
        printf "Installing homebrew...\n"
        echo | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        echo | brew update
        echo | brew install wimlib
        echo | brew install rsync
    fi
}

partextract(){
    set -e
    [[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
    clear
	cat << "EOF"
#######################################
#  WARNING: THE DRIVE WILL BE ERASED  #
#######################################
EOF
    read -r -p 'Enter name of USB media : ' INSTALLER_DEVICE
    clear
cat << "EOF"
###############################
#    PARTITIONING THE DRIVE   #
###############################
EOF
    diskutil unmountDisk /Volumes/"$INSTALLER_DEVICE"
    diskutil eraseVolume ms-dos WINDUSB "$INSTALLER_DEVICE"
    hdiutil attach Win*.iso -mountpoint /Volumes/WINISO
    clear
cat << "EOF"
#################################
#  COPYING FILES TO THE DRIVE   #
#################################
EOF
    printf "\n"
    rsync -a --info=progress2 --no-links --no-perms --no-owner --no-group --exclude sources/install.wim /Volumes/WINISO/ /Volumes/WINDUSB/
    clear
cat << "EOF"
###############################
#    SPLITTING INSTALL.WIM    #
###############################
EOF
    printf "this will take a long time...\n"
    wimlib-imagex split /Volumes/WINISO/sources/install.wim /Volumes/WINDUSB/sources/install.swm 1024
    hdiutil detach /Volumes/WINISO
    clear
    printf "Installation finished\n"
    exit 1
}

main(){
    installdepend "$@"
    partextract "$@"
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    main "$@"
fi

[[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"
declare -r cleanup="rm -rf /WINBLOWS/"
set -e
clear
cat << "EOF"
############################
#    WELCOME TO WINDUSB    #
############################
EOF
sleep 2s

$cleanup

dependencies(){
    clear
	cat << "EOF"
################################
#    INSTALLING DEPENDENCIES   #
################################
EOF
    
    sleep 2s
    if [[ -f /etc/debian_version ]]; then
        apt install -y wimtools p7zip-full rsync
        elif [[ -f /etc/fedora-release ]]; then
        dnf install -y wimlib-utils p7zip p7zip-plugins rsync
        elif [[ -f /etc/arch-release ]]; then
        pacman -Syu --noconfirm --needed wimlib p7zip rsync
    else
        printf "Your distro is not supported!'\n"
        exit 1
    fi
}

clear

cat << "EOF"
################################################
#  WARNING: THE SELECTED DRIVE WILL BE ERASED  #
################################################
EOF


readarray -t lines < <((lsblk -p -no name,size,MODEL,VENDOR,TRAN | grep "usb"))
printf "Please select the usb-drive!\n"
select choice in "${lines[@]}"; do
    [[ -n $choice ]] || { printf ">>> Invald Selection!\n" >&2; continue; }
    break
done
read -r drive _ <<<"$choice"
if [[ -z "$choice" ]]; then
	printf "No usb-drive found please insert the USB Drive and try again.\n"
	exit 1
fi
partformat(){
	clear
	cat << "EOF"
###############################
#    PARTITIONING THE DRIVE   #
###############################
EOF

umount "$drive"?* || :
sgdisk --zap-all "$drive" && partprobe
sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe
sleep 2s
mkfs.fat -F32 -n WINDUSB "$drive"1
mount "$drive"1 /mnt/
mkdir /WINBLOWS
}
extract(){
	clear
	cat << "EOF"
#############################
#    EXTRACTING ISO FILE    #
#############################
EOF
7z x Win*.iso -o/WINBLOWS/

clear
cat << "EOF"
###############################
#    SPLITTING INSTALL.WIM    #
###############################
EOF

wimsplit /WINBLOWS/sources/install.wim /WINBLOWS/sources/install.swm 1000
rm -rf /WINBLOWS/sources/install.wim

clear
cat << "EOF"
####################################
#    COPYING FILES TO THE DRIVE    #
####################################
EOF
rsync -a --info=progress2 /WINBLOWS/ /mnt/

printf "umounting the drive do not remove it or cancel this, it will take a long time!\n"
umount "$drive"1
printf "Installation finished!\n"
$cleanup
}

while true; do
	read -r -p "$(printf %s "Disk ""$drive"" will be erased and wimlib, p7zip, rsync will be installed
do you wish to continue [y/n]? ")" yn
	case $yn in
		[Yy]* ) dependencies; partformat; extract; break;;
		[Nn]* ) exit;;
		* ) printf "Please answer yes or no.\n";;
	esac
done
