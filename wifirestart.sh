#!/bin/sh

w=$(whoami | grep root)
if [ "$w" = "" ]  
then
    echo "it must runn in root"
    exit 1;
fi

ps aux | grep $0 | grep  "/bin/sh" | grep -v $$  | awk '{print("kill -9 "$2)}' | sh - 

restartwifi()
{
	#wlx0022c0a20242
	#wlx04a1516d4aaf
	interface=wlxf4ec380b031b

	killall -9 wpa_supplicant
#	killall -9 dhclient 
#	dhclient -r

	ifconfig $interface down
	ifconfig $interface up

	#iw dev $interface connect Tencent-StaffWiFi
	nohup /tools/wpa_supplicant -i $interface -c /tools/wpa.conf &
#network={
#	ssid="xxxxx"
#	psk="xxxx"
#}

	#dhclient $interface

	ifconfig $interface 192.168.31.220 netmask 255.255.255.0
	route del default
	route add default gw 192.168.31.1

	iptables  -t nat  -D POSTROUTING   1
	iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE

	sysctl -w net.ipv4.ip_forward=1

	killall -9 ss-server
	nohup /tools/ss-server -p 9393 -k dk -s 192.168.30.2 --fast-open  &

	killall -9 ss-local
	nohup /tools/ss-local -s 192.168.30.2 -p 9393 -l 9395 -b 192.168.30.2 -k dk &

	route add -net 10.0.0.0 netmask 255.0.0.0 gw 192.168.30.1
}

restartwifi

while true                           
do 
	if [ "$(ping www.baidu.com -c 3| grep  icmp_seq)" = "" ]  
	then
		restartwifi
	fi
	sleep 15
done

