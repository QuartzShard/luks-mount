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

USAGE="Usage: luks-mount [-n <profile>|-p <profile>|-h] [mount|umount|setup|help]"

source /usr/local/lib/luks-mount.shlib
if [[ "$(config_get configured default.cfg)" == *"false"* ]]; then
echo 'No default config found, please set one:'
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
		mntpath="$(config_get mntpath default.cfg)"
	fi
	done
	echo "#Device UUID
uuid=${uuid}
#name of directory
mntname=${mntname}
#Default mount path in /mnt/
mntpath=${mntpath}
#Flag for config script
configured='true' " > /etc/luks-mount/default.cfg
	luks-mount help
	exit
else
	uuid="$(config_get uuid default.cfg)"
	mntname="$(config_get mntname default.cfg)"
	mntpath="$(config_get mntpath default.cfg)"
	while getopts "hp::n::" arg; do
	case $arg in
	h)
		luks-mount help
		exit
		;;
	n)
		echo "Creating new config profile ${OPTARG}:"
		uuid=''
		mntname=''
		while [[ $uuid == '' && $mntname == '' ]]; do
			echo -n "Device uuid (luks-UUID_String): "
			read uuid
			echo -n "mount name: "
			read mntname
			echo -n "mount path (default /mnt/${mntname}, exclude mount name if custom): "
			read mountpath
			if [[ $mountpath == *'/'* ]]; then
				mntpath=$mountpath
			else
				mntpath="$(config_get mntpath default.cfg)"
			fi
		done
	echo "#Device UUID
uuid=${uuid}
#name of directory
mntname=${mntname}
#Default mount path in /mnt/
mntpath=${mntpath}
#Flag for config script
configured='true' " > /etc/luks-mount/${OPTARG}.cfg
		uuid="$(config_get uuid ${OPTARG}.cfg)"
		mntname="$(config_get mntname ${OPTARG}.cfg)"
		mntpath="$(config_get mntpath ${OPTARG}.cfg)"
		;;	
	p)
		uuid="$(config_get uuid ${OPTARG}.cfg)"
		mntname="$(config_get mntname ${OPTARG}.cfg)"
		mntpath="$(config_get mntpath ${OPTARG}.cfg)"
		;;
	esac
	done
fi

#Check args
ARG1=${@:$OPTIND:1}
ARG2=${@:$OPTIND+1:1}
if [[ ${ARG1} == *'help'* ]] ; then #Print help
	echo ${USAGE}
	echo 'Flags:'
	echo '	-p <profile name>: specify a profile to use over default'
	echo ' 	-n <profile name>: configure a new profile'
	echo '	-h: display this help'
	echo 'Options:'
	echo '	mount <device>: Prompt for LUKS key and mount the partition'
	echo '	umount: Unmount the drive and lock the LUKS partition'
	echo '	setup <device>: Create a new LUKS partition on the device (WARNING; Will overwrite all data on device)'
	echo '	help: Display this information'
elif [[ ( ${ARG1} == 'mount'* && ${ARG2} == 'sd'* ) ]] ; then #Unlock & mount
	cryptsetup luksOpen /dev/${ARG2} $uuid 
	if [ ! -d "${mntpath}${mntname}" ]; then
		mkdir -p ${mntpath}${mntname}
	fi
	mount /dev/mapper/$uuid $mntpath$mntname
	mntstr=$(df -h | grep $mntname || echo 'Error! Drive not mounted.')
	echo 'Device mount details:'
	echo $mntstr
elif [[ ${ARG1} == 'umount'* ]] ; then #Unmount & lock
	umount $mntpath$mntname
	cryptsetup luksClose /dev/mapper/$uuid
	systemctl daemon-reload
elif [[ (${ARG1} == *'setup'* && ${ARG2} == 'sd'* )]] ; then
	cryptsetup -y -v luksFormat /dev/${ARG2}
	cryptsetup luksOpen /dev/${ARG2} $uuid
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
	echo ${USAGE}
fi
