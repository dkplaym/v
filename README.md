#


openssl des-cbc -d -in setup.sh.en  -out setup.sh  -pass pass:0**0*k



./autogen.sh ; ./configure  --disable-documentation  ; 
sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./src/Makefile;  sed -i "s/LDFLAGS = /LDFLAGS = -all-static /g" ./Makefile ; 
sed -i "s/ -lev / -lev -lm  /g" ./Makefile ;  sed -i "s/ -lev / -lev -lm  /g" ./src/Makefile ; 
make 
ls -l src/ss-*;
strip src/ss-*;
ls -l src/ss-*;
ldd src/ss-*;


