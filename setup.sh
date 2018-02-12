#!/bin/bash

THISFILE="setup.sh"
MAILDIR='/tools/mail/'
MARK="written_by_dk"

bakpath(){
        head="/tmp/bakpathforsetup_"
        ppid=$PPID
        lsres=$( ls -l $head$ppid 2>&1 | grep "No such file" )
        if [ "$lsres" != "" ] ; then
                rm -f $head*
                bakdir="/tools/bak_`date -d today +%m%d_%H%M%S`/"
                echo -e "$bakdir\c" > $head$ppid
                mkdir -p $bakdir
                echo $bakdir
        else    
                cat $head$ppid
        fi      
}

writeConfig(){
	if [[ "$( ls -l $1  2>&1 | grep "No such file" )" == "" ]]  ; then cp  $1 `bakpath` ;   fi 
	echo -e "$2"  > $1
#	echo -e "\n\n;## by dk -- `date  +%y_%m_%d_%H_%M_%S` "  >> $1  
	
#fuck the xl2tpd.conf ! only support ";" for comment 
#	if [[ $1 == "/etc/xl2tpd/xl2tpd.conf" ]] ; then echo -e "\n\n;## by dk -- `date  +%y_%m_%d_%H_%M_%S` "  >> $1 ;
#	else echo -e "\n\n## by dk -- `date  +%y_%m_%d_%H_%M_%S` "  >> $1
#	fi
}

getgitfile(){
	lsres=$( ls -l $1 2>&1 | grep "No such file" )
	if [ "$lsres" != "" ] ; then
		wget $2 -O $1
		chmod +x $1
	fi
}

ENC_PSK=""
ENC_FROM_MAIL=""
ENC_TO_MAIL=""
ENC_FROM_USER=""
ENC_CHAP=""
ENC_SSKEY=""

getencfile(){
	DEC="/tools/decinfo.txt"
        lsres=$( ls -l $DEC  2>&1 | grep "No such file" )
        if [ "$lsres" != "" ] ; then	
		getgitfile /tools/encinfo.bin https://raw.github.com/dkplaym/v/master/encinfo.bin
		echo -e "\n\n"
		read -p "~~~~Give Me the pass??? :"
		openssl des-cbc -d -in /tools/encinfo.bin -out $DEC -pass pass:$REPLY
	fi
	
	ENC_PSK=`sed -n '1p' $DEC`
	ENC_FROM_MAIL=`sed -n '2p' $DEC`
	ENC_TO_MAIL=`sed -n '3p' $DEC`
	ENC_FROM_USER=`sed -n '4p' $DEC`
	ENC_CHAP=`sed -n '5p' $DEC`
	ENC_SSKEY=`sed -n '6p' $DEC`
}

encfile(){
	DEC="/tools/decinfo.txt"
	echo -e "\n\n"
        read -p "~~~~Give Me the pass??? :"
	openssl des-cbc -in $DEC -out /tools/encinfo.bin  -pass pass:$REPLY ;	
}

append_sendmail(){

	mkdir -p $MAILDIR
	chmod 777 $MAILDIR

	lsres=$(ls -l $1  2>&1 | grep "No such file")
	if [ "$lsres" != "" ] ;then 
		echo "check file $1 __________  $lsres"
		return
	fi		
	result=$(cat $1 | grep $THISFILE )
	if [ "$result" != "" ] ; then
		echo -e "ignore $1  ____________ $result \n\n"
	else	
		cp $1 `bakpath`
		echo -e "\n\n" >> $1
		echo  $2 >> $1
	fi
}

#####################################################################################################################################################################
#####################################################################################################################################################################


setup_pptp(){
	if [[ "$(apt list --installed 2>&1  | grep pptpd)" == "" ]] ;	then apt-get -y install pptpd  ;fi

	writeConfig "/etc/ppp/chap-secrets" "$ENC_CHAP" 

	writeConfig "/etc/ppp/pptpd-options" '
ms-dns 8.8.8.8
ms-dns 8.8.4.4
debug
logfile /tmp/pptpd.log'
	
	writeConfig "/etc/pptpd.conf"  '
option /etc/ppp/pptpd-options
debug
localip 192.168.10.1
remoteip 192.168.10.234-238,192.168.10.245  '

	modprobe nf_conntrack_pptp
	modprobe ip_nat_pptp
	service pptpd restart
}



