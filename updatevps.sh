#!/bin/bash

if [ $# -lt  1 ] ; then
	echo -e "proc [new_vps_ip]\n\n"
	exit 1;
fi

if [ "$(whoami | grep root)" = "" ] ; then
    echo -e "it must runn in root\n\n"
    exit 1;
fi

now=`date -d today +%y%m%d_%H%M%S`
cat /etc/hosts | sed "s/dkvps/vps_$now/"  > /tmp/hosts

echo -e "\n$1 dkvps" >> /tmp/hosts
mv /tmp/hosts /etc/

killall -9 ktclient

nohup /tools/ktclient -l 127.0.0.1:19393 -r dkvps:19393 --crypt none --mtu 1200 --nocomp --mode fast2 --dscp 46 >/dev/null 2>&1 &

