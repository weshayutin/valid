#!/bin/bash
# Copyright (c) 2010 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#
# written by whayutin@redhat.com
# modified by kbidarka@redhat.com for RHEL 6

FAILURES=0
MEM_HWP=0

function usage()
{
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
	   echo "Please use all options"
	   echo ""
           echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
           echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
           echo " http://bugzilla.redhat.com/ "
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
           echo ""
           echo "Available options are:"
           echo "--imageID=          :: Please provide a unique id for the image"
           echo "--RHEL=             :: Please specify the correct FULL rhel version eg: --RHEL=5.7 or --RHEL=6.1"
           echo "--full-yum-suite=   :: Please input the value  "yes" OR "no""          
	   echo "--skip-questions=   :: Please input the value  "yes" or "no""
	   echo "--bugzilla-username :: Please specify your bugzilla username@email.com"
	   echo "--bugzilla-password :: Please specify your bugzilla password"
	   echo "--bugzilla-num      :: If a bug has already been opened you can specify the number here "
	   echo "--memory	     :: Minium total memory the system *should* have available"
	   echo "--public-dns	     :: The Public-DNS Host name of the machine"
}


#cli
for i in $*
 do
 case $i in
      --imageID=*)
         IMAGEID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --RHEL=*)
         RHELV="`echo $i | sed 's/[-A-Z]*=//'`"
         ;;
      --full-yum-suite=*)
          yum_test="`echo $i | sed 's/[-a-zA-Z]*=//'`"
          if [ "$yum_test" == "yes" ] || [ "$yum_test" == "no" ]; then
            :
          else
	    usage
            exit 1
          fi
          ;;
      --skip-questions=*)
	  QUESTIONS="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-username=*)
	  BUG_USERNAME="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-password=*)
	  BUG_PASSWORD="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-num=*)
	  BUG_NUM="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --memory=*)
	  MEM_HWP="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --public-dns=*)
	  PUB_DNS="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
        *)
         # unknown option 
	   usage
           exit 1
           ;;
 esac
done


if [[ -z $IMAGEID ]] || [[ -z $RHELV ]] ||  [[ -z $yum_test ]] || [[ -z $BUG_USERNAME ]] || [[ -z $BUG_PASSWORD ]] || [[ -z $MEM_HWP ]]; then
 usage
 exit 1
fi



pushd /root/valid/src
source $PWD/testlib.sh

### DONT REMOVE OR COMMENT OUT ###
echo "opening a bugzilla for logging purposes"
open_bugzilla
##################################

echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
echo " http://bugzilla.redhat.com/ "
echo ""
echo "***************** DETAILED RESULTS LOGGED TO validate.log  ********************************"
echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo "" 
echo ""
test_fetch_host_details
test_rhel_version
echo ""
if [ $QUESTIONS == "no" ];then
 userInput_CloudProvider
 userInput_Filesystem
 userInput_Errata_Notification
 userInput_Availability
fi
echo "##### START TESTS #####"
echo ""
test_uname
test_disk_format
test_disk_size
test_swap_file
test_selinux
test_package_set
test_verify_rpms
test_gpg_keys
#test_repos #remarking this out for now.. until additional repo's land. the yum tests should be sufficient
test_yum_plugin
if [ $yum_test == "yes" ];then
 test_yum_full_test
else
 test_yum_general_test
fi
test_bash_history
test_system_id
test_cloud-firstboot
test_nameserver
test_group
test_passwd
test_inittab
test_shells
#test_IPv6 no longer needed
test_networking
test_iptables
test_sshd
test_chkconfig
test_syslog
test_auditd
test_sshSettings
test_libc6-xen.conf
test_grub
#installTestKernel
test_resize2fs


### DONT REMOVE OR COMMENT OUT ###
show_failures
open_bugzilla
bugzilla_comments
setup_rc.local 
#sos_report
echo "REBOOTING"
sleep 1
echo "REBOOTING"
sleep 1
echo "REBOOTING"
reboot
#im_exit
##################################






