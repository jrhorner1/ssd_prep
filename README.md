## Raspberry Pi 4 SSD preparation script for USB boot

### What is this? 
Simply put, this is a script that automates the installation and configuration of Ubuntu 21.04 on an SSD for the Raspberry Pi 4. 

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
The first thing you need is a MicroSD card setup with Raspberry Pi OS. Raspberry Pi Foundation provides a tool to make this step easy so, go grab that tool, flash your SD card, then come back here.

You will probably also want to have your pi hooked up to a monitor with a keyboard and an ethernet connection. Don't worry if you don't have that kind of setup, everything can be done via SSH as well, so if thats the case, make sure to plug in the ethernet cable or configure WiFi settings.

Install git and clone this repo:
```bash
sudo apt -y install git
git clone https://github.com/jrhorner1/ssd_prep.git
```

Update the eeprom on your Pi 4 to the latest version and configure the boot order:
```bash
sudo ./rpi-eeprom.sh
```

Plug in your SSD and run the script:
```bash
cd ssd_prep/
sudo ./ssd_prep.sh
```

Thats it. Your SSD is prepped and ready to go. Reboot your Pi and it should boot from the SSD. 