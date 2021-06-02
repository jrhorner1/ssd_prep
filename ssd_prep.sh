#!/bin/bash

# VARS
TARGETDEV=/dev/sda
UBUNTUIMG=ubuntu-21.04-preinstalled-server-arm64+raspi.img
MNTBOOT=/mnt/boot
MNTROOT=/mnt

HOSTNAME="${HOSTNAME:=""}"
NETPLAN_CONFIG="${NETPLAN_CONFIG:="99_config.yaml"}"
IP="${IP:=""}"
CIDR="${CIDR:="24"}"
GATEWAY="${GATEWAY:="$(echo $IP | sed -r 's/^([0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.)[0-9]{,3}/\11/')"}"
if [ $(echo $HOSTNAME | grep "\.") == "" ]; then
    DNS_SEARCH=${DNS_SEARCH:=""}
else
    DNS_SEARCH="${DNS_SEARCH:="$(echo $HOSTNAME | sed -r 's/^[a-z0-9\-_]+\.([a-z0-9\-_.]+)$/\1/')"}"
fi
DNS_ADDRS="${DNS_ADDRS:="$(grep "nameserver" /etc/resolv.conf | sed -r 's/^nameserver ([0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3})/\1/' | awk '{printf("%s ", $0)}' | sed -r 's/(.+) (.+)/\1, \2/')"}"

# check if running as root
if [ $(whoami) != "root" ]; then
    echo 'Try: sudo !!'
    exit 1
fi

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
+20G # extend partition to 20gb
p # print partition table again
n # create a new partition
p # primary partition
3 # partition number 3
 # default beginning of partition
 # default extend to the full capacity
p # print partitions
w # write changes
q # quit
EOF

# Mount target device, root first then boot
mount ${TARGETDEV}2 $MNTROOT
mount ${TARGETDEV}1 $MNTBOOT

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

# Set the hostname
if [ ${HOSTNAME} != "" ]; then
    echo ${HOSTNAME} > $MNTROOT/etc/hostname
    sed -ri "s/^(127.0.0.1 +localhost)/\1 ${HOSTNAME}/" $MNTROOT/etc/hosts
fi

# Static IP configuration
if [ ${IP} != "" ]; then
    # Disable Cloud config
    cp 99_disable_network_config.cfg ${MNTROOT}/etc/cloud/cloud.cfg.d/
    # Configure static IP
    cat <<EOF > ${MNTROOT}/etc/netplan/${NETPLAN_CONFIG}
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      dhcp6: no
      addresses:
        - ${IP}/${CIDR}
      gateway4: ${GATEWAY}
      nameservers:
        search: [ ${DNS_SEARCH} ]
        addresses: [ ${DNS_ADDRS} ]
EOF
fi

# unmount target device, boot first then root
umount $MNTBOOT
umount $MNTROOT