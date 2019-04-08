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
#Zenity based GUI for mounting and unmounting BitLocker drives using dislocker

function getPathMountPoint
{
    DRIVE_SELECTED=$1
    DRIVE_MOUNTPOINT_BASE="/mnt/BitLockerDrive"

    echo "$DRIVE_MOUNTPOINT_BASE-$DRIVE_SELECTED"
}

function getPathDislockerFile
{
  DRIVE_SELECTED=$1
  DFILE_LOCATION_BASE="/tmp/DFILE"

  echo "$DFILE_LOCATION_BASE-$DRIVE_SELECTED"
}

function openFileBrowser
{
    PATH_MOUNT_POINT=$1

    SUPPORTED_FILE_BROWSER_NOT_FOUND=0
    if type nautilus > /dev/null
    then
        FILE_BROWSER="nautilus"
    elif type dolphin > /dev/null
    then
        FILE_BROWSER="dolphin"
    elif type thunar > /dev/null
    then
        FILE_BROWSER="thunar"
    elif type nemo > /dev/null
    then
      FILE_BROWSER="nemo"
    else
        SUPPORTED_FILE_BROWSER_NOT_FOUND=1
        zenity --info --title="File Browser Not Found"
                      --text="Nautilus/Dolphin/Thunar/Nemo not found\n\nOpen your file browser at $PATH_MOUNT_POINT"
    fi

    if !(($SUPPORTED_FILE_BROWSER_NOT_FOUND))
    then
      $($FILE_BROWSER $PATH_MOUNT_POINT) > /dev/null
    fi
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
        errorMessage "Missing dependency 'Dislocker'. Please install it before using this app.
                                                            \n\nFor Ubuntu: sudo apt install dislocker
                                                            \n\nFor Fedora: sudo dnf install fuse-dislocker
                                                            \n\nMore info at: https://github.com/Aorimn/dislocker"
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

function getMountedBitLockerDrives
{
    echo $(getSelectionListBitLockerDrives "mounted")
}

function getNotMountedBitLockerDrives
{
  echo $(getSelectionListBitLockerDrives "unmounted")
}

function getSelectionListBitLockerDrives
{
    STATUS=$1
    #get list of NTFS/exFAT/HPFS/FAT drives and saves the list to the temp file
    getListSupportedDrives

    #if there are any ntfs/exFAT/HPFS drives attached
    if [ -f "/tmp/fdisk.txt" ]
    then
        DRIVE_FOUND=0
        #for each candidate drive test if it is a bitlocker drive
        for drive in $(cat /tmp/fdisk.txt)
        do
            #if it is a valid bitlocker drive
            if [ $(isBitLockerDrive $drive) = "0" ]
            then
                size=$(getDiskSizeGB $drive)
                brandNModel=$(getDiskBrandNModel $drive)

                DRIVE_MOUNTED=$(isDriveMounted $drive)
                #if the parameter is MOUNTED... only add mounted drives to list
                #if the parameter is NOT_MOUNTED... only add not mounted drives to the list
                if [[ ( $STATUS = "mounted" ) && ("$DRIVE_MOUNTED" = "0") ]] ||
                   [[ ( $STATUS = "unmounted" ) && ("$DRIVE_MOUNTED" = "1") ]]
                then
                  #creates a table for the drive selection interface. FALSE indicates that the option is by default not selected on the gui
                  DRIVE_FOUND=1
                  echo "FALSE $drive $brandNModel $size" >> /tmp/drive_selection_list-$STATUS.txt
                fi
            fi
        done

        #if no drive found with the desired status (mounted/unmounted) close the app
        if !(($DRIVE_FOUND))
        then
          errorBitLockerDriveNotFound $STATUS
        fi
    else
        #if no bitlocker drive found close the app
        errorBitLockerDriveNotFound ""

    fi
    echo $DRIVE_FOUND
}

function errorBitLockerDriveNotFound
{
    STATUS=$1
    errorMessage "No $STATUS BitLocker drives found!"
}

function getDiskFromPartition
{
    PARTITION=$1
    echo $PARTITION | cut -c1-3
}

function getDiskSizeGB
{
    PARTITION=$1

    #get the size of the disk in GB
    lsblk /dev/$PARTITION -n -o SIZE
}

function getDiskBrandNModel
{
    PARTITION=$1
    DISK=$(getDiskFromPartition $PARTITION)

    #the disk vendor and model info are located after the 8th char on the output of the command
    #sed command replace spaces with underscores
    lsblk -o NAME,VENDOR,MODEL | grep $DISK | grep -v $PARTITION | cut -c8- | sed -e 's/ /_/g'
}

function isBitLockerDrive
{
    DRIVE=$1

    #return 0 if true
    #return 1 if false
    sudo /opt/dislocker-gui/util-root.sh "isBitLockerDrive" $DRIVE
}

function createMountDirs
{
  PATH_MOUNT_POINT=$1
  PATH_DISLOCKER_FILE=$2
  sudo /opt/dislocker-gui/util-root.sh "createMountDir" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE
}

function mountDrive
{
    DRIVE_SELECTED=$1
    PATH_MOUNT_POINT=$(getPathMountPoint $DRIVE_SELECTED)
    PATH_DISLOCKER_FILE=$(getPathDislockerFile $DRIVE_SELECTED)

    createMountDirs $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE

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
                errorMessage "Wrong BitLocker password!\nPlease try again."
            fi
        else
            errorMessage "No password supplied!"
        fi
    done

    ID_MAIN_USER_GROUP=$(id -g)
    (sudo /opt/dislocker-gui/util-root.sh "mount" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE $UID $ID_MAIN_USER_GROUP) |
        zenity --progress --pulsate --auto-close --text="Please wait...\nMounting BitLockerDrive..." --title="Mounting Drive $DRIVE_SELECTED..."

    #open the file browser on the mount point directory
    openFileBrowser $PATH_MOUNT_POINT

    TITLE="Drive mounted at $PATH_MOUNT_POINT"
    MSG="To eject your drive safely ALWAYS use this app instead of the file browser eject button!!!"
    windowOperationSuccess "$TITLE"  "$MSG"
}

function unmountDrive
{
  DRIVE_SELECTED=$1
  PATH_MOUNT_POINT=$(getPathMountPoint $DRIVE_SELECTED)
  PATH_DISLOCKER_FILE=$(getPathDislockerFile $DRIVE_SELECTED)

  (sudo /opt/dislocker-gui/util-root.sh "unmount" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE) |
      zenity --progress --pulsate --auto-close --text="Please wait...\nSaving data..." --title="Saving Data..."

  #check if drive status changed to unmounted (ejected successfully)
  if [ "$(isDriveMounted $DRIVE_SELECTED)" = "1" ]
  then
      #after drive ejected remove empty mount directories
      (sudo /opt/dislocker-gui/util-root.sh "clearMountDir" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE)
      TITLE="BitLockerDrive Ejected"
      MSG="Now your BitLockerDrive can be removed safely."
      windowOperationSuccess "$TITLE" "$MSG"
  else
      errorMessage "Unable to eject BitLockerDrive.\nBefore trying to eject again, please close any opened file browser windows\nand make sure there are no files from the drive currently opened."
  fi
}

function windowOperationSuccess
{
  TITLE=$1
  MESSAGE=$2

  zenity --question --title="$TITLE" --no-wrap \
                      --text="$MESSAGE \n\What would you like to do?" \
                      --ok-label="Mount/Unmount another drive" --cancel-label="Close"

  #if the user clicks the close button or close the window
  #then close the app
  if [ "$?" = "1" ]
  then
        exit 0
  fi
}

function windowSelectDrive
{
  ACTION=$1

  STATUS=""
  clearTMPFiles
  if [ "$ACTION" = "Mount" ]
  then
    TITLE="BitLocker Drive List"
    TEXT="Select the BitLocker drive to be mounted:"
    OK_LABEL="Mount Drive"

    #before mounting a drive the app loads a list of currently unmounted drives
    SUFFIX_TMP_FILE="unmounted"

    DRIVE_FOUND=$(getNotMountedBitLockerDrives)
  else
    TITLE="Currently mounted BitLocker drives"
    TEXT="Select the BitLocker drive to be unmounted:"
    OK_LABEL="Unmount Drive"

    #before unmounting a drive the app loads a list of currently mounted drives
    SUFFIX_TMP_FILE="mounted"

    DRIVE_FOUND=$(getMountedBitLockerDrives)
  fi

  #if at least one drive was found
  if [ "$DRIVE_FOUND" != "0" ]
  then

    #show the list of drives for user selection
    DRIVE_SELECT_LIST=$(cat /tmp/drive_selection_list-"$SUFFIX_TMP_FILE".txt)
    DRIVE_SELECTED=$(zenity --list --title="$TITLE" \
                            --text="$TEXT" \
                            --radiolist \
                            --width="500" \
                            --height="450" \
                            --column ' ' --column 'Drive' --column 'Brand/Model' --column 'Size' \
                            --ok-label="$OK_LABEL" \
                            $DRIVE_SELECT_LIST)

    #if a drive was selected
    if [[ -n "$DRIVE_SELECTED" ]] && [[ $ACTION = "Mount" ]]
    then
        mountDrive $DRIVE_SELECTED
    elif [[ -n "$DRIVE_SELECTED" ]] && [[ $ACTION = "Unmount" ]]
    then
        unmountDrive $DRIVE_SELECTED
    else
        errorMessage "No drive selected!"
    fi
    clearTMPFiles
  fi
}

function mainWindow
{
    ACTION_SELECTED="INIT_LOOP"
    #loop the main window until the user clicks the window close button or the cancel button
    while [ -n "$ACTION_SELECTED" ]
    do
      ACTION_SELECTED=$(zenity --list --title="Dislocker-GUI-Zenity" \
                      --text="Mount/Unmount BitLocker encrypted drives." \
                      --column="What would you like to do?" 'Mount' 'Unmount' \
                      --height=250)

      #only do something if mount/umount clicked
      #if click cancel or close window do nothing
      if [ -n "$ACTION_SELECTED" ]
      then
        windowSelectDrive $ACTION_SELECTED
      fi
    done
}

function isDriveMounted
{
    DRIVE=$1

    PATH_MOUNT_POINT=$(getPathMountPoint $DRIVE)
    PATH_DISLOCKER_FILE=$(getPathDislockerFile $DRIVE)

    sudo /opt/dislocker-gui/util-root.sh "isDriveMounted" $PATH_MOUNT_POINT $PATH_DISLOCKER_FILE
}

checkDependencies
mainWindow
