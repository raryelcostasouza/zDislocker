#!/bin/bash

#Copyright (C) 2018 Raryel C. Souza <raryel.costa at gmail.com>

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
# any later version

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <https://www.gnu.org/licenses/>.

#dislocker-gui
#Zenity based GUI for mounting and unmounting Bitlocker drives using dislocker


function getPathMountPoint
{
    DRIVE_SELECTED=$1
    DRIVE_MOUNTPOINT_BASE="/mnt/BitLockerDrive"

    echo $(echo "$DRIVE_MOUNTPOINT_BASE-$DRIVE_SELECTED")
}

function getPathDislockerFile
{
  DRIVE_SELECTED=$1
  DFILE_LOCATION_BASE="/tmp/DFILE"

  echo $(echo $DFILE_LOCATION_BASE-$DRIVE_SELECTED)
}

function openFileBrowser
{
    PATH_MOUNT_POINT=$1

    if type nautilus > /dev/null
    then
        FILE_BROWSER="nautilus"
    elif type dolphin > /dev/null
    then
        FILE_BROWSER="dolphin"
    elif type thunar > /dev/null
    then
        FILE_BROWSER="thunar"
    else
        zenity --info --title="File Browser Not Found"
                      --text="Nautilus/Dolphin/Thunar not found\n\nOpen your file browser at $PATH_MOUNT_POINT"
        exit
    fi
    $($FILE_BROWSER $PATH_MOUNT_POINT)
}

function checkDependencies
{
    if ! type zenity > /dev/null
    then
        echo "Missing dependency 'Zenity'. Please install it before using this script.
                \n\nFor Ubuntu: sudo apt install zenity
                \n\nFor Fedora: sudo dnf install zenity";
        exit;
    fi


    if ! type dislocker-fuse > /dev/null
    then
        errorMessage "Missing dependency 'Dislocker'. Please install it before using this script.
                                                            \n\nFor Ubuntu: sudo apt install dislocker
                                                            \n\nFor Fedora: sudo dnf install fuse-dislocker"
        exit;
    fi
}

function clearTMPFiles
{
    sudo /opt/dislocker-gui/util-root.sh "clearTMP"
}

function errorMessage
{
    MESSAGE=$1
    zenity --error --title="Error" --no-wrap --text="$1"
}

function getListSupportedDrives
{
    sudo /opt/dislocker-gui/util-root.sh "getListSupportedDrives"
}

function getMountedBitlockerDrives
{
    getSelectionListBitlockerDrives "mounted"
}

function getNotMountedBitlockerDrives
{
  getSelectionListBitlockerDrives "not_mounted"
}

function getSelectionListBitlockerDrives
{
    STATUS=$1

    #get list of NTFS/exFAT/HPFS/FAT drives and saves the list to the temp file
    getListSupportedDrives

    #if there are any ntfs/exFAT/HPFS drives attached
    if [ -f "/tmp/fdisk.txt" ]
    then
        #for each candidate drive test if it is a bitlocker drive
        for drive in $(cat /tmp/fdisk.txt)
        do
            #if it is a valid bitlocker drive
            if [ $(isBitlockerDrive $drive) = "0" ]
            then
                size=$(getDiskSizeGB $drive)
                brandNModel=$(getDiskBrandNModel $drive)

                #if the parameter is MOUNTED... only add mounted drives to list
                #if the parameter is NOT_MOUNTED... only add not mounted drives to the list
                if [ [ $STATUS = "mounted" ] && [ $(isDriveMounted $drive) ] ] ||
                  [ [ $STATUS = "not_mounted" ] && ! [ $(isDriveMounted $drive) ] ]
                then
                  #creates a table for the drive selection interface. FALSE indicates that the option is by default not selected on the gui
                  echo "FALSE $drive $brandNModel $size" >> /tmp/drive_selection_list-$STATUS.txt
                fi
            fi
        done
    else
        errorBitlockerDriveNotFound
        exit 1
    fi

}

function errorBitlockerDriveNotFound
{
    errorMessage "No Bitlocker drives found!"
}

function getDiskFromPartition
{
    PARTITION=$1
    echo $(echo $PARTITION | cut -c1-3)
}

function getDiskSizeGB
{
    PARTITION=$1
    DISK=$(getDiskFromPartition $PARTITION)

    sectors=$(cat /sys/block/$DISK/size)
    sectorSize=$(cat /sys/block/$DISK/queue/logical_block_size)
    #get the size of the disk in GB
    echo $(echo "scale=2;(($sectors * $sectorSize * 1.0)/(1024*1024*1024.0))" | bc)"GB"
}

function getDiskBrandNModel
{
    PARTITION=$1
    DISK=$(getDiskFromPartition $PARTITION)

    #the disk vendor and model info are located after the 8th char on the output of the command
    #sed command replace spaces with underscores
    echo $(lsblk -o NAME,VENDOR,MODEL | grep $DISK | grep -v $PARTITION | cut -c8- | sed -e 's/ /_/g')
}

