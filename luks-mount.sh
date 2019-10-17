#!/bin/bash
#Quartzshard, 2019

#Check is script is running as root
if [[ $EUID > 0 ]]; then
	echo 'Please run as root (sudo luks-mount...)'
	exit
fi
#Check if cryptsetup is present, if not, installs it (Debian environment)
if [ $(dpkg-query -W -f='${Status}' cryptsetup 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install cryptsetup -y;
fi

source /usr/local/lib/luks-mount.shlib
if [[ "$(config_get configured)" == *"false"* ]]; then
while [[ $uuid == '' && $mntname == '' ]]; do
	echo -n "Device uuid (luks-UUID_String): "
	read uuid
	echo -n "mount name: "
	read mntname
	echo -n "mount path (default /mnt/${mntname}, exclude mount name if custom): "
	read mountpath
	if [[ $mountpath == *'/'* ]]; then
		mntpath=mountpath
	else
		mntpath="$(config_get mntpath)"
	fi
	done
	configured="true"
	echo "#Device UUID
uuid=${uuid}
#name of directory
mntname=${mntname}
#Default mount path in /mnt/
mntpath=${mntpath}
#Flag for config script
configured='true' " > /etc/luks-mount.cfg
	luks-mount help
	exit
else
	uuid="$(config_get uuid)"
	mntname="$(config_get mntname)"
	mntpath="$(config_get mntpath)"
fi

#Check args
if [[ $1 == *'help'* ]] ; then #Print help
	echo 'Usage: luks-mount <Option>'
	echo 'Options:'
	echo '	mount <device>: Prompt for LUKS key and mount the partition'
	echo '	umount: Unmount the drive and lock the LUKS partition'
	echo '	setup <device>: Create a new LUKS partition on the device'
	echo ' 	                (WARNING; Will overwrite all data on device)'
	echo '	help: Display this information'
elif [[ ( $1 == 'mount'* && $2 == 'sd'* ) ]] ; then #Unlock & mount
	cryptsetup luksOpen /dev/$2 $uuid 
	mount /dev/mapper/$uuid $mntpath$mntname
	mntstr=$(df -h | grep $mntname || echo 'Error! Drive not mounted.')
	echo 'Device mount details:'
	echo $mntstr
elif [[ $1 == 'umount'* ]] ; then #Unmount & lock
	umount $mntpath$mntname
	cryptsetup luksClose /dev/mapper/$uuid
	systemctl daemon-reload
elif [[ ($1 == *'setup'* && $2 == 'sd'* )]] ; then
	cryptsetup -y -v luksFormat /dev/$2
	cryptsetup luksOpen /dev/$2 $uuid
	echo -n "Write zeros to new partition? (Slow, but adds security) [Y/N]: "
	read zero
	if [[$zero == 'Y']]; then
		dd if=/dev/zero of=/dev/mapper/$uuid status=progress
	fi
	mkfs.ext4 /dev/mapper/$uuid
	mkdir $mntpath$mntname
	mount /dev/mapper/$uuid $mntpath$mntname
	mntstr=$(df -h | grep $mntname || echo 'Error! Drive not mounted.')
	echo 'Device mount details:'
	echo $mntstr
else
	echo "Unkown usage case, try 'luks-mount help'."
fi
