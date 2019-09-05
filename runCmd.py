#!/usr/bin/env python

from http.server import HTTPServer, CGIHTTPRequestHandler  , SimpleHTTPRequestHandler
import subprocess
from string import Template
import collections
import os
import time
import threading
from http.server import HTTPServer
import socketserver 
import sys
import datetime
import fcntl
import os
import pyinotify
import _thread 

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
cmdDict = collections.OrderedDict()
#DEFINE_BEGIN 

cmdDict['restartNET'] =  'killall -9 dnsmasq pdnsd ss-tunnel ss-local ss-redir ktclient ; sleep 5  ; ps aux  | grep tools/net | grep -v check ; ' ;
cmdDict['restartppp'] =  'killall -9 pppd ; ps aux| grep pppd | grep dsl ; ifconfig ppp' ;
cmdDict['ifconfig_ppp']=   'ifconfig ppp ' ;
cmdDict['show_iptables']=   'iptables -L -n -v ' ;
cmdDict['stop_182']=   'iptables -I FORWARD  -d 192.168.0.182 -j DROP ; iptables -L -n -v' ;
cmdDict['start_182']=   'iptables -D FORWARD  -d 192.168.0.182 -j DROP ; iptables -L -n -v' ;
cmdDict['21stop' ]= 'echo "stop" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor ; echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor | grep -v qemu ; ' ; 
cmdDict['21cont' ]= 'echo "cont" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor ; echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor | grep -v qemu ; ' ; 
cmdDict['21status' ]= 'echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor | grep -v qemu ; ' ; 
cmdDict['XPstop' ]= 'echo "stop" | /tools/bin/socat - UNIX-CONNECT:/opt/kvmwinxp/monitor ; echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvmwinxp/monitor | grep -v qemu ; ' ; 
cmdDict['XPcont' ]= 'echo "cont" | /tools/bin/socat - UNIX-CONNECT:/opt/kvmwinxp/monitor ; echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvmwinxp/monitor | grep -v qemu ; ' ; 
cmdDict['XPstatus' ]= 'echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvmwinxp/monitor | grep -v qemu; ' ; 

#DEFINE_END 
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

def readDefine( filePath ,  cmddict  ):
    cmddict.clear()
    f = open(filePath,'r')  #os.path.realpath(__file__)
    lines = f.read()
    f.close()
    s = ((lines.split("DEFINE_BEGIN")[1]).split("DEFINE_END"))[0]
    lines = s.split("\n")
    for line in lines:
        if not line.startswith("cmdDict"): continue
        s = line.split('\'')
        cmddict[s[1]] =s[3]
        print("readDefine : {} -> {}".format(s[1] ,  s[3])  )

SELF_PATH=os.path.realpath(__file__)
class MyEventHandler(pyinotify.ProcessEvent):
    def process_IN_MODIFY(self, event):
        if(  __file__ != event.name  ): return

        time.sleep(5)
        global cmdDict , SELF_PATH
        cmd = collections.OrderedDict()
        readDefine( SELF_PATH ,  cmd  ) 
        cmdDict = cmd
        print("After Read Define : cmdDcit: {}".format(len(cmdDict)))
        
 

def watchThread(path):
    try:
        while True:
            if not os.path.isdir(path):
                print("error path: " + path)
                return

            wm = pyinotify.WatchManager()
            eh = MyEventHandler()
            notifier = pyinotify.Notifier(wm, eh)
            wm.add_watch(path, pyinotify.IN_MODIFY, rec=True)
            notifier.loop()
    except Exception as e:
        print(str(e))
        return


def startWatch():
    global cmdDict , SELF_PATH
    readDefine( SELF_PATH ,  cmdDict  ) #init it first
    try:
        _thread.start_new_thread( watchThread,  (os.path.dirname(SELF_PATH), ) )
    except:
        print ("Error: unable to start watch path thread")
        exit(1)


