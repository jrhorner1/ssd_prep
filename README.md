#  

## Raspberry Pi 4 SSD preparation script for USB boot  

### What is this?  

Simply put, this is a script that automates the installation and configuration of Ubuntu 22.04 on an SSD for the Raspberry Pi 4.  

### What does it do exactly?  

It does several things necessary for the successful booting of Ubuntu from an SSD on the Pi 4.

* Download (if necessary) the Ubuntu image
* Install Ubuntu 21.04 LTS to the SSD
* Resize the partitions (this is not done automatically when using `dd`)
* Decompress the linux kernel
* Setup a script and APT hook to automatically decompress the kernel after updates
* Download and install the latest Raspberry Pi firmware
* Update the Pi config to use the decompressed kernel during boot

### How can I use this?  

The first thing you need is a MicroSD card setup with Raspberry Pi OS. Raspberry Pi Foundation provides a tool to make this step easy so, go grab the [imager](https://downloads.raspberrypi.org/imager/), flash your SD card, then come back here. RaspiOS arm64 images are located [here](https://downloads.raspberrypi.org/raspios_lite_arm64/images/).

You will probably also want to have your pi hooked up to a monitor with a keyboard and an ethernet connection. Don't worry if you don't have that kind of setup, everything can be done via SSH as well, so if thats the case, make sure to plug in the ethernet cable or configure WiFi settings.

Install git and clone this repo:

```bash
sudo apt -y install git
git clone https://github.com/jrhorner1/ssd_prep.git
```

Update the eeprom on your Pi 4 to the latest version and configure the boot order:

```bash
cd ssd_prep/
sudo ./rpi-eeprom.sh
```

Plug in your SSD and run the script:

```bash
sudo ./ssd_prep.sh
```

Thats it. Your SSD is prepped and ready to go. Reboot your Pi and it should boot from the SSD.  

## Optional Features

### Hostname configuration

Specify the hostname as an environment variable when running the script:

```bash
sudo HOSTNAME="myhostname.example.com" ./ssd_prep.sh
```

This sets your hostname in `/etc/hostname` and adds it to the localhost entry in `/etc/hosts`.

### Static IP configuration

Specify the IP configuration as environment variables when running the script:

```bash
sudo IP=192.168.1.100 CIDR=24 GATEWAY=192.168.1.1 DNS_SEARCH="example.com" DNS_ADDRS="1.1.1.1, 1.0.0.1" ./ssd_prep.sh
```

This will disable cloud configuration and setup a static IP using Netplan. Paths to the files involved are as follows:

* `/etc/cloud/cloud.cfg.d/99_disable_cloud_config.cfg`
* `/etc/netplan/99_config.yaml` (This filename is configurable.)

### OpenEBS Mount

Change the `USE_OPENEBS` variable to `1` to create the mount point and add an `/etc/fstab` entry.  

## Script variables

|Variable|Value|Description|
|---|---|---|
|TARGETDEV|/dev/sda|Device path for your SSD.|
|UBUNTUIMG|ubuntu-21.04-preinstalled-server-arm64+raspi.img|Ubuntu 21.04 LTS image filename.|
|MNTBOOT|/mnt/boot|Path to mount your boot partition to.|
|MNTROOT|/mnt/root|Path to mount your root partition to.|
|HOSTNAME| |No default value is set.|
|NETPLAN_CONFIG|99_config.yaml|Generic netplan configuration file name.|
|IP| |No default value is set.| 
|CIDR|24|The standard subnet size for class C private networks with 254 usable addresses.|
|GATEWAY| |This uses a sed command to set the gateway to the first address in the IP's subnet, ie. if your IP is 192.168.1.54 the gateway will be 192.168.1.1. Note: does not work if the CIDR isn't 24.|
|DNS_SEARCH| |By default, this will determine if a domain is appended to your hostname and if so, set that as the value. Otherwise it is not set.|
|DNS_ADDRS| |This uses a sed command to pull your nameservers from `/etc/resolv.conf` in Raspberry Pi OS which would have been set by DHCP by default.|