setup_named(){
	if [[ "$(apt list --installed 2>&1  | grep bind9)" == "" ]] ;	then apt-get -y install bind9  ;fi

	writeConfig "/etc/bind/named.conf.options" '
options {
     directory "/var/cache/bind";
     forwarders {
	  8.8.8.8;
	  8.8.4.4;
     };
     dnssec-validation auto;
     allow-query     {  any; };
     recursion yes;
     auth-nxdomain no;    # conform to RFC1035
     listen-on port 53 {127.0.0.1;};
};	
' 
	service bind9 restart
}





setup_xl2tp(){
	if [[ "$(apt list --installed 2>&1  | grep strongswan)" == "" ]] ;	then apt-get -y install strongswan  ;fi
	if [[ "$(apt list --installed 2>&1  | grep xl2tpd)" == "" ]] ;	then apt-get -y install xl2tpd  ;fi

    writeConfig "/etc/ppp/chap-secrets" "$ENC_CHAP"

	writeConfig "/etc/ipsec.secrets"  ": PSK \"$ENC_PSK\" "

	writeConfig "/etc/ipsec.conf" '
config setup
   uniqueids=never             

conn %default
    keyexchange=ike           
    left=%any                 
    leftsubnet=0.0.0.0/0           
    right=%any             

conn L2TP-PSK
    keyexchange=ikev1
    authby=secret
    leftprotoport=17/1701
    leftfirewall=no
    rightprotoport=17/%any
    type=transport
    auto=add 
'

 	writeConfig  "/etc/xl2tpd/xl2tpd.conf" '
[global]
port = 1701
access control = no
[lns default]
ip range = 192.168.10.200-192.168.10.220
local ip = 192.168.10.1
name = xl2tpd
pppoptfile = /etc/ppp/options.xl2tpd
ppp debug = yes
require chap = yes
refuse pap = yes
require authentication = yes 
' 
        

	writeConfig "/etc/ppp/options.xl2tpd" '
noccp
auth
crtscts
mtu 1410
mru 1410
#nodefaultroute
lock
proxyarp
silent
ms-dns 8.8.8.8
ms-dns 8.8.4.4 
'

	append_sendmail /etc/ppp/ip-up   "/tools/$THISFILE mail on \$PEERNAME"
	append_sendmail /etc/ppp/ip-down "/tools/$THISFILE mail off \$PEERNAME"
}

runservice()
{       
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.disable_ipv6=1

    if [[ "$(iptables -L -t  nat -v -n  | grep MASQUE)" == "" ]] ; then    
	    iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o $(head -n 1 /tools/interface)  -j MASQUERADE
    fi

    killall -9 checkproc.sh ss-server ktserver
    nohup /tools/checkproc.sh 5 ss-server /tools/ss-server -s 127.0.0.1 -p 9393 -k $ENC_SSKEY -m aes-256-cfb  >/dev/null 2>&1   &
    nohup /tools/checkproc.sh 5 ktserver /tools/ktserver -l :19393 -t 127.0.0.1:9393 --crypt none --mtu 1200 --nocomp --mode fast2 --dscp 46 > /dev/null 2>&1 &

    service strongswan restart
    service xl2tpd restart
}

setup_vps(){
	cp /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime    # ntpdate time.windows.com	
	echo $2 > /tools/interface

	if [ "$(cat /etc/hostname | grep "^$1")" == "" ] ; then echo "$1" > /etc/hostname  ; fi

	if [ "$(cat /etc/hosts | grep "$1")" == "" ] ; then echo -e "\n127.0.0.1 $1 \n" >> /etc/hosts ; fi

	apt-get update;
	if [ "$(apt list --installed 2>&1  | grep curl)" == "" ] ; then apt-get -y install curl ; fi 
	if [ "$(apt list --installed 2>&1  | grep curl)" == "" ] ; then apt-get -y install wget ; fi 
	if [ "$(apt list --installed 2>&1  | grep curl)" == "" ] ; then apt-get -y install unzip ; fi 
	if [ "$(apt list --installed 2>&1  | grep curl)" == "" ] ; then apt-get -y install lrzsz ; fi 

	getencfile
	append_sendmail $HOME/.bashrc "/tools/$THISFILE mail last"
	
	setup_xl2tp

	if [ "$(cat /etc/rc.local | grep $THISFILE)" == "" ] ; then 
		cp /etc/rc.local `bakpath`
		sed "s/^exit 0//" /tools/rc.local.bak  > /etc/rc.local
		echo -e "/tools/$THISFILE rc.local \nexit 0;\n" >> /etc/rc.local
		chmod +x /etc/rc.local
	fi

	getgitfile /tools/ss-server https://github.com/dkplaym/v/raw/master/ss-server
    getgitfile /tools/ktserver https://github.com/dkplaym/v/raw/master/ktserver
	getgitfile /tools/ktserver https://github.com/dkplaym/v/raw/master/checkproc.sh


	runservice;
}


