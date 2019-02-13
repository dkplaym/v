#!/bin/sh

if [ "$(whoami | grep root)" = "" ] ; then
    echo -e "it must runn in root\n\n"
    exit 1;
fi



checkproc(){

	result=`ps aux  | grep xl2tpd |  grep -v grep  `
	echo "______________" $result "___________"
	if [ "$result" = "" ]  
	then 
		return 1 
    fi     

	result=`ps aux  | grep starter|  grep -v grep  `
	echo "______________" $result "___________"
	if [ "$result" = "" ]  
	then 
		return 2 
    fi  

	result=`ps aux  | grep charon  | grep -v starter |  grep -v grep  `
	echo "______________" $result "___________"
	if [ "$result" = "" ]  
	then 
		return 3
    fi    

	return 0
}

restartproc(){
	echo "restart now"
	killall -9 pppd
	service strongswan restart
	service xl2tpd restart
}

count=$((86400/2/5))
#count=4
i=0
while true                           
do 
	i=`expr $i + 1`;
	if [ $i -gt $count ]
	then
		i=0
		restartproc	
	fi
        
	checkproc
	res=$?
	if [ "$res" != "0" ]                            
        then                  
			echo "start now  return :" $res
			restartproc     
        else               
			echo "continue  return :" $res
        fi     
	
	sleep 5
done

