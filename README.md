# How to create a windows 10 or 11 bootable usb installer on Linux.

## Windusb
This script format flash drives to FAT32    
mounts the windows iso and copies all files from the iso to the flash drive,    
except the install.win file wich is over 4GB in size  
wich is not supported by FAT32 file systems, so it compress it using wimlib-imagex like   
Microsoft install media does, so I chose to do it the same way,  
this script supports:  
Debian, Arch Linux, and Fedora base distros.  

### Linux Usage:

   1. Plug in the usb-drive then open your terminal cd to the directory contaning the windows iso then run  

   ```
   curl -o windusb.sh https://raw.githubusercontent.com/Broly1/Windusb/master/windusb.sh && chmod +x windusb.sh && ./windusb.sh
   ```  
  Or download and Paste the script in the same directory as the windows iso
   
   2. Plug in the usb-drive, open your terminal and ``cd`` to the directory contanining the iso and script.

   3. Run `./windusb.sh` enter your password.

   4. select the usb-drive and type ``y`` to start.
  
   5. It will take a long time to umount old 2.0 usb-drives, do not remove it or cancel it before it finishes syncing. 

