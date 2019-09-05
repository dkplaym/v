#!/usr/bin/env python

from http.server import HTTPServer, CGIHTTPRequestHandler  , SimpleHTTPRequestHandler
import subprocess
from string import Template
import collections
import time
import threading
import socketserver 
from socket import *
import sys
import datetime
import fcntl
import os
import pyinotify
import _thread 

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
cmdDict = collections.OrderedDict()
#DEFINE_BEGIN 

cmdDict['runCmd.py'] =  '''5;-;86400;-;python3 /home/dk/8000/runCmd.py 0.0.0.0;-;ps aux | grep python | grep runCmd.py| grep -v sudo | grep -v grep  ''' ;
#cmdDict['minidlnad'] =  '5;-;86400;-;cd /home/dk/minidlna-master ;   ./start.sh  '  ;
cmdDict['redis-server'] =  '''5;-;86400;-;/usr/bin/redis-server 127.0.0.1:6379;-;ps aux | grep -v sudo | grep -v grep | grep redis_server   '''  ;  
#/usr/bin/redis-server 127.0.0.1:6379
cmdDict['dnsmasq'] = '''5;-;86400;-;/home/dk/v-master/dnsmasq -C /home/dk/v-master/dnsmasq.conf;-;ps aux|grep -v grep|grep -v sudo|grep dnsmasq|grep dnsmasq.conf '''  ;  
#/home/dk/v-master/dnsmasq -C /home/dk/v-master/dnsmasq.conf

#DEFINE_END 
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#| awk -F ' ' '{system("sudo kill -9 " $2)}'

def readDefine( filePath ,  cmddict  ):
    cmddict.clear()
    f = open(filePath,'r')  
    lines = f.read()
    f.close()
    s = ((lines.split("DEFINE_BEGIN")[1]).split("DEFINE_END"))[0]
    lines = s.split("\n")
    for line in lines:
        if not line.startswith("cmdDict"): continue
        cmdName  = line.split('\'')[1]
        content = line.split('\'\'\'')[1]
        arr =  content.split(';-;')
        cmddict[cmdName] =[ int(arr[0]) , int(arr[1])  , arr[2] , arr[3]   ]
        print("readDefine:  {} ->  {}".format(cmdName , cmddict[cmdName]))

fileNotified = False
class MyEventHandler(pyinotify.ProcessEvent):
    def process_IN_MODIFY(self, event):
        if(  __file__ != event.name  ): return
        global fileNotified
        print(fileNotified)
        fileNotified = True
 
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

def runCmd(cmd):
    try:
        return str( subprocess.check_output(cmd, stderr = subprocess.STDOUT, shell = True ))
    except subprocess.CalledProcessError as exc:
        print(exc)
        return  ""

def killProc(name, psCmd):
    psstr = runCmd(psCmd)
    if psstr.find(name) == -1 :
        print("killProc:  proc [{}]  not exist []".format(name, psstr) )
        return

    killByPid = 'kill -9 '  + psstr.split()[1]
    os.system(  killByPid )
    print("killProc:AFTER_KILL name:[{}] {} \n\n ps:   {} \n".format(name,  killByPid ,  runCmd(psCmd)) )

def checkStartProc(name, psCmd, runStr):
    psstr = runCmd(psCmd)
    if psstr.find(name) != -1 :
        print("checkStartProc:  proc [{}]  already exist []".format(name, psstr) )
        return

    startCmd = 'nohup ' + runStr + ' >/dev/null 2>&1  & ' 
    os.system( startCmd )
    print("checkStartProcc:AFTER_START name:[{}] {} \n\n ps:  {} \n".format(name, startCmd, runCmd(psCmd)) )

def checkLoop():
    lastCheck =  dict()
    lastReboot = dict()
    cmd = collections.OrderedDict()
    SELF_PATH=os.path.realpath(__file__)
    readDefine( SELF_PATH ,  cmd  ) #init it first
    try:
        _thread.start_new_thread( watchThread,  (os.path.dirname(SELF_PATH), ) )
    except:
        print ("Error: unable to start watch path thread")
        exit(1)

    global fileNotified
    while 1 :
        if fileNotified:
            print("file notified , readDefine: OLD size:{}".format(len(cmd)))
            readDefine( SELF_PATH ,  cmd  )
            fileNotified = False
            print("file notified , AFTER  readDefine: NEW  size:{}".format(len(cmd)))

        sys.stdout.flush()  
        time.sleep(1)
        now = int(time.time())
        for c in cmd.keys():
            arr = cmd.get(c)
            lc =  int( now  -   int(lastCheck.get(c, 0) )   )
            lr = int( now -   int( lastReboot.get(c ,0 ) ) )
            print("Loop: Name:{} check:{} / {} reboot:{} / {} [{}] [{}]".format(c, lc , arr[0] , lr,  arr[1] , arr[2]  , arr[3]))

            if (  lr  ==  now ):  
                lastReboot[c] = now
            elif ( lr  >=  arr[1] )  : 
                lastReboot[c]= now
                killProc(c, arr[3] )
                checkStartProc(c, arr[3] , arr[2] )
   
            if ( lc  >= arr[0] ):
                lastCheck[c] = now 
                checkStartProc(c, arr[3] , arr[2] )

   
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

def checkSingleton(filename):
    print("singleton start")
    pidfile = open(filename , "a+")
    print("pidfile: " + str(pidfile))
    try:
        print("startlock :" + str(os.getpid()))
        fcntl.flock(pidfile.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB )
        print("finlock :" + str(os.getpid()))
    except IOError as e:
        raise SystemExit("check singleton already running:  " + str(e) )
    
    pidfile.seek(0)
    pidfile.truncate()
    pidfile.write(str(os.getpid()))
    pidfile.flush()
    pidfile.seek(0)
    return pidfile

if os.geteuid() != 0:
    print("\n   This program must be run as root. Aborting.\n" )
    exit(1)

if ( len(sys.argv)  > 1 )   and   (  len(sys.argv)  < 3  or len(sys.argv) > 4)  :
    print("python " + sys.argv[0] + " {runPath} {logPath}  [{pidPath}] " )
    print(
    '''Example: [ 
        \nsudo ps aux | grep checkProc.py | grep python | awk -F ' ' '{system("sudo kill -9 " $2)}';sudo python3  checkProc.py  /dev/shm   /dev/shm/checkProc.log /dev/shm/checkProc.pid     
        \n]  ''')
    exit(1)
    
if len(sys.argv) == 3 :
    daemonInit(sys.argv[1] , sys.argv[2])



pidfile = checkSingleton( 'checkProc.pid' if len(sys.argv)  < 4  else  sys.argv[3]  ) # must be define and keep var pidfile for holding file lock




checkLoop()
 
