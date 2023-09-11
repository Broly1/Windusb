# WindUSB Installation Script

## Description

This Bash script automates the process of creating a bootable Windows USB drive using a Windows ISO file. It provides a user-friendly interface to format a USB drive, install required dependencies, and extract the Windows ISO file to the drive. The script also checks for root permissions and supports multiple Linux distributions.

## Usage

1. Make sure you have a Windows ISO file ready.

2. Execute the script type your root password. You can do this by running:

     ```bash
      curl -o windusb.sh https://raw.githubusercontent.com/Broly1/Windusb/master/windusb.sh && chmod +x windusb.sh && ./windusb.sh

    ```
or 
    ```bash
   chmod +x windusb.sh && ./windusb.sh
    ```




3. Follow the on-screen instructions:

   - You will be prompted to select a USB drive from the list of connected drives. Ensure you choose the correct drive as it will be formatted and all data will be erased.

   - The script will install the necessary dependencies for formatting and extracting.

   - You will be asked to confirm the erasure of the selected drive and the installation of dependencies.

   - The Windows ISO file will be extracted to the USB drive. This process may take some time.

4. Once the script finishes, you will receive a message indicating that the installation is complete.

## License

This script is licensed under the GNU General Public License v3.0. You can find the full license text [here](https://www.gnu.org/licenses/gpl-3.0.txt).

## Author

This script was authored by Broly.

Feel free to use and modify this script according to your needs. If you encounter any issues or have suggestions for improvements, please let me know.

**Note**: Be cautious when using this script, as it will format the selected USB drive and erase all existing data. Make sure you have backed up any important data before running the script.