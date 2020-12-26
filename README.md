# How to create a windows 10 bootble usb installer on linux and macOS.

## Windusb
This script will split the fat install.wim into smaller parts that fits within the fat32 limit,
partition and format the usb drive and copy all the iso files to it,
making it a bootble usb driver installer.
Supports macOS, Ubuntu, Arch Linux, and Fedora.
For more details read dragon788 <a href="https://gist.github.com/dragon788/26921410d8de054366188c5c5435ae01" target="_top">win10_binary_fission.md</a>
Credits to him.

### Linux Usage:

In terminal:

   1. Paste the script in the same directory as the windows iso
   
   2. Plug in the usb-drive, open your terminal and ``cd`` to the directory contanining the iso and script.

   3. Run `./windusb.sh` enter your password.

   4. select the usb-drive and type ``y`` to start.
  
   5. It will take a long time to umount old 2.0 usb-drives, do not remove it or cancel it before it finishes syncing. 

### macOS Usage:

   1. Plug in the usb-drive

   2. Open Disk utility and format it as ms-dos or exfat, it wont work with any other format.

   3. Paste the script in the same directory as the windows iso and ``cd`` to it.

   5. Run `./windusb.sh` enter your password.

   6. Type in the name you gave you usb-drive when formating eg: ``UNTITLED`` if no name was given.

   7. It will install ``homebrew`` and ``wimlib`` if you don't already have it installed.

   8. It will take a long time, do not cancel or remove the drive before it finishes.