curlmail(){
	curl -s --url "smtps://smtp.gmail.com:465" --ssl-reqd --mail-from "$ENC_FROM_MAIL" --mail-rcpt "$ENC_TO_MAIL" --upload-file $1 --user "$ENC_FROM_USER" --insecure 
}
sendmail(){
	t=`date  +%m%d_%H%M%S`
        MAIL="$MAILDIR/$1_$t"
        rm $MAIL > /dev/null 2>&1

        echo -e "From:$ENC_FROM_MAIL\nTo:$ENC_TO_MAIL"  >> $MAIL

        if [ $1 == "last" ] ; then
                cnt=`last | wc -l`
                echo -e "Subject: last_$t_vps_$cnt \n\n" >> $MAIL
                last >> $MAIL
                curlmail $MAIL;
        fi
        if [ $1 == "on" ] ; then
                echo -e "Subject: $2 ON \n\n  time:$t" >> $MAIL
                cat  /var/log/syslog |egrep "established between|CHAP Response" | tail -n 2 >> $MAIL
                curlmail $MAIL;
        fi
        if [ $1 == "off" ] ; then
                echo -e "Subject: $2 OFF \n\n  time:$t" >> $MAIL
                cat  /var/log/syslog | egrep  "closed to |Connect time |bytes, received " | tail -n 3  >> $MAIL
                curlmail $MAIL;
        fi
        if [ $1 == "kt" ] ; then
                echo -e "Subject: KT_NEW \n\n  time:$t" >> $MAIL
		cat $2 >> $MAIL
                curlmail $MAIL;
        fi
#        rm -rf $MAIL
}

show_usage(){
echo -e "
vps [hostname] [interface]		//init vps  give hostname   
sshport	[port]				//change sshd port 
pptpd					//setup pptpd for vps
named 				//setup named for vps  
run					//restart all service 

encfile					//enc info file to git

client [vps ip] 			//chanage vps ip in route 

rc.local				//for rc.local to start service  
mail [last|on|off] [user]		//send mail (last on off) (user)
"
}

if [ $# -lt  1 ] ; then
show_usage
exit 1;
fi
getencfile
if [ $1 = 'rc.local' ] ; then
	runservice;
	exit 1;
fi

if [ $1 == "mail" ] ; then
	sendmail $2 $3
	exit 1;
fi

if [ "$(whoami | grep root)" = "" ] ; then
    echo "it must runn in root"
    exit 1;
fi

if [ "$(pwd | grep /tools)" = "" ] ; then
        echo "it must runn at dir /tools"
        exit 1;
fi

if [ $1 = 'client' ] ; then
	if [ "$2" = "" ]; then
		echo "give me the vps ip" 
		exit 1;
        fi
	setup_client $2
	exit 1;
fi

if [ $1 = 'vps' ] ; then
	if [ "$2" = "" ]; then
		echo "give me this hostname" 
		exit 1;
        fi
	if [ "$3" = "" ]; then
                echo "give me this interface" 
                exit 1;
        fi

	setup_vps $2 $3
	exit 1;
fi

if [ $1 = 'encfile' ] ; then
        getencfile;
        exit 1;
fi

if [ $1 = 'run' ] ; then
        runservice;
        exit 1;
fi

if [ $1 = 'pptpd' ] ; then
	setup_pptp;
	exit 1;
fi

if [ $1 = 'named' ] ; then
	setup_named;
	exit 1;
fi


if [ $1 = 'sshport' ] ; then
	if [ "$2" = "" ]; then 
		echo "give me the port" 
		exit 1;
	fi
	mv /etc/ssh/sshd_config `bakpath`
	sed "s/^Port 22/Port $2/" `bakpath`/sshd_config  > /etc/ssh/sshd_config
	service sshd restart #/usr/sbin/sshd -f /root/sshd/sshd_config
	exit 1;
fi

show_usage
exit 1;





