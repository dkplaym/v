#!/bin/sh


if [ $# -lt  1 ] ; then
	echo -e "proc sleepTime procname cmd \n\n"
	exit 1;
fi

if [ "$(whoami | grep root)" = "" ] ; then
    echo -e "it must runn in root\n\n"
    exit 1;
fi


while true                           
do         

        result=`ps aux | grep $2 | grep -v checkproc | grep -v grep`
        echo $result
	if [ "$result" != "" ]                            
        then                                           
                echo "True"     
        else               
                echo "False"   
		$3
        fi     
	
	sleep $1
done

