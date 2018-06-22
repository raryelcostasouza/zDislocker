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

#dislocker-gui-zenity
#Zenity based GUI for mounting and umounting Bitlocker drives using dislocker

DRIVE_MOUNTPOINT="/media/BitLockerDrive"

function openFileBrowser
{
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
                      --text="Nautilus/Dolphin/Thunar not found\n\nOpen your file browser at $DRIVE_MOUNTPOINT"
        exit
    fi
    $($FILE_BROWSER $DRIVE_MOUNTPOINT)
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
        zenity --error --title="Dislocker Not Found" --no-wrap --text="Missing dependency 'Dislocker'. Please install it before using this script.
                                                            \n\nFor Ubuntu: sudo apt install dislocker
                                                            \n\nFor Fedora: sudo dnf install fuse-dislocker"
        exit;
    fi
}

function clearTMPFiles
{
    sudo ./util.sh "clearTMP"
}

function errorMessage
{
    MESSAGE=$1
    zenity --error --title="Error" --no-wrap --text="$1"
}

function getListNTFSDrives
{
    sudo ./util.sh "getListNTFSDrives"
}

function getSelectionListBitlockerDrive
{
    #get list of NTFS/exFAT/HPFS drives and saves the list to the temp file
    getListNTFSDrives

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

                #creates a table for the drive selection interface. FALSE indicates that the option is by default not selected on the gui
                echo "FALSE $drive $brandNModel $size" >> /tmp/drive_selection_list.txt
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

    #the disk vendor and model info are located after the 18th char on the output of the command
    #sed command replace spaces with underscores
    echo $(lsblk -o NAME,VENDOR,MODEL | grep $DISK | grep -v $PARTITION | cut -c13- | sed -e 's/ /_/g')
}

function isBitlockerDrive
{
    DRIVE=$1

    #return 0 if true
    #return 1 if false
    echo $(sudo ./util.sh "isBitlockerDrive" $DRIVE)
}

function mountDrive
{
    DRIVE=$1

    sudo ./util.sh "createMountDir" $DRIVE_MOUNTPOINT

    #loop until the user supplies a valid password
    PASSWORD_WRONG=0
    while [ "$PASSWORD_WRONG" = "0" ]
    do
        DRIVE_PASSWORD=$(zenity --password --title="Locked Drive" --text="Please type the password for the BitLocker drive")
        #if the password field is not empty
        if [ -n "$DRIVE_PASSWORD" ]
        then
            #try to unlock the drive
            PASSWORD_WRONG=$(sudo ./util.sh "decrypt" $DRIVE $DRIVE_PASSWORD)

            #if the output contains the string "Can't decrypt correctly the VMK." it means the password supplied is wrong
            if [ "$PASSWORD_WRONG" = "0" ]
            then
                errorMessage "Wrong Bitlocker password! Please try again."
            fi
        else
            errorMessage "No password supplied!"
        fi
    done

    sudo ./util.sh "mount" $DRIVE_MOUNTPOINT

    #open the file browser on the mount point directory
    openFileBrowser
  }

function actionMountDrive
{
    clearTMPFiles

    getSelectionListBitlockerDrive

    #if there is any valid bitlocker drive
    if [ -f "/tmp/drive_selection_list.txt" ]
    then
        DRIVE_SELECT_LIST=$(cat /tmp/drive_selection_list.txt)
        DRIVE_SELECTED=$(zenity --list --title="BitLocker Drive List" \
                                --text="Select the Bitlocker drive to be mounted:" \
                                --radiolist --multiple \
                                --width="450" \
                                --column ' ' --column 'Drive' --column 'Brand/Model' --column 'Size' \
                                $DRIVE_SELECT_LIST)

        #if a drive was selected
        if [ -n "$DRIVE_SELECTED" ]
        then
            mountDrive $DRIVE_SELECTED
        else
            errorMessage "No Bitlocker drive selected!"
        fi
        clearTMPFiles
    else
        errorBitlockerDriveNotFound
    fi

}

function actionUmountDrive
{
    sudo ./util.sh "umount" $DRIVE_MOUNTPOINT
}

function checkBitlockerDriveMounted
{
    echo $(sudo ./util.sh "checkBitLockerDriveMounted" $DRIVE_MOUNTPOINT)
}

checkDependencies

#check if there is any bitlocker drive currently mounted
if [ "$(checkBitlockerDriveMounted)" = "0" ]
then
    zenity --question --title="Bitlocker Drive already mounted" --no-wrap \
                      --text="There is a Bitlocker drive currently mounted.\n\nWhat would you like to do?" \
                      --ok-label="Remove it safely" --cancel-label="Nothing"

    #if the user clicked the ok button (Remove it Safely)
    if [ "$?" = "0" ]
    then
        actionUmountDrive
    fi
else
    actionMountDrive
fi
