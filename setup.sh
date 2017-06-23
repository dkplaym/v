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

write_dnsmasq(){
        F="/etc/dnsmasq.conf"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F `bakpath`
    	echo '
no-resolv
interface=brlan
bind-interfaces
dhcp-range=192.168.0.150,192.168.0.200,8760h

all-servers
server=127.0.0.1#9396
server=127.0.0.1#9397
cache-size=1500
max-cache-ttl=3600
conf-file=/tools/domain.txt
        ' > $F
	echo -e "\n\n#$MARK" >> $F
}

setup_client(){
	getencfile 

	old=`cat CurrVpsAddr.txt`       
	echo $old
	echo $old >> OldVpsAddr.txt
	echo $1 > CurrVpsAddr.txt
	cp  /etc/rc.local  /tmp/rc.local
	sed "s/$old/$1/" /tmp/rc.local > /etc/rc.local
	
	getgitfile /tools/ss-redir https://github.com/dkplaym/v/raw/master/ss-redir
	killall -9 ss-redir 
	nohup /tools/ss-redir -s $1 -b 0.0.0.0 -p 9393 -l 9394 -k $ENC_SSKEY -m aes-256-cfb >/dev/null 2>&1 &
	getgitfile /tools/ss-local https://github.com/dkplaym/v/raw/master/ss-local
	killall -9 ss-local
	nohup /tools/ss-local -s $1 -b 0.0.0.0 -p 9393 -l 9395 -k $ENC_SSKEY -m aes-256-cfb >/dev/null 2>&1 &
	getgitfile /tools/ss-tunnel https://github.com/dkplaym/v/raw/master/ss-tunnel
	killall -9 ss-tunnel	
	nohup /tools/ss-tunnel -u -s $1 -b 0.0.0.0  -p 9393 -l 9396 -L 8.8.8.8:53 -k $ENC_SSKEY -m aes-256-cfb  2>&1 &
	nohup /tools/ss-tunnel -u -s $1 -b 0.0.0.0  -p 9393 -l 9397 -L 208.67.222.222:53 -k $ENC_SSKEY -m aes-256-cfb  2>&1 &
	rm /tools/domain.txt
	cat /tools/domain_raw.txt | tr -d '\r' | grep -v '^$' | sort  | uniq  | while read line   
	do
	    echo ipset=/$line/gfwredir >> /tools/domain.txt    #echo server=/$line/$1#53553 >> /tools/domain.txt
	done

	write_dnsmasq
	service dnsmasq restart

	ipset flush

	echo -e "\n\n\n //todo ____________________________________________"

	echo " rm -fr $HOME/.ssh/id_rsa ; /usr/bin/ssh-keygen -q  -t rsa  -f ~/.ssh/id_rsa -P ''  "
	echo " ssh-copy-id -i ~/.ssh/id_rsa.pub -p 32132  root@$1"
	echo "ls -l $HOME/.ssh/ :"
	ls -l $HOME/.ssh/
	echo -e "\n\n\n"
 
}

write_name_options(){
	F="/etc/bind/named.conf.options"
	result=$( cat $F | grep $MARK )
		if [[ "$result" != "" ]]
		then
			echo "ignore $F"
			return;
		fi
	cp  $F `bakpath`
	echo '
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
     listen-on port 53553 {127.0.0.1;};
};
	
	' > $F
echo -e "\n\n#$MARK" >> $F
}

write_ipsec_conf(){
        F="/etc/ipsec.conf"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then    
                        echo "ignore $F"
                        return;
                fi
        
        cp  $F `bakpath`
        echo '
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
        ' > $F
echo -e "\n\n#$MARK" >> $F
}

write_xl2tpd_conf(){
        F="/etc/xl2tpd/xl2tpd.conf"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then    
                        echo "ignore $F"
                        return;
                fi
        
        cp  $F `bakpath`
        echo '
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
        ' > $F
echo -e "\n\n;$MARK" >> $F
}

write_xl2tpd_options(){
        F="/etc/ppp/options.xl2tpd"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F `bakpath`
        echo '
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
        ' > $F
echo -e "\n\n#$MARK" >> $F
}
write_pptpd_options(){
        F="/etc/ppp/pptpd-options"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F `bakpath`
        echo '
ms-dns 8.8.8.8
ms-dns 8.8.4.4
debug
logfile /tmp/pptpd.log'  
	>> $F
	echo -e "\n\n#$MARK" >> $F
}

write_pptpd_conf(){
        F="/etc/pptpd.conf"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F  `bakpath`
        echo '
option /etc/ppp/pptpd-options
debug
localip 192.168.10.1
remoteip 192.168.10.234-238,192.168.10.245
	' >>  $F
	echo -e "\n\n#$MARK" >> $F
}