tempButton = '''          
<button onclick='myFunction("###key")'>###word</button>        
'''

tempHtml = '''
<!doctype html><html><title>ur</title> <head><meta charset="utf-8"></head><body>

###bu

<code>
<p id="output"></p>
</code>
<script>
function httpGet(theUrl)
{
    var xmlHttp = new XMLHttpRequest();
    xmlHttp.open( "GET", theUrl, false ); // false for synchronous request
    xmlHttp.send( null );
    return xmlHttp.responseText;
}

function myFunction(cmd) {
  document.getElementById("output").innerHTML = httpGet(cmd) + 
  "<br/>__________________________________________________________________________________________<br/>"  + 
  document.getElementById("output").innerHTML
  ;
}
</script>

</body></html>
'''

def runCmd(cmd):
    try:
        return subprocess.check_output(cmd, stderr = subprocess.STDOUT, shell = True)
    except subprocess.CalledProcessError as exc:
        return exc

#print(runCmd('echo "info status" | /tools/bin/socat - UNIX-CONNECT:/opt/kvm21/monitor ;'))
#exit(1)

class SharpSignTemplate(Template):  delimiter = '###'
def procHtml(path):
    global cmdDict 

    if path is None or path == '/':
        bu = ''
        for c in cmdDict.keys():
            bu += SharpSignTemplate(tempButton).substitute({"key": c , "word": c})

        return SharpSignTemplate(tempHtml).substitute({"bu": bu})

    value = cmdDict.get(path.split('/')[1]) 
    if  value is not None :
        ret = runCmd(value)
        return str(ret).replace('\\n', '<br/>')

    return ''

class handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        print ('Handler Get, currPid:{}  currTid:{}'.format(os.getpid() , threading.current_thread().ident  )) 
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(bytes(procHtml(self.path),  encoding = "utf-8"))
        sys.stdout.flush()  
        sys.stderr.flush()

class ThreadedHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    pass

class ForkingServer(socketserver.ForkingMixIn,HTTPServer):
    pass

def daemonInit(runPath,  logPath):
    print ('beforeDaemon, currPid:{}  currTid:{}'.format(os.getpid() , threading.current_thread().ident  )) 
    sys.stdin = open('/dev/null','r')
    sys.stdout = open(logPath,'a+')
    sys.stderr = open(logPath,'a+')
    try:
        pid = os.fork()
        if pid > 0:        #parrent
            os._exit(0)
    except OSError as e:
        sys.stderr.write("first fork failed!!"+e.strerror)
        os._exit(1)
    os.setsid()
    os.chdir(runPath)
    os.umask(0)
    try:
        pid = os.fork()     
        if pid > 0:
            os._exit(0)     
    except OSError as e:
        sys.stderr.write("second fork failed!!"+e.strerror)
        os._exit(1)
    print ('Starting server, time:{}  currPid:{}  currTid:{}'.format(datetime.datetime.fromtimestamp(time.time()).strftime('%Y-%m-%d %H:%M:%S')  ,os.getpid() , threading.current_thread().ident  )) 
    sys.stdout.flush()  

if os.geteuid() != 0:
    print("\n   This program must be run as root. Aborting.\n" )
    exit(1)


if ( len(sys.argv) < 2 )   and  len(sys.argv)  != 4  :
    print("python " + sys.argv[0] + " {bindIP} {runPath} {logPath} " )
    print("Example: [ sudo python3  runCmd.py 192.168.0.1 /dev/shm   /dev/shm/runCmd.log    ]  ")
    exit(1)
    
if len(sys.argv) == 4 :
    daemonInit(sys.argv[2] , sys.argv[3])

startWatch()

#HTTPServer(('192.168.0.1', 8000), handler).serve_forever()
#server = ThreadedHTTPServer(('0.0.0.0', 8000), handler)
server = ForkingServer((sys.argv[1], 8000), handler)
server.serve_forever()

