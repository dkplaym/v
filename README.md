#

edit setup:    

password=0**0*k   
openssl des-cbc -d -in setup.sh.en  -out setup.sh  -pass pass:$password  

password=0**0*k  
openssl des-cbc  -in setup.sh  -out setup.sh.en -pass pass:$password ;   
openssl des-cbc -d -in setup.sh.en  -out setup.sh.1  -pass pass:$password ;   
md5sum setup.sh setup.sh.1 ;   


442c5f53aeb3bb1cda15e70c2fdc8cb4  ss-local    
bbed4f2126bc570604c7a547bbf2c6cb  ss-manager   
5fb07656482693535b4e932bb1297b60  ss-redir   
e6988bac38b5e147ae42beb8ced7b442  ss-server   
36ef48b0d7a583c866c511cfc465e705  ss-tunnel    

make shadowsocks     

apt-get -y install libpcre++-dev libpcre++0v5 libpcre16-3  libpcre3 libpcre3-dev recommends build-essential autoconf libtool libssl-dev gawk debhelper dh-systemd init-system-helpers pkg-config asciidoc xmlto apg libpcre3-dev libev-dev libev4     
./autogen.sh ; ./configure  --disable-documentation  ;   
sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./src/Makefile;    
sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./Makefile ;      
sed -i "s/ -lev / -lev -lm  /g" ./Makefile ;     
sed -i "s/ -lev / -lev -lm  /g" ./src/Makefile ;      
make   
ls -l src/ss-*;   
strip src/ss-*;   
ls -l src/ss-*;   
ldd src/ss-*;   


server:   
/tools/ktserver -l :19393 -t 127.0.0.1:9393 --crypt none --mtu 1200 --nocomp --mode fast2 --dscp 46 &    

route:   
./ktclient -l 127.0.0.1:19393  -r ${server}:19393  --crypt none --mtu 1200 --nocomp --mode fast2  --dscp 46 &    

./ss-local -s 127.0.0.1 -p 19393 -l 9394 -k ${passssss} -m aes-256-cfb &    


disable ipv6   
sysctl -w net.ipv6.conf.all.disable_ipv6=1    




