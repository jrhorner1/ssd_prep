#!/bin/bash

# check if running as root
if [ $(whoami) != "root" ]; then
    echo 'Try: sudo !!'
    exit 1
fi

# VARS
TARGETDEV=/dev/sda
UBUNTUVER=21.04
UBUNTUIMG=ubuntu-21.04-preinstalled-server-arm64+raspi.img
MNTBOOT=/mnt/boot/firmware
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

# check if ubuntu image exists
if [ ! -f "$UBUNTUIMG" ]; then
    # if not: download image, checksums, and signature
    echo "Downloading SHA-256 checksums..."
    curl -O https://cdimage.ubuntu.com/releases/${UBUNTUVER}/release/SHA256SUMS
    echo "Downloading SHA-256 checksums signature..."
    curl -O https://cdimage.ubuntu.com/releases/${UBUNTUVER}/release/SHA256SUMS.gpg
    echo "Downloading image..."
    curl -O https://cdimage.ubuntu.com/releases/${UBUNTUVER}/release/${UBUNTUIMG}.xz
    # Retrieve Ubuntu keys from their keyserver 
    # Ref. https://ubuntu.com/tutorials/how-to-verify-ubuntu#4-retrieve-the-correct-signature-key
    UBUNTU_KEY_1="0x46181433FBB75451"
    UBUNTU_KEY_2="0xD94AA3F0EFE21092"
    echo "Retrieving signature keys from the Ubuntu keyserver..."
    gpg --keyid-format long --keyserver hkp://keyserver.ubuntu.com --recv-keys ${UBUNTU_KEY_1} ${UBUNTU_KEY_2}
    gpg --keyid-format long --list-keys --with-fingerprint ${UBUNTU_KEY_1} ${UBUNTU_KEY_2}
    # Verify the downloaded checksums
    echo "Verifying SHA-256 checksums signature..."
    gpg --keyid-format long --verify SHA256SUMS.gpg SHA256SUMS
    if [ ! $? -eq 0 ]; then
        echo "Signature doesn't match."
        exit 1
    fi
    # Verify the downloaded image
    echo "Verifying image checksum..."
    sha256sum -c SHA256SUMS 2>&1 | grep OK
    if [ ! $? -eq 0 ]; then
        echo "SHA-256 sum doesn't match."
        exit 1
    fi
    echo "Decompressing the image..."
    xz -d ${UBUNTUIMG}.xz
fi

# check if target device exists
if [ ! -e $TARGETDEV ]; then
    echo "Plugin the ssd, nerd."
    exit 1
fi
# flash the ubuntu image
echo "Writing image to ${TARGETDEV}..."
dd status=progress if=$UBUNTUIMG of=$TARGETDEV bs=4M

# resize the root partition
echo "Resizing ${TARGETDEV}2 and adding another partition..."
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
echo "Mounting ${TARGETDEV} partitions..."
mount ${TARGETDEV}2 $MNTROOT
mount ${TARGETDEV}1 $MNTBOOT

# Decompress kernel
echo "Decompressing kernel..."
cp $MNTBOOT/vmlinuz ./
zcat ./vmlinuz > ./vmlinux
cp ./vmlinux $MNTBOOT

# Script to decompress kernel after updates
echo "Configuring apt to decompress any kernel updates..."
cp auto_decompress_kernel $MNTBOOT
cp 999_decompress_rpi_kernel $MNTROOT/etc/apt/apt.conf.d/
chmod +x $MNTROOT/etc/apt/apt.conf.d/999_decompress_rpi_kernel

# check if firmware folder exists
if [ ! -d ./firmware ]; then
    # if not, make it and download the firmware
    echo "Downloading latest Raspberry Pi firmware..."
    mkdir ./firmware
    cd ./firmware
    wget $( wget -qO - https://github.com/raspberrypi/firmware/tree/master/boot | perl -nE 'chomp; next unless /[.](elf|dat)/; s/.*href="([^"]+)".*/$1/; s/blob/raw/; say qq{https://github.com$_}' )
    cd ../
fi
# copy updated firmware to boot partition
echo "Writing latest firmware to ${MNTBOOT}..."
cp ./firmware/* $MNTBOOT

# Update config to use decompressed kernel
echo "Writing updated config.txt to ${MNTBOOT}..."
cp ./config.txt $MNTBOOT

# Set the hostname
if [ ${HOSTNAME} != "" ]; then
    echo "Setting hostname to ${HOSTNAME}..."
    echo ${HOSTNAME} > $MNTROOT/etc/hostname
    sed -ri "s/^(127.0.0.1 +localhost)/\1 ${HOSTNAME}/" $MNTROOT/etc/hosts
fi

# Static IP configuration
if [ ${IP} != "" ]; then
    # Disable Cloud config
    echo "Disabling network cloud configuration..."
    cp 99_disable_network_config.cfg ${MNTROOT}/etc/cloud/cloud.cfg.d/
    # Configure static IP
    echo "Configuring static IP..."
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
echo "Unmounting ${TARGETDEV}..."
umount $MNTBOOT
umount $MNTROOT