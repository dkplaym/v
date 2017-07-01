#!/bin/sh
while true                           
do         

        a=`ifconfig | grep ppp`                                               
        result=$(echo $a | grep "Link encap:Point-to-Point Protocol")     
        echo $result
	if [ "$result" != "" ]                            
        then                                           
                echo "True"     
        else               
                echo "False"   
		killall -9 pppd
		pon dsl-provider
		sleep 2
		echo "________________" >> /tools/ppp.log
		date >> /tools/ppp.log
		ifconfig ppp0 | grep inet >> /tools/ppp.log 


        fi     
	
	sleep 15
done

