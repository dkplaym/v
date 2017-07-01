cat /tools/dnsmasq.leases | awk '{a="echo -n \"" $0"\";echo -n \" \";date -d @"$1" +\"%Y-%m-%d_%H:%M:%S\"" ;  system(a)}' | awk '{print($6" \t"$2" \t"$3" \t\t"$4)}'

