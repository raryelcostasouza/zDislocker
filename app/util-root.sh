#!/bin/bash

#Copyright (C) 2018 Raryel C. Souza <raryel.costa at gmail.com>

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <https://www.gnu.org/licenses/>.

#dislocker-gui-zenity
#This util-root.sh script contains the commands used by the dislocker-gui.sh
#that need to be run as root user

ACTION=$1
case $ACTION in
  "clearTMP")
      rm -f /tmp/fdisk.txt
      rm -f /tmp/drive_selection_list-mounted.txt
      rm -f /tmp/drive_selection_list-not_mounted.txt
      ;;

  "isDriveMounted")
      PATH_MOUNT_POINT=$2
      PATH_DISLOCKER_FILE=$3

      echo $(mount | grep -q "$PATH_MOUNT_POINT\|$PATH_DISLOCKER_FILE"; echo $?)
      ;;

  "isBitlockerDrive")
      DRIVE=$2
      echo $(dislocker-fuse -r -V "/dev/$DRIVE" | grep -q "None of the provided decryption mean is decrypting the keys."; echo $?)
      ;;

  "createMountDir")
      MOUNT_POINT=$2
      DFILE_LOCATION=$3
      mkdir -p $MOUNT_POINT
      mkdir -p $DFILE_LOCATION
      ;;

  "decrypt")
      DRIVE_SELECTED=$2
      DRIVE_PASSWORD=$3
      PATH_DISLOCKER_FILE=$4
      #if the output contains the string "Can't decrypt correctly the VMK." it means the password supplied is wrong
      echo $(dislocker-fuse -v -V /dev/"$DRIVE_SELECTED" -u$DRIVE_PASSWORD -- $PATH_DISLOCKER_FILE | grep -q "Can't decrypt correctly the VMK."; echo $?)
      ;;

  "mount")
      DRIVE_SELECTED=$2
      PATH_MOUNT_POINT=$3
      PATH_DISLOCKER_FILE=$4

      mount -o loop,rw $PATH_DISLOCKER_FILE/dislocker-file $PATH_MOUNT_POINT
      ;;

  "umount")
      DRIVE_MOUNTPOINT=$2
      umount $DRIVE_MOUNTPOINT
      umount $DFILE_LOCATION
      ;;

  "getListSupportedDrives")
      #get list of NTFS/exFAT/HPFS/FAT drives and saves the list to the temp file
      fdisk -l | grep 'FAT32\|NTFS' | cut -c6-9 > /tmp/fdisk.txt
    ;;
esac
