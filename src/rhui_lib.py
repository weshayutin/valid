try:
    import paramiko
except ImportError:
    print "Sorry, you don't have the paramiko module installed, and this"
    print "script relies on it.  Please install or reconfigure paramiko"
    print "and try again."
    
import re
import os 
import sys
import time


#def putfile(hostname, pkey_file, localpath, filepath):
#    username = 'root'
#    key = paramiko.RSAKey.from_private_key_file(pkey_file)
#    tr = paramiko.Transport((hostname, 22))
#    tr.connect(username=username, pkey=key)
#    sftp = paramiko.SFTPClient.from_transport(tr)
#    print "\n\nPlease wait, Trying to upload the file ", localpath, " to   hostname : ", hostname
#    sftp.put(localpath,filepath)
#    print "Uploading the file : ", localpath, "  to  ", hostname, " completed"
#    sftp.close()
#    tr.close()

def putfile(hostname, pkey_file, localpath, filepath):
    username = 'root'
    num = 7
    while num > 1:
	try:
    	    key = paramiko.RSAKey.from_private_key_file(pkey_file)
    	    tr = paramiko.Transport((hostname, 22))
    	    tr.connect(username=username, pkey=key)
    	    sftp = paramiko.SFTPClient.from_transport(tr)
	    break
	except:
	    print "\n\nError, re-trying in 30 secs"
	    print "The Hostname is :", hostname
	    print "The key is :", pkey_file
	    print "The Local and REmote path is :", localpath, " ", filepath
	    num = num - 1
	    print "Number of attempts left", num
	    time.sleep(30)
	    continue
    if num == 1:
	return 1 
    print "\n\nPlease wait, Trying to upload the file ", localpath, " to   hostname : ", hostname
    sftp.put(localpath,filepath)
    print "Uploading the file : ", localpath, "  to  ", hostname, " completed"
    sftp.close()
    tr.close()

    
#def getfile(hostname, pkey_file, localpath, filepath):
#    username = 'root'
#    key = paramiko.RSAKey.from_private_key_file(pkey_file)
#    tr = paramiko.Transport((hostname, 22))
#    tr.connect(username=username, pkey=key)
#    sftp = paramiko.SFTPClient.from_transport(tr)
#    print "\n\nPlease wait, Trying to download the file ", filepath, " from hostname : ", hostname
#    sftp.get(filepath,localpath)
#    print "Downloading the file : ", filepath, "  from  ", hostname, " completed"
#    sftp.close()
#    tr.close()
    
    
def getfile(hostname, pkey_file, localpath, filepath):
    username = 'root'
    num = 7
    while num > 1:
        try:
            key = paramiko.RSAKey.from_private_key_file(pkey_file)
            tr = paramiko.Transport((hostname, 22))
            tr.connect(username=username, pkey=key)
            sftp = paramiko.SFTPClient.from_transport(tr)
            break
        except:
            print "\nError, re-trying in 30 secs"
	    print "\nThe Hostname is :", hostname
	    print "\nThe key is :", pkey_file
	    print "\nThe Local and Remote path is :", localpath, " ", filepath
            num = num - 1
            print "Number of attempts left", num
            time.sleep(30)
            continue
    if num == 1:
        return 1    
    print "\n\nPlease wait, Trying to download the file ", filepath, " from hostname : ", hostname
    sftp.get(filepath,localpath)
    print "Downloading the file : ", filepath, "  from  ", hostname, " completed"
    sftp.close()
    tr.close()
    
def remote_exe(hostname, pkey_file, cmd):
    user = 'root'
    key = paramiko.RSAKey.from_private_key_file(pkey_file)
    s = paramiko.SSHClient()
    s.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    s.connect(hostname, username=user, pkey=key)
    stdin, stdout, stderr = s.exec_command(cmd)
    print stdout.read()
    s.close()    

def answers_replace(stext, dtext, input_file):
    print "\nReplacing", stext, " with ", dtext, "in file : ", input_file
    data = open(input_file).read()
    o = open(input_file,"w")
    o.write( re.sub(stext, dtext ,data) )
    o.close()      
    
def chek_files(fil_list, lis_sz):
    print "\n\nChecking for the pre-requisites : \n"
    home_dir = os.path.expanduser("~") 
    file_not = []
    for kde in range(lis_sz):
        file = home_dir + "/" + fil_list[kde]
        stat = os.path.exists(file)
        if stat == False:
            file_not.append(file)
        elif stat == True:
            print file + " : Present"
        
    if file_not:        
        print "\n\nFollowing files are not present in your home-directory : \n"
        for disp in file_not:
            print disp 
        print "\nPlease include the above files."
        sys.exit()
