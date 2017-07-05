#!/bin/sh


if [ $# -lt  1 ] ; then
	echo -e "proc sleepTime procname cmd \n\n"
	exit 1;
fi

if [ "$(whoami | grep root)" = "" ] ; then
    echo -e "it must runn in root\n\n"
    exit 1;
fi

i=0
for var in $*
do
	i=`expr $i + 1`;
	if  [ $i -gt 2 ]
	then
		cmd=$cmd" "$var	
   	fi
done

count=`expr 86400 /2 / $1 `
#count=4
i=0
while true                           
do 
	echo $i
	i=`expr $i + 1`;
	if [ $i -gt $count ]
	then
		
		echo $i
		i=0
		killall $2
		
	fi
        
        result=`ps aux | grep $2 | grep -v checkproc | grep -v grep`
        echo "______________" $result "___________"
	if [ "$result" != "" ]                            
        then                                           
                echo "True"     
        else               
                echo "False"   
		echo $cmd
		$cmd &
        fi     
	
	sleep $1
done

