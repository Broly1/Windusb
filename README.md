---
title: "WindUSB Installation Script"
description: "Automated Bash script for creating bootable Windows USB drives with GPT, FAT32, and WIM splitting support."
---

# WindUSB Installation Script

> [!TIP]
> **Looking for the graphical version? Try:**  
> 👉 **[WindUSB-GUI](https://github.com/Broly1/WindUSB-GUI)**

---

## Overview

WindUSB is a fully automated Bash script for creating a bootable Windows installation USB on Linux.

It handles:

- Automatic dependency installation (APT, DNF, Pacman)
- Secure USB detection (USB transport filtering)
- Explicit data-destruction confirmation
- GPT partition table reset
- FAT32 formatting for UEFI compatibility
- Automatic `install.wim` splitting (bypasses FAT32 4GB limit)
- ISO validation (`install.wim` / `install.esd`)
- Clean loop device handling
- Safe unmounting and disk finalization

No manual partitioning. No manual mounting. No guesswork.

---

## Supported Distributions

- Debian / Ubuntu (APT)
- Fedora (DNF)
- Arch Linux (Pacman)

---

## How It Works

1. Detects connected USB devices using `lsblk` filtered by transport type.
2. Prompts for explicit confirmation before wiping the drive.
3. Resets the drive using GPT (`sgdisk --zap-all`).
4. Creates a Microsoft Basic Data partition.
5. Formats it as FAT32 (UEFI compatible).
6. Mounts and validates the Windows ISO.
7. Splits `install.wim` into 3.4GB `.swm` chunks.
8. Copies remaining installer files using `rsync`.
9. Flushes writes and safely unmounts the device.

---

## Usage

### 1. Download and Run
Make sure you have wget or curl installed and run this commands:

**Using wget:**
```bash
wget -O windusb.sh https://raw.githubusercontent.com/Broly1/Windusb/master/windusb.sh
chmod +x windusb.sh
./windusb.sh
````

or

**Using curl:**

```bash
curl -o windusb.sh https://raw.githubusercontent.com/Broly1/Windusb/master/windusb.sh
chmod +x windusb.sh
./windusb.sh
````

The script will automatically request sudo privileges if required.

---

### 2. Select USB Drive

You will see a list of detected USB devices.

⚠ **ALL DATA ON THE SELECTED DRIVE WILL BE ERASED**

You must type `YES` to confirm formatting.

---

### 3. Provide Windows ISO Path

You will be prompted to:

* Paste the ISO path
* Or drag & drop the ISO into the terminal

The script validates that the ISO contains:

* `sources/install.wim`
* or `sources/install.esd`

If not detected, the ISO will be rejected.

---

### 4. Automatic Creation Process

The script will:

* Install missing dependencies
* Partition and format the USB
* Split large WIM files automatically
* Copy installer files
* Flush and safely unmount the device

When complete, you will see:

```
Success: Windows Installation Media is ready.
```

---

## Requirements

* Valid Windows ISO (Windows 10 / 11 supported)
* Internet connection (for dependency installation)
* 8GB+ USB drive recommended

---

## Safety Notes

* The selected USB drive will be completely wiped.
* Always double-check the selected device.
* Do not interrupt formatting or copying.
* Removing the USB before completion may corrupt the media.

---

## License

Licensed under the GNU General Public License v3.0
[https://www.gnu.org/licenses/gpl-3.0.txt](https://www.gnu.org/licenses/gpl-3.0.txt)

---

## Author

Developed and maintained by Broly.

If you encounter issues or have improvement suggestions, feel free to open an issue or submit a pull request.
