# dislocker-gui-zenity
Zenity based GUI for mounting and umounting Bitlocker drives using dislocker (https://github.com/Aorimn/dislocker)


# Recent Changes 08/04/2019
* Added support for mounting/unmounting multiple BitLocker drives
* Fix bug that cause FAT partitions or disks with GPT partitioning not being detected.
* Fix bug that caused the mounted drive only to be editable by the root user

# Requirements
1. dislocker
2. zenity


# Installation instructions
sudo ./install.sh

Note: to enable non-admin users to mount/umount Bitlocker protected drives, by default, during the installation a rule is added to the /etc/sudoers file. This rule allow all users to execute the script util-root.sh (where the root commands needed for mounting/umounting are located).

# WARNING!!!
The proper and safe way to eject the BitLocker encrypted drives is using this app.
Your file browser may automatically show an eject button, but it does not know how to eject with BitLocker drives properly.

If you eject a drive only using the file browser button it may cause DATA LOSS.

# Screenshots

# Main Window
![dislocker-gui-ss0](screenshot/main.png?raw=true "Main Window")

# Bitlocker Drive Selection List
![dislocker-gui-ss1](screenshot/drive-list.png?raw=true "Bitlocker Drive List")

# Password Input
![dislocker-gui-ss2](screenshot/password-input.png?raw=true "Password Input")

# Drive currently Mounted. Eject safely?
![dislocker-gui-ss3](screenshot/drive-mounted-eject-safely.png?raw=true "Eject Safely")

# Mount successfully
![dislocker-gui-ss4](screenshot/mount-success.png?raw=true "Mount Success")

## License

GNU GPL v3
