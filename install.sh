#!/bin/bash

#sudo rule to permit non-root users to use the dislocker-gui without being admin users
LINE_SUDOERS="ALL ALL=NOPASSWD: /opt/dislocker-gui/util-root.sh"

mkdir -p /opt/dislocker-gui

cp -r app/* /opt/dislocker-gui/
cp shortcut/dislocker-gui.desktop /usr/share/applications/

#check if the line already exists in the /etc/sudoers file
LINE_SUDOERS_EXISTS=$(cat /etc/sudoers | grep -q "$LINE_SUDOERS"; echo $?)

#if line does not exist yet... append it by the end of the file
if [ $LINE_SUDOERS_EXISTS ]
then
    echo $LINE_SUDOERS >> /etc/sudoers
fi
