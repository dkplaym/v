#

edit setup:    

password=0**0*k  
openssl des-cbc -d -in setup.sh.en  -out setup.sh  -pass pass:$password  

password=0**0*k
openssl des-cbc  -in setup.sh  -out setup.sh.en -pass pass:$password ; openssl des-cbc -d -in setup.sh.en  -out setup.sh.1  -pass pass:$password ; md5sum setup.sh setup.sh.1 ;   




./autogen.sh ; ./configure  --disable-documentation  ; 
sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./src/Makefile;  sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./Makefile ; 
sed -i "s/ -lev / -lev -lm  /g" ./Makefile ;  sed -i "s/ -lev / -lev -lm  /g" ./src/Makefile ; 
make 
ls -l src/ss-*;
strip src/ss-*;
ls -l src/ss-*;
ldd src/ss-*;


