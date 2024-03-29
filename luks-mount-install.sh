#!/bin/bash
#Quartzshard, 2019

#Check is script is running as root
if [[ $EUID > 0 ]]; then
	echo 'Please run as root (sudo ./luks-mount-install...)'
	exit
fi

mv ./luks-mount.sh /usr/local/bin/luks-mount
mv ./luks-mount.shlib /usr/local/lib/
mkdir /etc/luks-mount
mv ./luks-mount.cfg /etc/luks-mount/default.cfg
chmod a+x /usr/local/bin/luks-mount
echo "Installed Successfully!"
rm ./luks-mount-install.sh 