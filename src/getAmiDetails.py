from pprint import pprint
from boto import ec2
import sys, time, optparse, os, paramiko


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
parser.add_option('-s','--ssh-key', type='string',dest='SSHKEY',help='full path to ssh key for the ec2 region')
parser.add_option('-i','--ec2-key', type='string',dest='AWS_ACCESS_KEY_ID',help='EC2 Access Key ID')
parser.add_option('-p','--ec2-secret-key', type='string',dest='AWS_SECRET_ACCESS_KEY',help='EC2 Secret Access Key ID')
parser.add_option('-y','--bugzilla_username', type='string',dest='BZUSER',help='bugzilla username')
parser.add_option('-z','--bugzilla_password', type='string',dest='BZPASS',help='bugzilla password')


(opts, args) = parser.parse_args()
AMI = opts.AMI
REGION = opts.REGION
RHEL = opts.RHEL
BZ = opts.BZ
SSHKEY = opts.SSHKEY
AWS_ACCESS_KEY_ID = opts.AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY = opts.AWS_SECRET_ACCESS_KEY
BZUSER = opts.BZUSER
BZPASS = opts.BZPASS

mandatories = ['AMI','REGION','SSHKEY','RHEL','AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']
for m in mandatories:
    if not opts.__dict__[m]:
        print "mandatory option is missing\n"
        parser.print_help()
        exit(-1)

print "+++++++"
print AMI
print REGION
print SSHKEY
print RHEL
print "+++++++\n"

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
reservation = conn_region.run_instances(AMI, instance_type='t1.micro', key_name='cloude-key')
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
time.sleep(90)
# check for console output here to make sure ssh is up

filepath = "/home/whayutin/workspace/valid/src/*"
serverpath = "/root"
print "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " -r " + filepath + " root@"+publicDNS+":"+serverpath
os.system("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " -r " + filepath + " root@"+publicDNS+":"+serverpath)

if BZ is None:
    command = "/root/image_validation.sh --imageID="+AMI+"_"+REGION+" --RHEL="+RHEL+" --full-yum-suite=yes --skip-questions=yes --bugzilla-username="+BZUSER+" --bugzilla-password="+BZPASS
else:
    command = "/root/image_validation.sh --imageID="+AMI+"_"+REGION+" --RHEL="+RHEL+" --full-yum-suite=yes --skip-questions=yes --bugzilla-username="+BZUSER+" --bugzilla-password="+BZPASS+" --bugzilla-num="+BZ
print "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command
os.system("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "+SSHKEY+ " root@"+publicDNS+" "+command)

