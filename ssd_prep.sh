#!/bin/bash

# VARS
TARGETDEV=/dev/sda
UBUNTUIMG=ubuntu-21.04-preinstalled-server-arm64+raspi.img
MNTBOOT=/mnt/boot
MNTROOT=/mnt/root


# check if ubuntu image exists
if [ ! -f "$UBUNTUIMG" ]; then
	# if not download image
	curl -O https://cdimage.ubuntu.com/releases/21.04/release/${UBUNTUIMG}.xz
	xz -d ${UBUNTUIMG}.xz
fi

# check if target device exists
if [ ! -e $TARGETDEV ]; then
	echo "plugin the ssd nerd"
	exit 1
fi
# flash the ubuntu image
dd status=progress if=$UBUNTUIMG of=$TARGETDEV bs=4M

# resize the root partition
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk $TARGETDEV
p # print the partion table
d # delete a partition
2 # select partition 2
n # new partition
p # primary partition
2 # partion number 2
526336 # begining of the original partition 
+20G  # extend partition to 20gb
n # do not overwrite signature
p # print partition table again
n # new partition
p # primary partition
3 # partion number 3
 # default, begining of the new partition 
 # default, extend partition to the end of the disk
p # print partition table once more
w # write changes
q # quit
EOF


# Mount disk
mount ${TARGETDEV}1 $MNTBOOT
mount ${TARGETDEV}2 $MNTROOT

# Decompress kernel
cp $MNTBOOT/vmlinuz ./
zcat ./vmlinuz > ./vmlinux
cp ./vmlinux $MNTBOOT

# Script to decompress kernel after updates
cp auto_decompress_kernel $MNTBOOT
cp 999_decompress_rpi_kernel $MNTROOT/etc/apt/apt.conf.d/
chmod +x $MNTROOT/etc/apt/apt.conf.d/999_decompress_rpi_kernel

# check if firmware folder exists
if [ ! -d ./firmware ]; then
	# if not, make it and download the firmware
	mkdir ./firmware
	cd ./firmware
	wget $( wget -qO - https://github.com/raspberrypi/firmware/tree/master/boot | perl -nE 'chomp; next unless /[.](elf|dat)/; s/.*href="([^"]+)".*/$1/; s/blob/raw/; say qq{https://github.com$_}' )
	cd ../
fi
# copy updated firmware to boot partition
cp ./firmware/* $MNTBOOT

# Update config to use decompressed kernel
cp ./config.txt $MNTBOOT
