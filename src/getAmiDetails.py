from pprint import pprint
from boto import ec2
import boto, thread
import sys, time, optparse, os, paramiko
#from boto.ec2.blockdevicemapping import BlockDeviceMapping
from boto.ec2.blockdevicemapping import EBSBlockDeviceType, BlockDeviceMapping 



#def main(argv):
#    try:
#        opts, args = getopt.getopt(argv, "hr:vb:a:", ["help","region", "version","bugzilla","ami-number"])
#    except getopt.GetoptError:
#        usage()
#        sys.exit(2)

parser = optparse.OptionParser()

desc="ami test script"

parser.add_option('-r','--region', type='string', dest='REGION', help='specify ec2 region')
parser.add_option('-v','--RHEL_Version', type='string', dest='RHEL', help='RHEL version')
parser.add_option('-b', '--bugzilla_number', type='string', dest='BZ', help='optional bugzilla number')
parser.add_option('-a','--ami_number', type='string', dest='AMI', help='ami id number')
parser.add_option('-s','--ssh-key-path', type='string',dest='SSHKEY',help='full path to ssh key for the ec2 region')
parser.add_option('-k','--ssh-key-name', type='string',dest='SSHKEYNAME',help='name of the key pair')
parser.add_option('-i','--ec2-key', type='string',dest='AWS_ACCESS_KEY_ID',help='EC2 Access Key ID')
parser.add_option('-p','--ec2-secret-key', type='string',dest='AWS_SECRET_ACCESS_KEY',help='EC2 Secret Access Key ID')
parser.add_option('-y','--bugzilla_username', type='string',dest='BZUSER',help='bugzilla username')
parser.add_option('-z','--bugzilla_password', type='string',dest='BZPASS',help='bugzilla password')
parser.add_option('-m','--arch',  dest='ARCH', default='x86_64', help='arch = i386, or x86_64') #c1.medium


(opts, args) = parser.parse_args()
AMI = opts.AMI
REGION = opts.REGION
RHEL = opts.RHEL
BZ = opts.BZ
SSHKEY = opts.SSHKEY
SSHKEYNAME = opts.SSHKEYNAME
AWS_ACCESS_KEY_ID = opts.AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY = opts.AWS_SECRET_ACCESS_KEY
BZUSER = opts.BZUSER
BZPASS = opts.BZPASS
ARCH = opts.ARCH

mandatories = ['AMI','REGION','SSHKEY','RHEL','AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'ARCH']
for m in mandatories:
    if not opts.__dict__[m]:
        print "mandatory option is missing\n"
        parser.print_help()
        exit(-1)




def getConnection(key,secretKey,REGION):
    conn = ec2.connection.EC2Connection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    regions = ec2.regions()
    print regions
    
    regionNum = 99
    for i in range(len(regions)):
        thisRegion = str(regions[i])
        myRegion =  "RegionInfo:"+REGION
        if thisRegion == myRegion:
            regionNum = i
    
    region = regions[regionNum]
    print region
    conn_region = region.connect()       
    print conn_region
    return conn_region
#east# reservation = ec2conn.run_instances('ami-8c8a7de5', instance_type='t1.micro', key_name='cloude-key')
#block_device_map
#'/dev/sda=:20'

def startInstance(ec2connection, hardwareProfile):
    conn_region = ec2connection
    map = BlockDeviceMapping() 
    t = EBSBlockDeviceType()
    t.size = '15'
    #map = {'DeviceName':'/dev/sda','VolumeSize':'15'}
    map['/dev/sda1'] = t  
    
    
    #blockDeviceMap = []
    #blockDeviceMap.append( {'DeviceName':'/dev/sda', 'Ebs':{'VolumeSize' : '100'} })
    
    
    
    if ARCH == 'i386' and RHEL == '6.1':
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME, block_device_map=map )
    elif ARCH == 'x86_64' and RHEL == '6.1':
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME, block_device_map=map )
    elif ARCH == 'i386':
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME )
    elif ARCH == 'x86_64':
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME )
    else:
        print "arch type is neither i386 or x86_64.. will exit"
        exit(1)
        
    myinstance = reservation.instances[0]
    
    time.sleep(5)
    while(not myinstance.update() == 'running'):
        time.sleep(5)
        print myinstance.update()
        
    instanceDetails = myinstance.__dict__
    #pprint(instanceDetails)
    #region = instanceDetails['placement']
    #print 'region =' + region
    publicDNS = instanceDetails['public_dns_name']
    print 'public hostname = ' + publicDNS
   
    
    # check for console output here to make sure ssh is up
    return publicDNS

def executeValidScript(SSHKEY, publicDNS):    
    filepath = "/home/whayutin/workspace/valid/src/*"
    serverpath = "/root/valid/src"
    commandPath = "/root/valid/src"
    
    os.system("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" mkdir -p /root/valid/src")
    
    print "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " -r " + filepath + " root@"+publicDNS+":"+serverpath+"/n"
    os.system("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " -r " + filepath + " root@"+publicDNS+":"+serverpath)
    
    
    if BZ is None:
        command = commandPath+"/image_validation.sh --imageID="+AMI+"_"+REGION+" --RHEL="+RHEL+" --full-yum-suite=yes --skip-questions=yes --bugzilla-username="+BZUSER+" --bugzilla-password="+BZPASS
    else:
        command = commandPath+"/image_validation.sh --imageID="+AMI+"_"+REGION+" --RHEL="+RHEL+" --full-yum-suite=yes --skip-questions=yes --bugzilla-username="+BZUSER+" --bugzilla-password="+BZPASS+" --bugzilla-num="+BZ
    print "nohup ssh -n -f -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command
    print ""
    os.system("nohup ssh -n -f -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command)

def printValues(hwp):
    print "+++++++"
    print AMI
    print REGION
    print SSHKEY
    print RHEL
    print hwp
    print "+++++++\n"

def myfunction(string, sleeptime,lock,SSHKEY,publicDNS):
        #entering critical section
        lock.acquire() 
        print string," Now Sleeping after Lock acquired for ",sleeptime
        time.sleep(sleeptime) 
        
        print string," Now releasing lock and then sleeping again"
        lock.release()
        
        #exiting critical section
        time.sleep(sleeptime) # why?
    


hwp_i386 = ['t1.micro' , 'm1.small' , 'c1.medium']
hwp_x86_64 = ['t1.micro' , 'm1.large' , 'm1.xlarge' , 'm2.xlarge' , 'm2.2xlarge' , 'm2.4xlarge' , 'c1.xlarge']


publicDNS = []

if ARCH == 'i386':
    for hwp in hwp_i386:
        printValues(hwp)
        myConn = getConnection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, REGION)
        publicDNS.append(startInstance(myConn, hwp))
        
elif ARCH == 'x86_64':
    for hwp in hwp_x86_64:
        printValues(hwp)
        myConn = getConnection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, REGION)
        publicDNS.append(startInstance(myConn, hwp))

lock = thread.allocate_lock()
print "sleep for 30 seconds"
time.sleep(30)
for host in publicDNS:  
    print "current working dir is"+os.getcwd()
    os.chdir("/home/whayutin/workspace/valid/src")
    print "current working dir is"+os.getcwd()
    executeValidScript(SSHKEY, host)
