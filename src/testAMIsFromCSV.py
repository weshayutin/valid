from pprint import pprint
from boto import ec2
import sys, time, optparse, os, paramiko
import csv 

CSVFILE = "test.csv"
parser = optparse.OptionParser()
desc="ami test script"

parser.add_option('-i','--ec2-key', type='string',dest='AWS_ACCESS_KEY_ID',help='EC2 Access Key ID')
parser.add_option('-p','--ec2-secret-key', type='string',dest='AWS_SECRET_ACCESS_KEY',help='EC2 Secret Access Key ID')
parser.add_option('-y','--bugzilla_username', type='string',dest='BZUSER',help='bugzilla username')
parser.add_option('-z','--bugzilla_password', type='string',dest='BZPASS',help='bugzilla password')

(opts, args) = parser.parse_args()
AWS_ACCESS_KEY_ID = opts.AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY = opts.AWS_SECRET_ACCESS_KEY
BZUSER = opts.BZUSER
BZPASS = opts.BZPASS
SSHKEY = ""
SSHKEYNAME = ""

mandatories = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'BZUSER','BZPASS']
for m in mandatories:
    if not opts.__dict__[m]:
        print "mandatory option is missing\n"
        parser.print_help()
        exit(-1)

reader = csv.reader(open(CSVFILE,"rb"))
fields = reader.next()


ami = [(row[0], row[1], row[2], row[3], row[4], row[5]) for row in reader]
for x in range(len(ami)):
    #print ami[x]
    myRow = ami[x]
    print myRow
    
    REGION = myRow[0]
    ARCH = myRow[1]
    RHEL = myRow[2]
    BZ = myRow[3]
    AMI = myRow[5]
    
    if REGION == "us-east-1":
        SSHKEY = "/home/whayutin/.ec2/WESHAYUTIN/cloude-key.pem"
        SSHKEYNAME = "cloude-key"
    elif REGION == "us-west-1":
        SSHKEY = "/home/whayutin/.ec2/WESHAYUTIN/wes-us-westkey.pem"
        SSHKEYNAME = "wes-us-westkey"
    elif REGION == "eu-west-1":
        SSHKEY = "/home/whayutin/.ec2/WESHAYUTIN/eu-west-cloudekey.pem"
        SSHKEYNAME = "eu-west-cloudekey"
    elif REGION == "ap-southeast-1":
        SSHKEY = "/home/whayutin/.ec2/WESHAYUTIN/asia-cloudekey.pem"
        SSHKEYNAME = "asia-cloudekey"
    elif REGION == "ap-northeast-1":
        SSHKEY = "/home/whayutin/.ec2/WESHAYUTIN/ap-northeast-cloudekey.pem"
        SSHKEYNAME = "ap-northeast-cloudekey"
        
    print "=============== START =============================== \n"
    print myRow; print "BUGZILLA="+BZ
    print "=============== START =============================== \n"
    
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
    
    #east# reservation = ec2conn.run_instances('ami-8c8a7de5', instance_type='t1.micro', key_name='cloude-key')
    if ARCH == 'i386':
        reservation = conn_region.run_instances(AMI, instance_type='c1.medium', key_name=SSHKEYNAME)
    elif ARCH == 'x86_64':
        reservation = conn_region.run_instances(AMI, instance_type='m1.large', key_name=SSHKEYNAME)
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
    print "sleep for 90 seconds"
    time.sleep(120)
    # check for console output here to make sure ssh is up
    
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
    print "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command+"/n"
    os.system("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command)
    print "=============== DONE =============================== \n"
    print myRow
    print "=============== DONE =============================== \n"
    
