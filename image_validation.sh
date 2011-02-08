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

if [ $# -lt 2 ];then
 echo "ERROR: The number of arguments should be two"
 echo "please use --help"
 exit 1
fi

#cli
for i in $*
 do
 case $i in
      --imageID=*)
         IMAGEID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --RHEL=*)
         RHELV="`echo $i | sed 's/[-A-Z]*=//'`"
         if [ "$RHELV" == 5 ] || [ "$RHELV" == 6 ]; then
           :
         else
           echo "The OS version is incorrect; Please specify the correct version !!!"
           echo ""
           echo "Please specify the correct rhel version e.g: --RHEL=5 or --RHEL=6"
           exit 1
         fi
         #echo the version is $RHELV
         ;;
        *)
         # unknown option 
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
           echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
           echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
           echo " http://bugzilla.redhat.com/ "
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
           echo ""
           echo "Available options are:"
           echo "--imageID   Please provide a unique id for the image"
           echo "--RHEL  Please specify the correct rhel version eg: --RHEL=5 or --RHEL=6"
           exit 1
           ;;
 esac
done

source $PWD/testlib.sh

echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
echo " http://bugzilla.redhat.com/ "
echo ""
echo "***************** DETAILED RESULTS LOGGED TO validate.log  ********************************"
echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo "" 
echo ""
test_rhel_version
echo ""
userInput_CloudProvider
userInput_Filesystem
userInput_Errata_Notification
userInput_Availability
echo "##### START TESTS #####"
echo ""
test_disk_format
test_disk_size
test_selinux
test_package_set
test_verify_rpms
test_gpg_keys
test_repos
test_yum_plugin
test_install_package
test_yum_update
test_bash_history
test_system_id
test_cloud-firstboot
test_nameserver
test_group
test_passwd
test_inittab
test_shells
test_IPv6
test_networking
test_iptables
test_sshd
test_chkconfig
test_syslog
test_auditd
test_uname
#test_swap_file


### DONT REMOVE OR COMMENT OUT ###
show_failures
open_bugzilla
sos_report
remove_bugzilla_rpms
im_exit
##################################






