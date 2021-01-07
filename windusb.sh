#!/bin/bash 
# Autor: Broly
# License: GNU General Public License v3.0
# https://www.gnu.org/licenses/gpl-3.0.txt
# macOS

homebrewfunc(){

  if ! command -v brew &>/dev/null; then

    echo | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

    echo | brew update

  fi

}

wimlibfunc(){

  if brew ls --versions wimlib > /dev/null; then

    printf "wimlib already installed.\n"

  else

    echo | brew install wimlib

  fi

}

rsyncfunc(){

  if brew ls --versions rsync > /dev/null; then

    printf "rsync already installed.\n"

  else

    echo | brew install rsync

  fi

}

partextract(){

  set -e

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

sudo diskutil unmountDisk /Volumes/"$INSTALLER_DEVICE"

sudo diskutil eraseVolume ms-dos WINDUSB "$INSTALLER_DEVICE"

sudo hdiutil attach Win*.iso -mountpoint /Volumes/WINISO

}
wimsplitfunc(){

  clear
  cat << "EOF"
#################################
#  COPYING FILES TO THE DRIVE   #
#################################
EOF

printf "Copying Files to Drive.\n"

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

  partextract "$@"

  homebrewfunc "$@"

  wimlibfunc "$@"

  rsyncfunc "$@"

  wimsplitfunc "$@"

}

clear

cat << "EOF"
############################
#    WELCOME TO WINDUSB    #
############################
EOF

if [[ "$OSTYPE" == "darwin"* ]]; then

  while true; do

    read -r -p "$(printf "Homebrew, wimlib, and rsync will be installed if not already avaliable,\n do you wish to continue [y/n]? ")" yn

    case $yn in

      [Yy]* ) main "$@"; return 1;;

      [Nn]* ) exit;;

      * ) printf "Please answer yes or no.\n";;

    esac

  done

fi


# Linux

[[ "$(whoami)" != "root" ]] && exec sudo -- "$0" "$@"

set -e

dependencies(){

  clear

  printf "Installing dependencies.\n"

  printf "\n"

  if [[ -f /etc/debian_version ]]; then

    apt install -y  wimtools rsync 

  elif [[ -f /etc/fedora-release ]]; then

    dnf install -y  wimlib-utils rsync 

  elif [[ -f /etc/arch-release ]]; then

    pacman -Syu --noconfirm --needed  wimlib rsync 

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

  printf "Partitioning the Drive.\n"

  printf "\n"

  umount "$drive"?* || :

  sgdisk --zap-all "$drive" && partprobe

  sgdisk -e "$drive" --new=0:0: -t 0:0700 && partprobe

  sleep 2s

  mkfs.fat -F32 -n WINDUSB "$drive"1

  mount "$drive"1 /mnt/

}
extract(){

  if [ ! -d "/media/winiso" ] 

  then

    mkdir /media/winiso

  else

    umount /media/winiso || :; rm -rf /media/winiso; mkdir /media/winiso

  fi  

  mount -o loop Win*.iso /media/winiso

  clear

  printf "Splitting and Copying files to Drive.\n"

  printf "\n"

  rsync -a --info=progress2 --no-links --no-perms --no-owner --no-group --exclude sources/install.wim /media/winiso/ /mnt/

  clear

  printf "This will take a long time!\n"

  printf "\n"

  wimsplit /media/winiso/sources/install.wim /mnt/sources/install.swm 1000

  umount /media/winiso || :; rm -rf /media/winiso

  clear

  printf "\n"

  printf "umounting the drive do not remove it or cancel, this will take a long time!\n"

  umount "$drive"1

  clear

  printf "\n"

  printf "Installation finished!\n"

}

while true; do

  read -r -p "$(printf %s "Disk ""$drive"" will be erased wimlib and rsync will be installed, do you wish to continue [y/n]? ")" yn

  case $yn in

    [Yy]* ) dependencies; partformat; extract; break;;

    [Nn]* ) exit;;

    * ) printf "Please answer yes or no.\n";;

  esac
done
