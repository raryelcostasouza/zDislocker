#!/bin/bash

#uninstall script for dislocker-gui-zenity
#must be executed as ROOT

#remove the line added to sudoers file during install
sed -i '/zDislocker/d' /etc/sudoers

sudo rm -f /usr/share/applications/zDislocker.desktop
sudo rm -rf /opt/zDislocker
