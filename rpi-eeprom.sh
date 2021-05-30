#!/bin/bash

# variables
REBOOT_TIMER=1
EEPROM_CONFIG=boot.conf

# check if running as root
if [ $(whoami) != "root" ];
    echo 'Try: sudo !!'
    exit 1
fi

# reinstall the rpi-eeprom package
apt -y reinstall rpi-eeprom
# install the latest eeprom
rpi-eeprom-update -d -a
# apply the eeprom config
rpi-eeprom-config --apply ${EEPROM_CONFIG}
# notify user of reboot and send it
shutdown -r +${REBOOT_TIMER} "Rebooting in ${REBOOT_TIMER} minute(s) to apply EEPROM upgrade/configuration."