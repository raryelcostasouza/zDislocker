#!/bin/bash

sudo dislocker -v -V /dev/sdb -u -- /mnt/tmp
sudo mount -o loop,rw /mnt/tmp/dislocker-file /media/dislocker/


    
