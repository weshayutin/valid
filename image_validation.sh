#!/bin/bash

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
      --diffDirectory=*)
         DIFF_DIR="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      *)
         # unknown option 
           echo " unknown option " 
           echo ""
           echo "Available options are:"
           echo "--provider         The cloude provider: ibm,ec2"
           echo "--diffDirectory   The directory where the authoritive files exist"
           exit 1
           ;;
 esac
done

source $PWD/testlib.sh

test_selinux
test_package_set
test_gpg_keys
#test_verify_rpms
#test_install_package
test_parted
#test_yum_update
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
##################################






