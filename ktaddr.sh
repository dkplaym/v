#!/bin/sh

while true                           
do 
	cat /tmp/kt.log  | grep remote | awk -F " |:" '{print($8) }'   | sort -u > /tmp/new.txt
	sort /tmp/new.txt /tmp/old.txt /tmp/old.txt | uniq -u > /tmp/diff.txt
	cp /tmp/new.txt /tmp/old.txt
	
	while read line;do
		cat /tmp/kt.log | grep $line | tail -n 1 >> /tmp/rep.txt
	done < /tmp/diff.txt

        if [ -f "/tmp/rep.txt" ]; then
		/tools/setup.sh mail kt /tmp/rep.txt
		rm -rf /tmp/rep.txt
        fi
	sleep 3
done

