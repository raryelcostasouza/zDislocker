#!/bin/bash

DFILE_LOCATION="/tmp/DFILE"

ACTION=$1
case $ACTION in
  "clearTMP")
      rm -f /tmp/fdisk.txt
      rm -f /tmp/drive_selection_list.txt
      ;;

  "checkBitLockerDriveMounted")
      DRIVE_MOUNTPOINT=$2
      echo $(mount | grep -q "$DRIVE_MOUNTPOINT\|$DFILE_LOCATION"; echo $?)
      ;;

  "isBitlockerDrive")
      DRIVE=$2
      echo $(dislocker-fuse -r -V "/dev/$DRIVE" | grep -q "None of the provided decryption mean is decrypting the keys."; echo $?)
      ;;

  "createMountDir")
      DRIVE_MOUNTPOINT=$2
      mkdir -p $DRIVE_MOUNTPOINT
      mkdir -p $DFILE_LOCATION
      ;;

  "decrypt")
      DRIVE_SELECTED=$2
      DRIVE_PASSWORD=$3
      #if the output contains the string "Can't decrypt correctly the VMK." it means the password supplied is wrong
      echo $(dislocker-fuse -v -V /dev/"$DRIVE_SELECTED" -u$DRIVE_PASSWORD -- $DFILE_LOCATION | grep -q "Can't decrypt correctly the VMK."; echo $?)
      ;;

  "mount")
      DRIVE_MOUNTPOINT=$2
      mount -o loop,rw $DFILE_LOCATION/dislocker-file $DRIVE_MOUNTPOINT
      ;;

  "umount")
      DRIVE_MOUNTPOINT=$2
      umount $DRIVE_MOUNTPOINT
      umount $DFILE_LOCATION
      ;;

  "getListNTFSDrives")
      #get list of NTFS/exFAT/HPFS drives and saves the list to the temp file
      fdisk -l | grep NTFS | cut -c6-9 > /tmp/fdisk.txt
    ;;
esac
