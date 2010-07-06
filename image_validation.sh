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

FAILURES=0

if [ -z $1 ];then
 echo "ERROR:"
 echo "please use --help"
 exit 1
fi

#cli
for i in $*
 do
 case $i in
      --provider=*)
         PROVIDER="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --diffDir=*)
         DIFF_DIR="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --description=*)
         DESC="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --username=*)
         USER="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      *)
         # unknown option 
           echo " unknown option " 
           echo ""
           echo "Available options are:"
           echo "--provider         The cloude provider: ibm,ec2"
           echo "--diffDir   The directory where the authoritive files exist"
           echo "--description   describe the test, used for bugzilla"
           echo "--username   used for unique bug bugzilla creation"
           exit 1
           ;;
 esac
done

source $PWD/testlib.sh
echo "## START TESTS ... "
test_selinux
test_package_set
test_gpg_keys
test_verify_rpms
test_install_package
test_parted
test_yum_update
test_disk_label
test_swap_file
test_bash_history
test_system_id
test_cloud-firstboot
test_nameserver
#test_securetty # busted
test_group
test_passwd
test_inittab
test_modprobe
test_mtab
test_shells
test_repos
test_yum_plugin
#test_hostname #disabled
test_IPv6
test_networking
test_iptables
test_sshd
test_chkconfig
test_syslog
test_auditd
test_uname


### DONT REMOVE OR COMMENT OUT ###
show_failures
open_bugzilla
sos_report
remove_bugzilla_rpms
im_exit
##################################






