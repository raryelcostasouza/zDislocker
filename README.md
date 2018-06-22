# dislocker-gui-zenity
Zenity based GUI for mounting and umounting Bitlocker drives using dislocker (https://github.com/Aorimn/dislocker)

# Requirements
1. dislocker
2. zenity


# Installation instructions
sudo ./install.sh

Note: to enable non-admin users to mount/umount Bitlocker protected drives, by default, during the installation a rule is added to the /etc/sudoers file. This rule allow all users to execute the script util-root.sh (where the root commands needed for mounting/umounting are located).

# Screenshots

# Bitlocker Drive Selection List
![dislocker-gui-ss1](screenshot/drive-list.png?raw=true "Bitlocker Drive List")

# Password Input
![dislocker-gui-ss2](screenshot/password-input.png?raw=true "Password Input")

# Drive currently Mounted. Eject safely?
![dislocker-gui-ss3](screenshot/drive-mounted-eject-safely.png?raw=true "Eject Safely")


## License

GNU GPL v3