write_ipsec_secerts(){
        F="/etc/ipsec.secrets"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F `bakpath`
        echo ": PSK \"$ENC_PSK\" "   > $F
        echo -e "\n\n#$MARK" >> $F
}

write_chap_secrets(){
        F="/etc/ppp/chap-secrets"
        result=$( cat $F | grep $MARK )
                if [[ "$result" != "" ]]
                then
                        echo "ignore $F"
                        return;
                fi

        cp  $F `bakpath`
        echo -e "
$ENC_CHAP
	"> $F
echo -e "\n\n#$MARK" >> $F
}

runservice()
{       
        sysctl -w net.ipv4.ip_forward=1
        
	result=$(iptables -L -t  nat -v -n  | grep MASQUE)
        if [[ "$result" != "" ]]
        then    
                echo $result 
                echo "ignore run iptables"
        else    
		e=$(head -n 1 /tools/interface)        
	        iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o $e  -j MASQUERADE
        fi
	
	getgitfile /tools/ss-server https://github.com/dkplaym/v/raw/master/ss-server
	killall -9 ss-server
        nohup /tools/ss-server -u -p 9393 -k $ENC_SSKEY -m aes-256-cfb  >/dev/null 2>&1   &
        
        service strongswan restart
        service xl2tpd restart
        service bind9 restart
}

append_sendmail(){
	lsres=$(ls -l $1  2>&1 | grep "No such file")
	if [ "$lsres" != "" ] ;then 
		echo "check file $1 __________  $lsres"
		return
	fi		
	result=$(cat $1 | grep $THISFILE )
	if [ "$result" != "" ] ; then
		echo -e "ignore $1  ____________ $result \n\n"
	fi	
	cp $1 `bakpath`
	echo -e "\n\n" >> $1
	echo  $2 >> $1
}

setup_vps(){
	cp /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime    # ntpdate time.windows.com
	getencfile
	
	echo $2 >> /tools/interface

	if [ "$(cat /etc/hostname | grep "^$1")" != "" ] ; then echo "ignore hostname"
	else echo "$1" > /etc/hostname
	fi
	if [ "$(cat /etc/hosts | grep "$1")" != "" ] ; then echo "ignore hosts"
	else echo "\n127.0.0.1 $1 \n" >> /etc/hosts
	fi
	if [ "$(apt list --installed 2>&1  | grep strongswan)" != "" ] ; then echo "ignore apt-get"
	else apt-get update ; apt-get -y install curl unzip lrzsz strongswan xl2tpd bind9 
	fi
	#rm named.conf.options #sed "s/0.0.0.0/$1/" named.conf.options.4zero > named.conf.options #cp -r ./l2tp/etc/* /etc/ #cp named.conf.options /etc/bind/

	write_name_options
	write_ipsec_secerts
	write_ipsec_conf
	write_xl2tpd_conf
	write_xl2tpd_options
	write_chap_secrets

	mkdir -p $MAILDIR
	chmod 777 $MAILDIR
	append_sendmail /etc/ppp/ip-up   "/tools/$THISFILE mail on \$PEERNAME"
	append_sendmail /etc/ppp/ip-down "/tools/$THISFILE mail off \$PEERNAME"
	append_sendmail $HOME/.bashrc "/tools/$THISFILE mail last"

	if [ "$(cat /etc/rc.local | grep $THISFILE)" != "" ] ;then echo "ignore setup rc.local"
	else
		cp /etc/rc.local `bakpath`
		sed "s/^exit 0//" /tools/rc.local.bak  > /etc/rc.local
		echo -e "/tools/$THISFILE rc.local \nexit 0;\n" >> /etc/rc.local
		chmod +x /etc/rc.local
	fi
	runservice;
}

setup_pptp()
{
	result=$(apt list --installed 2>&1  | grep pptpd)
	if [[ "$result" != "" ]]
	then
		echo "ignore apt-get pptpd"
	else
		apt-get update
		apt-get -y install pptpd
	fi
	write_chap_secrets
	write_pptpd_options
	write_pptpd_conf
	service pptpd restart
}

curlmail(){
	curl -s --url "smtps://smtp.gmail.com:465" --ssl-reqd --mail-from "$ENC_FROM_MAIL" --mail-rcpt "$ENC_TO_MAIL" --upload-file $1 --user "$ENC_FROM_USER" --insecure 
}
sendmail(){
	t=`date  +%m%d_%H%M%S`
        MAIL="$MAILDIR/$1_$t"
        rm $MAIL > /dev/null 2>&1

        echo -e "From: $ENC_FROM_MAIL \nTo: $ENC_TO_MAIL \n"  >> $MAIL

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
        rm -rf $MAIL
}

show_usage(){
echo -e "
vps [hostname] [interface]		//init vps  give hostname   
sshport	[port]				//change sshd port 
pptpd					//setup pptpd for vps
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