function isBitlockerDrive
{
    DRIVE=$1

    #return 0 if true
    #return 1 if false
    echo $(sudo /opt/dislocker-gui/util-root.sh "isBitlockerDrive" $DRIVE)
}

function mountDrive
{
    DRIVE_SELECTED=$1
    PATH_MOUNT_POINT= getPathMountPoint $DRIVE_SELECTED
    PATH_DISLOCKER_FILE= getPathDislockerFile $DRIVE_SELECTED

    sudo /opt/dislocker-gui/util-root.sh "createMountDir" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE

    #loop until the user supplies a valid password
    PASSWORD_WRONG=0
    while [ "$PASSWORD_WRONG" = "0" ]
    do
        DRIVE_PASSWORD=$(zenity --password --title="Locked Drive" --text="Please type the password for the BitLocker drive")
        #if the password field is not empty
        if [ -n "$DRIVE_PASSWORD" ]
        then
            #try to unlock the drive
            PASSWORD_WRONG=$(sudo /opt/dislocker-gui/util-root.sh "decrypt" $DRIVE_SELECTED $DRIVE_PASSWORD $PATH_DISLOCKER_FILE)

            #if the output contains the string "Can't decrypt correctly the VMK." it means the password supplied is wrong
            if [ "$PASSWORD_WRONG" = "0" ]
            then
                errorMessage "Wrong Bitlocker password! Please try again."
            fi
        else
            errorMessage "No password supplied!"
        fi
    done

    (sudo /opt/dislocker-gui/util-root.sh "mount" $DRIVE_SELECTED $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE) |
        zenity --progress --pulsate --auto-close --text="Please wait...\nMounting BitLockerDrive..." --title="Mounting Drive $DRIVE_SELECTED..."

    #open the file browser on the mount point directory
    openFileBrowser $PATH_MOUNT_POINT
}

function unmountDrive
{
  (sudo /opt/dislocker-gui/util-root.sh "unmount" $DRIVE_MOUNTPOINT) |
      zenity --progress --pulsate --auto-close --text="Please wait...\nSaving data..." --title="Saving Data..."

  //check if drive was successfully unmounted
  if [ "$(isDriveMounted)" = "1" ]
  then
      zenity --info --title="BitLockerDrive Ejected" --text="Now your BitLockerDrive can be removed safely"
  else
      errorMessage "Unable to eject BitLockerDrive.\nBefore trying to eject again, please close any opened file browser windows\nand make sure there are no files from the drive currently opened."
  fi
}

function windowSelectDrive
{
  ACTION=$1

  if [ "$ACTION" = "mount" ]
  then
    TITLE="BitLocker Drive List"
    TEXT="Select the Bitlocker drive to be mounted:"
    OK_LABEL="Mount Drive"
    SUFFIX_TMP_FILE="mounted"
  else
    TITLE="Currently mounted Bitlocker drives"
    TEXT="Select the Bitlocker drive to be unmounted:"
    OK_LABEL="Unmount Drive"
    SUFFIX_TMP_FILE="not_mounted"
  fi

  clearTMPFiles

  getSelectionListBitlockerDrives

  #if there is any valid bitlocker drive
  if [ -f "/tmp/drive_selection_list-$SUFFIX_TMP_FILE.txt" ]
  then
      DRIVE_SELECT_LIST=$(cat /tmp/drive_selection_list.txt)
      DRIVE_SELECTED=$(zenity --list --title="$TITLE" \
                              --text="$TEXT" \
                              --radiolist \
                              --width="450" \
                              --column ' ' --column 'Drive' --column 'Brand/Model' --column 'Size' \
                              --ok-label="$OK_LABEL" \
                              $DRIVE_SELECT_LIST)

      #if a drive was selected
      if [ -n "$DRIVE_SELECTED" ] && [ $ACTION = "mount"]
      then
          mountDrive $DRIVE_SELECTED
      elif [ -n "$DRIVE_SELECTED" ] && [ $ACTION = "mount"]
      then
          unmountDrive $DRIVE_SELECTED
      else
          errorMessage "No Bitlocker drive selected!"
      fi
      clearTMPFiles
  else
      errorBitlockerDriveNotFound
  fi
}

function mainWindow
{
    ACTION_SELECTED=$(zenity --list --title="Dislocker-GUI-Zenity" \
                    --text="Mount/Unmount Bitlocker encrypted drives.\nWhat would you like to do?" \
                    --column="What would you like to do?" 'Mount' 'Unmount')

    windowSelectDrive $ACTION_SELECTED
}

function isDriveMounted
{
    DRIVE=$1

    PATH_MOUNT_POINT= getPathMountPoint $DRIVE
    PATH_DISLOCKER_FILE= getPathDislockerFile $DRIVE
    echo $(sudo /opt/dislocker-gui/util-root.sh "isDriveMounted" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE)
}

checkDependencies
mainWindow
