#!/bin/bash

#uninstall script for dislocker-gui-zenity
#must be executed as ROOT

#remove the line added to sudoers file during install
sed -i '/dislocker-gui/d' /etc/sudoers

sudo rm -f /usr/share/applications/dislocker-gui.desktop
sudo rm -rf /opt/dislocker-gui
