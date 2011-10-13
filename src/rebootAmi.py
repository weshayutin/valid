#!/usr/bin/python -tt

from pprint import pprint
from boto import ec2
import boto, thread
import sys, time, optparse, os
#from boto.ec2.blockdevicemapping import BlockDeviceMapping
from boto.ec2.blockdevicemapping import EBSBlockDeviceType, BlockDeviceMapping
from bugzilla.bugzilla3 import Bugzilla36

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
parser.add_option('-m','--arch',  dest='ARCH', default='x86_64', help='arch = i386, or x86_64')




(opts, args) = parser.parse_args()
AMI = opts.AMI
REGION = opts.REGION
RHEL = opts.RHEL
SSHKEY = opts.SSHKEY
SSHKEYNAME = opts.SSHKEYNAME
AWS_ACCESS_KEY_ID = opts.AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY = opts.AWS_SECRET_ACCESS_KEY
ARCH = opts.ARCH





mandatories = ['AMI','REGION','SSHKEY','RHEL','AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'ARCH']
for m in mandatories:
    if not opts.__dict__[m]:
        print "mandatory option is missing\n"
        parser.print_help()
        exit(-1)
        


def getConnection(key, secret, region):
    """establish a connection with ec2"""
    reg = boto.ec2.get_region(region, aws_access_key_id=key,
        aws_secret_access_key=secret)
    return reg.connect(
        aws_access_key_id=key, aws_secret_access_key=secret)

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
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME, block_device_map=map )
    elif ARCH == 'x86_64':
        reservation = conn_region.run_instances(AMI, instance_type=hardwareProfile, key_name=SSHKEYNAME, block_device_map=map)
    else:
        print "arch type is neither i386 or x86_64.. will exit"
        exit(1)
        
    myinstance = reservation.instances[0]
    
    time.sleep(5)
    while(not myinstance.update() == 'running'):
        time.sleep(5)
        print myinstance.update()
        
    instanceDetails = myinstance.__dict__
    pprint(instanceDetails)
    #region = instanceDetails['placement']
    #print 'region =' + region
    publicDNS = instanceDetails['public_dns_name']
    print 'public hostname = ' + publicDNS
   
    
    # check for console output here to make sure ssh is up
    return myinstance


    

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

def startAndReboot(hwp):
    printValues(hwp)
    myConn = getConnection(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, REGION)
    this_hostname = startInstance(myConn, hwp["name"])
    print "sleep for 60 seconds"
    time.sleep(60)
    print 'SSH into running instance NOW'
    print "sleep for 30 seconds"
    time.sleep(30)
    print this_hostname.update()
        
    print 'REBOOTING'
    print this_hostname.reboot();
        
    print this_hostname.update()
    time.sleep(130)
    print this_hostname.update()

# Define hwp
m1Small = {"name":"m1.small","memory":"1700000","cpu":"1","arch":"i386"}
m1Large = {"name":"m1.large","memory":"7500000","cpu":"2","arch":"x86_64"}
m1Xlarge = {"name":"m1.xlarge","memory":"15000000","cpu":"4","arch":"x86_64"}
t1Micro = {"name":"t1.micro","memory":"600000","cpu":"1","arch":"both"}
m2Xlarge = {"name":"m2.2xlarge","memory":"17100000","cpu":"2","arch":"x86_64"}
m22Xlarge = {"name":"m2.2xlarge","memory":"34200000","cpu":"4","arch":"x86_64"}
m24Xlarge = {"name":"m2.4xlarge","memory":"68400000","cpu":"8","arch":"x86_64"}
c1Medium = {"name":"c1.medium","memory":"1700000","cpu":"2","arch":"i386"}
c1Xlarge = {"name":"c1.xlarge","memory":"7000000","cpu":"8","arch":"x86_64"}   


#Use all hwp types for ec2 memory tests, other hwp tests
#hwp_i386 = [c1Medium, t1Micro , m1Small ]
#hwp_x86_64 = [m1Xlarge, t1Micro , m1Large , m2Xlarge , m22Xlarge , m24Xlarge , c1Xlarge]
#hwp_x86_64 = [m1Large , m1Xlarge]

#Use just one hwp for os tests
hwp_i386 = [c1Medium]
hwp_x86_64 = [m1Xlarge]



publicDNS = []

if ARCH == 'i386':
    for hwp in hwp_i386:
        startAndReboot(hwp)
        
                  
if ARCH == 'x86_64':
    for hwp in hwp_x86_64:
        startAndReboot(hwp)
        
        



