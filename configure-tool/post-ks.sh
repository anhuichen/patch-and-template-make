#!/bin/bash
# 0. pre-harden
hardendir="/home/harden-log"
executedir="/mnt/sysimage${hardendir}"
if [ -d ${executedir} ]; then
        rm -rf ${executedir}
fi
mkdir -p "${executedir}"

# 1. Execute EulerOS_Reiforce and osstdfix.py
/bin/cp -arf /run/install/repo/initial-setup/EulerOS_Reinforce "${executedir}"
/bin/cp -arf /run/install/repo/initial-setup/osstdclient/osstdfix.py "${executedir}"
/bin/cp initial-setup.sh "${executedir}"
/sbin/chroot /mnt/sysimage /bin/bash ${hardendir}/initial-setup.sh ${hardendir}
#/bin/cat << EOF | /sbin/chroot /mnt/sysimage /bin/bash 
#pwd
#ps -ef |grep bash
#/bin/cd /home/harden-log/EulerOS_Reinforce
#ps -ef |grep bash
#pwd
#/bin/bash /home/harden-log/EulerOS_Reinforce/EulerReinforce.sh
#/bin/cd /home/harden-log
#pwd
#/bin/python /home/harden-log/osstdfix.py
#EOF

## 3. Execute configure-tools
#/bin/cp -arf /run/install/repo/initial-setup /tmp
#/bin/cd /tmp/initial-setup
#/bin/bash /tmp/initial-setup/configure-tool.sh -c euleros-cloud.conf -d /mnt/sysimage/

## 4. Save harden log
#if [ -d "/tmp/harden-log" ]; then
#	rm -rf /tmp/harden-log
#fi
#/bin/mv "${executedir}" /tmp/initial-setup
#/bin/cd /tmp
#if [ -f initial-setup-log.zip ]; then
#	rm -rf initial-setup-log.zip
#fi
#/bin/zip -r initial-setup-log.zip initial-setup/*
