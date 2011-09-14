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
# modified by kbidarka@redhat.com

LOGFILE=$PWD/validate.log
DLOG=" tee -a ${LOGFILE} " #Display and log output
cat /dev/null > $LOGFILE
RSLT=""
LOGRESULT="echo ${RSLT} 1>>$LOGFILE 2>>$LOGFILE"
DIFFDIR=$PWD
SYSDATE=$( /bin/date '+%Y-%m-%d %H:%M' )
UNAMEI=$( /bin/uname -i )
BETA=0


echo ""
echo ""

txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtrst=$(tput sgr0)       # Text reset

### Begin:  Create a list of partitions
rm -Rf disk_partitions
rm -Rf swap_partitions
mount | grep ^/dev | awk '{print $1}' >> disk_partitions
parted -l | grep -B 5 swap | grep ^Disk | awk '{print $2}' | sed '$s/.$//' >> swap_partitions

rm -Rf tmp1_partitions tmp2_partitions
### End:  Create a list of partitions

RHEL=`cat /etc/redhat-release | awk '{print $7}' | awk -F. '{print $1}'`
RHELU=`cat /etc/redhat-release | awk '{print $7}' | awk -F. '{print $2}'`
RHEL_FOUND=$RHEL.$RHELU
KERNEL=""
KERNEL_UPDATED=""
TEST_CURRENT=""
TEST_FAILED=""
echo "IMAGE ID= ${IMAGEID}" >> $LOGFILE



function new_test()
{
	echo -n $1
	echo "######################################################################################" >> $LOGFILE
	echo "# NEW TEST: $1" >> $LOGFILE
	TEST_CURRENT=$1
	echo "######################################################################################" >> $LOGFILE
}

#rus a basic command
function rc()
{
	echo "COMMAND: $1" >>$LOGFILE
 	RSLT=`eval $1 2>>${LOGFILE}`
	rc=$?
	echo "RETURN CODE: $rc" >>$LOGFILE
}

function rq()
{
	echo "QUESTION: $1" 
}

#runs a basic command and redirects stdout to file $2
function rc_outFile()
{
	echo "COMMAND: $1 $2" >>$LOGFILE
 	`eval $1 1>>${LOGFILE}` 
	rc=$?
	echo "RETURN CODE: $rc" >>$LOGFILE
}

#runs a basic command and asserts its return code
function assert()
{
        args=("$@")
        cmd=${args[0]}
        option=${args[1]}
        option2=${args[2]}
        echo "COMMAND:  $1"  >>$LOGFILE
        RSLT=`eval $cmd 2>>$LOGFILE`
        rc=$?
        echo "RESULT: $RSLT " >>$LOGFILE
	if [ -z $option2 ];then
         echo "EXPECTED RESULT: $option" >>$LOGFILE
	 option2="zzz###zzz"
	else
         echo "EXPECTED RESULT: $option OR $option2 " >>$LOGFILE
	fi
        echo "RETURN CODE: $rc" >>$LOGFILE

        if [[ "$RSLT" == "$option" ]] || [[ "$RSLT" == $option2 ]] && [[ "$option" != "" ]];then
         #echo "IN FIRST TEST" >>$LOGFILE
         echo "${txtgrn}PASS${txtrst}" 
         echo "PASS" >> $LOGFILE
        elif [ -z "$option" ] && [ "$rc" == 0 ];then
         #echo "IN SECOND TEST" >>$LOGFILE
         echo "${txtgrn}PASS${txtrst}" 
         echo "PASS" >> $LOGFILE
	elif [[ "$rc" == "$option" ]];then
         echo "${txtgrn}PASS${txtrst}" 
         echo "PASS" >> $LOGFILE
        elif [[ "$RSLT" != "$option" ]] && [[ "$RSLT" != "$option2" ]] &&  [[ "$rc" != 0 ]] ;then
         #echo "IN THIRD TEST" >>$LOGFILE
         echo "${txtred}FAIL${txtrst}" 
         echo "FAIL1" >>  $LOGFILE
         echo ${RSLT} >>${LOGFILE}
	 TEST_FAILED="$TEST_FAILED $TEST_CURRENT"
         let FAILURES++
        else
         echo "${txtred}FAIL${txtrst}" 
         echo "FAIL2" >>  $LOGFILE
         echo ${RSLT} >>${LOGFILE}
	 TEST_FAILED="$TEST_FAILED $TEST_CURRENT"
         let FAILURES++
        fi
}

function test_rhel_version()
{
	pwd >> $LOGFILE
        hostname >> $LOGFILE
	echo  `cat /etc/redhat-release` >> $LOGFILE
        if [ $RHELV == $RHEL_FOUND ]; then
          new_test "The selected image has the version RHEL $RHELV"
        else
          echo "Version Mismatched !!!!, The input version RHEL$RHELV should be similar to the selected Ami's version RHEL$RHEL_FOUND" 
          exit
        fi
	BETA=`cat /etc/redhat-release  | grep -i beta | wc -l`
	if [ $BETA == 1 ]; then 
	 echo "ami is a BETA" >> $LOGFILE
	fi
}

function print_rhel_version()
{
        echo  hostname >> $LOGFILE
	echo  `cat /etc/redhat-release`
        if [ $RHELV == $RHEL_FOUND ]; then
          new_test "The selected image has the version RHEL $RHELV"
        else
          echo "Version Mismatched !!!!, The input version RHEL$RHELV should be similar to the selected Ami's version RHEL$RHEL_FOUND" 
          echo "Version Mismatched !!!!, Check the logs to see if yum update changed the RHEL version" 
        fi
}

function test_fetch_host_details()
{
	yum install -y wget > /dev/null
        BP_ID=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i billingProducts | gawk -F":" '{print $NF}' | gawk -F"\"" '{print $2}'`
        if [ $BP_ID == "bp-6fa54006" ]; then
          HOSTNAME=`hostname`
          INS_ID=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i instanceId | gawk '{print $NF}'| gawk -F"\"" '{print $2}'`
          IMG_ID=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i imageId | gawk '{print $NF}'| gawk -F"\"" '{print $2}'`
          INS_TYP=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i instanceType | gawk '{print $NF}'| gawk -F"\"" '{print $2}'`
          ARCH=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i architecture | gawk '{print $NF}'| gawk -F"\"" '{print $2}'`
          REG=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/document | grep -i zone | gawk '{print $NF}'| gawk -F"\"" '{print $2}'`
	  SIGN1=`wget -q  -O - http://169.254.169.254/latest/dynamic/instance-identity/signature`
          new_test "Fetching Host Details "
          echo "This Host => $PUB_DNS with Image Id : $IMG_ID, is launched with Instance Id : $INS_ID , Instance Type : $INS_TYP and Arch : $ARCH in the Region : $REG" >> $LOGFILE
	  echo "This is a Hourly image" >> $LOGFILE
	  echo "The Validate Signature is : $SIGN1" >> $LOGFILE
        else
	  new_test "Fetching Host Details "
          echo "This is not a Hourly image" >> $LOGFILE
        fi
}

function userInput_CloudProvider()
{
	echo ""
	echo "******** Please answer the following questions *********"
	new_test  "Cloud Provider Basic Information.." 
	echo ""
	rq "What is the cloud providers company name?"
	read answer
	echo $answer >>$LOGFILE
	rq "What is your full name?"
	read answer
	echo $answer >>$LOGFILE
	rq "What is your email address?"
	read email
	echo $email >>$LOGFILE
}

function userInput_Filesystem()
{
	echo ""
	echo "******** Please answer the following questions *********"
	new_test "Non-Standard Image Layout or Filesystem Types.." 
	echo ""
	rq "If this image contains a non standard partition or filesystem, please describe it"
	read answer
	echo $answer >>$LOGFILE
}

function userInput_Errata_Notification()
{
	echo ""
	echo "******** Please answer the following questions *********"
	new_test "Description of Errata Notification Procedure/Process to be Used to Notify Cloud Users" 
	echo ""
	rq "Please describe the process to be used in order to notify Cloud Users of errata and critical updates."
	read answer
	echo $answer >>$LOGFILE
}

function userInput_Availability()
{
	echo ""
	echo "******** Please answer the following questions *********"
	new_test "Description of Policy for Availability of Updated Starter Images" 
	echo ""
	rq "Please clearly define the policy for making starter images available."
	read answer
	echo $answer >>$LOGFILE
	new_test "Description of Policy for retiring  starter images" 
	echo ""
	rq "Please clearly define the policy for retiring "
	read answer
	echo $answer >>$LOGFILE
}

function test_disk_size()
{
 	new_test "## Partition Size ..."
 	for part in $(cat disk_partitions);do
	echo "size=`df -k $part | awk '{ print $2 }' | tail -n 1`" >> $LOGFILE
        size=`df -k $part | awk '{ print $2 }' | tail -n 1`
  	 if [ "$size" -gt "3937219" ]
	  then
	   echo "$part is 4gb or greater"
	   assert "echo true" true
          else  
	   echo "$part is NOT 4gb or greater"
	   assert "echo false" true
  	 fi
        done
}

function test_disk_format()
{
 	new_test "## Partition Format  ..."
 	for part in $(cat disk_partitions);do
	echo "mount | grep $part | awk '{ print $5 }'" >> $LOGFILE
	result=`mount | grep $part | awk '{ print $5 }'`

	if [ $RHEL == 5 ] ; then
	assert "echo $result" ext3
	else
	ext=`mount | grep $part | awk '{print $3}'`
        if [ "$ext" == "/" ] ; then 
	 assert "echo $result" "ext4"
	else
	 assert "echo $result" "ext3"
	fi
	fi
	done
}


function test_selinux()
{
 	echo "## SELINUX TESTS"
	new_test "## /sbin/getenforce ... " 
	assert "/usr/sbin/getenforce" "Enforcing"
	
	new_test "## Verify SELINUX enforcing ... " 
	assert "grep ^SELINUX= /etc/sysconfig/selinux | cut -d\= -f2" enforcing

	new_test "## Verify SELINUXTYPE targeted ... " 
	assert "grep ^SELINUXTYPE= /etc/sysconfig/selinux | cut -d\= -f2" targeted

	new_test "## Flip Selinux Permissive ... "
	assert "/usr/sbin/setenforce Permissive && /usr/sbin/getenforce" Permissive

	new_test "## Flip Selinux Enforcing ... "
	assert "/usr/sbin/setenforce Enforcing && /usr/sbin/getenforce" Enforcing

}


function test_package_set()
{
        new_test  "## Verify no missing packages ... "
        file=/tmp/rpmqa
        rc "/bin/rpm -qa --queryformat='%{NAME}\n' > ${file}.tmp"
        #/bin/rpm -qa --queryformat="%{NAME}.%{ARCH}\n" > ${file}.tmp  
        cat ${file}.tmp  |  sort -f > ${file}
	if [ $RHEL == 5 ] ; then
         rc "comm -23 packages_5 ${file}"
         comm -23 packages_5 ${file} > /tmp/package_diff
	elif [ $RHEL_FOUND == "6.0" ]; then
         rc "comm -23 packages_6 ${file}"
         comm -23 packages_6 ${file} > /tmp/package_diff
	elif [ $RHEL_FOUND == "6.1" ]; then	
	 rc "comm -23 packages_61 ${file}"
         comm -23 packages_61 ${file} > /tmp/package_diff
	else
         echo "VERSION NOT FOUND"
        fi

	cat /tmp/package_diff >>$LOGFILE
	COUNT=`cat /tmp/package_diff | wc -l`
	echo "COUNT = `cat /tmp/package_diff | wc -l`" >> $LOGFILE
	if [ $BETA == 1 ]; then
		if [ $COUNT == 1 ]; then
	 		assert "cat /tmp/package_diff | wc -l" 1
		else
			assert "echo test failed" 1
		fi
	else
		if [ $COUNT -gt 0 ]; then
			assert "echo test failed" 1
		else
			assert "echo test passed" 0
		fi
	fi
}

function test_verify_rpms()
{
    THIS_RHEL=`echo $RHELV | cut -d . -f 1`
    if [ $THIS_RHEL == 5 ] ; then
	file=/tmp/rpmqaV.txt
        new_test "## Verify RPMs ... " 
        /bin/rpm -Va --nomtime --nosize --nomd5 2>> $LOGFILE | sort -fu > ${file}
        echo "/bin/rpm -Va --nomtime --nosize --nomd5" >> $LOGFILE
	    cat $file >> $LOGFILE
	    cat rpmVerifyTable >> $LOGFILE
        assert "cat ${file} | wc -l" "2"
        new_test "## Verify Version 2 ... "
        assert "/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2" $RHELV # to-do, pass this in
     else
	file=/tmp/rpmqaV.txt
        new_test "## Verify RPMs ... " 
        /bin/rpm -Va --nomtime --nosize --nomd5 2>> $LOGFILE | sort -fu > ${file}
	    cat $file >> $LOGFILE
	    cat rpmVerifyTable >> $LOGFILE
	if [[ $RHEL_FOUND == "6.1" ]] && [[ $UNAMEI == "x86_64" ]]  ; then
         assert "cat ${file} | wc -l" "5"
	else
         assert "cat ${file} | wc -l" "4"
	fi
        new_test "## Verify Version 2 ... " 
        assert "/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release-server | cut -d. -f1,2" $RHELV # to-do, pass this in
     fi
        
	new_test "## Verify packager ... "
        file=/tmp/Packager
        `cat /dev/null > $file`
        #echo "for x in $file ;do echo -n $x >> $file; rpm -qi $x | grep Packager >> $file;done" >>$LOGFILE
        for x in $(cat /tmp/rpmqa);do
         echo -n $x >>$file
         rpm -qi $x | grep Packager >>$file
        done
        assert "cat $file | grep -v 'Red Hat, Inc.' |  grep -v crash-trace-commandPackager| wc -l" 0
        cat $file | grep -v 'Red Hat, Inc.' >>$LOGFILE	
}

function test_yum_full_test()
{
        #echo "Invoking more rigorous yum tests"
        new_test "## List the configured repositories..."
        assert "/usr/bin/yum repolist" 

        new_test "## Search zsh..."
        assert "/usr/bin/yum search zsh" 

        new_test "## install zsh ... "
        rc "/usr/bin/yum -y install zsh"
        assert "/bin/rpm -q --queryformat '%{NAME}\n' zsh" zsh

        new_test "## List available groups.."
        assert "/usr/bin/yum grouplist" 

        new_test "## Install Development tools group..." 
        assert "/usr/bin/yum -y groupinstall 'Development tools'"

        new_test "## Verify yum update ... "
        assert "/usr/bin/yum -y update"  
 	
	new_test "## Verify no fa1lures in rpm package ... "
	assert "cat $LOGFILE | grep 'failure in rpm package' | wc -l" "1"
	
	new_test "## Verify no rpm scriplet fa1lures ... "
	assert "cat $LOGFILE | grep 'scriptlet failed, exit status 1' | wc -l" "1"

        new_test "## Verify package removal... "
        rc "/bin/rpm -e zsh"
        assert "/bin/rpm -q zsh" "package zsh is not installed"

}

function test_yum_general_test()
{
        new_test "## install zsh ... "
        rc "/usr/bin/yum -y install zsh"
        assert "/bin/rpm -q --queryformat '%{NAME}\n' zsh" zsh

        new_test "## Verify package removal ... "
        rc "/bin/rpm -e zsh"
        assert "/bin/rpm -q zsh" "package zsh is not installed"

        new_test "## Verify yum update ... " 
	assert "/usr/bin/yum -y update" 
}

function test_bash_history()
{
	new_test "## Verify bash_history ... "
	assert "cat ~/.bash_history | wc -l " 0 
}


function test_swap_file()
{
	new_test "## Verify turning on/off swap file ... "
	if [ $UNAMEI == "i386" ]; then
	 swap=`cat swap_partitions`
	 fst=`cat /etc/fstab | grep swap | awk '{print $1}'`
	 [ $swap != $fst ] && [ -b /dev/xvde3] && sed -i 's/\/dev\/xvda3/\/dev\/xvde3/' /etc/fstab 
	 [ $swap != $fst ] && [ -b /dev/xvda3] && sed -i 's/\/dev\/xvde3/\/dev\/xvda3/' /etc/fstab 
	 assert "/sbin/swapoff $swap && /sbin/swapon $swap"
	fi

# The below logic needs to be reversed, after checking the actual images. Actual images have swap partitions only for i386 and not for x86_64.
	new_test "## Verify swap size ... "
	if [ $UNAMEI == "i386" ]; then
	 size=`free | grep Swap | awk '{print $2}'`
	 echo "free | grep Swap | awk '{print $2}'" >> $LOGFILE
         echo "swap size = $size" >> LOGFILE
	 if [ $size -gt 0 ]; then
	  assert "echo true" 
         else 
	  assert "echo false" "1"
	 fi
	fi 
          	
	if [ $UNAMEI == "x86_64" ]; then
	 echo "no swap for x86_64 is expected" >> $LOGFILE
	fi
	
}

function test_system_id()
{
        new_test "## Verify no systemid file ... " 
	if [ ! -f /etc/sysconfig/rhn/systemid ]; then
	 assert "echo true"
	else
	 assert "/bin/asdf"
	fi
}

function test_cloud-firstboot()
{
	if [ $RHELV == 6.0 ]; then
	 echo "WAIVED TESTS FOR BUGZILLA 704821"
	else
         new_test "## Verify rh-cloud-firstboot is on ... "
	 assert "chkconfig --list | grep rh-cloud | grep 3:off | wc -l" "1"
         if [  -f /etc/sysconfig/rh-cloud-firstboot ]; then
	  echo "/etc/sysconfig/rh-cloud-firstboot FOUND" >> $LOGFILE
          assert "echo true"
         else
	  echo "/etc/sysconfig/rh-cloud-firstboot NOT FOUND" >> $LOGFILE
	  assert "/bin/asdf"
	 fi
	 assert "cat /etc/sysconfig/rh-cloud-firstboot" "RUN_FIRSTBOOT=NO"
	fi
}

function test_nameserver()
{
	new_test "## Verify nameserver ... "
	assert "/usr/bin/dig clock.redhat.com 2>> $LOGFILE | grep 66.187.233.4  | wc -l"
}

function test_group()
{
        new_test "## Verify group file ... " 
	assert "cat /etc/group | grep root:x:0" "root:x:0:root"
	assert "cat /etc/group | grep bin:x:1" "bin:x:1:root,bin,daemon"
	assert "cat /etc/group | grep daemon:x:2" "daemon:x:2:root,bin,daemon"
	assert "cat /etc/group | grep nobody:x:99" "nobody:x:99:"
}

function test_passwd()
{
	new_test "## Verify new passwd file ... "
	assert "cat /etc/passwd | grep root:x:0" "root:x:0:0:root:/root:/bin/bash"
	assert "cat /etc/passwd | grep nobody:x:99" "nobody:x:99:99:Nobody:/:/sbin/nologin"
	assert "cat /etc/passwd | grep sshd" "sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin"
}

function test_inittab()
{
        if [ $RHEL == 5 ] ;then
	new_test "## Verify runlevel ... " 
	assert "cat /etc/inittab | grep id:" "id:3:initdefault:"
	assert "cat /etc/inittab | grep si:" "si::sysinit:/etc/rc.d/rc.sysinit"
	else	
	new_test "## Verify runlevel ... " 
	assert "cat /etc/inittab | grep id:" "id:3:initdefault:"
	fi
}


function test_shells()
{
        new_test "## Verify new shells file ... " 
	assert "cat /etc/shells | grep bash" "/bin/bash"
	assert "cat /etc/shells | grep nologin" "/sbin/nologin"
}

function test_repos()
{
    
	if [ $RHEL == 5 ]; then
	new_test "## test repo files ... "
	assert "ls /etc/yum.repos.d/ | wc -l " 6
	assert "ls /etc/yum.repos.d/redhat* | wc -l" 4
	assert "ls /etc/yum.repos.d/rhel* | wc -l" 2
    else
	new_test "## test repo files ... "
	assert "ls /etc/yum.repos.d/ | wc -l " 4
	assert "ls /etc/yum.repos.d/redhat* | wc -l" 4
	assert "ls /etc/yum.repos.d/rhel* | wc -l" 0
    fi
}

function test_yum_plugin()
{
        new_test "## Verify disabled yum plugin ... "
	assert "grep ^enabled /etc/yum/pluginconf.d/rhnplugin.conf | grep -v '^#' | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq"
}

function test_gpg_keys()
{
        new_test "## Verify GPG checking ... " 
	assert "grep '^gpgcheck=1' /etc/yum.repos.d/redhat-*.repo | cut -d\= -f2 | sort -f | uniq" 1

	new_test "## Verify GPG Keys ... "
	if [ $BETA == 1 ]; then	
	 assert "rpm -qa gpg-pubkey* | wc -l " 3
	elif [ $RHEL_FOUND == "6.1" ]; then
	 assert "rpm -qa gpg-pubkey* | wc -l " 2
	else
	 assert "rpm -qa gpg-pubkey* | wc -l " 2
	fi


	if [ $BETA == 1 ]; then
 	 echo "SKIPPING TEST, BETA DETECTED" >> $LOGFILE
	elif [[ $RHEL == 5 ]] && [[ $BETA == 0 ]]; then
	 new_test "## Verify GPG RPMS ... "
	 assert "rpm -qa gpg-pubkey* | sort -f | tail -n 1" "gpg-pubkey-37017186-45761324"
	 assert "rpm -qa gpg-pubkey* |  grep 2fa6" "gpg-pubkey-2fa658e0-45700c69"
	elif [[ $RHEL_FOUND == "6.1" ]] && [[ $BETA == 0 ]]; then
         assert "rpm -qa gpg-pubkey* | sort -f | tail -n 1" "gpg-pubkey-fd431d51-4ae0493b"
         assert "rpm -qa gpg-pubkey* | sort -f | head -n 1" "gpg-pubkey-2fa658e0-45700c69"
        else
	 new_test "## Verify GPG RPMS ... "
	 assert "rpm -qa gpg-pubkey* | sort -f | tail -n 1" "gpg-pubkey-fd431d51-4ae0493b"
	 assert "rpm -qa gpg-pubkey* |  grep 2fa6" "gpg-pubkey-2fa658e0-45700c69"
    	fi 
}

function test_IPv6()
{
        new_test "## Verify IPv6 disabled ... "
	assert "grep ^NETWORKING_IPV6= /etc/sysconfig/network" "NETWORKING_IPV6=no"
}

function test_networking()
{
        new_test "## Verify networking ... "
 	assert "grep ^NETWORKING= /etc/sysconfig/network | cut -d\= -f2" yes	

	new_test "## Verify device ... "
	assert "grep ^DEVICE= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2" eth0
}

function test_sshd()
{
	new_test "## Verify sshd ..."
	assert "chkconfig --list | grep sshd" "sshd           	0:off	1:off	2:on	3:on	4:on	5:on	6:off"
	assert "/etc/init.d/sshd status | grep running | wc -l"  1
}


function test_iptables()
{       
	if [ $RHEL == 5 ]; then
        new_test "## Verify iptables ... "
        rc_outFile "/etc/init.d/iptables status | grep REJECT"
	assert "/etc/init.d/iptables status | grep :22 | grep ACCEPT | wc -l " "1" 
	assert "/etc/init.d/iptables status | grep "dpt:631" | grep ACCEPT | wc -l " "2"
#	assert "/etc/init.d/iptables status | grep "icmp type" | grep ACCEPT | wc -l" "1"
	assert "/etc/init.d/iptables status | grep "dpt:5353" | grep ACCEPT | wc -l" "1"
	assert "/etc/init.d/iptables status | grep "RELATED,ESTABLISHED" | grep ACCEPT | wc -l" "1"
	assert "/etc/init.d/iptables status | grep -e esp -e ah | grep ACCEPT | wc -l" "2"	
#	assert "/etc/init.d/iptables status | grep :80 | grep ACCEPT | wc -l " "1" 
#	assert "/etc/init.d/iptables status | grep :443 | grep ACCEPT | wc -l " "1" 
	assert "/etc/init.d/iptables status | grep REJECT | grep all | grep 0.0.0.0/0 | grep icmp-host-prohibited |  wc -l" "1" 
	else
        new_test "## Verify iptables ... "
        rc_outFile "/etc/init.d/iptables status | grep REJECT"
        assert "/etc/init.d/iptables status | grep :22 | grep ACCEPT | wc -l " "1"
#        assert "/etc/init.d/iptables status | grep "dpt:631" | grep ACCEPT | wc -l " "2"
#       assert "/etc/init.d/iptables status | grep "icmp type" | grep ACCEPT | wc -l" "1"
#        assert "/etc/init.d/iptables status | grep "dpt:5353" | grep ACCEPT | wc -l" "1"
#        assert "/etc/init.d/iptables status | grep "ESTABLISHED,RELATED" | grep ACCEPT | wc -l" "1"
#        assert "/etc/init.d/iptables status | grep -e esp -e ah | grep ACCEPT | wc -l" "2"
#       assert "/etc/init.d/iptables status | grep :80 | grep ACCEPT | wc -l " "1"
#       assert "/etc/init.d/iptables status | grep :443 | grep ACCEPT | wc -l " "1"
#        assert "/etc/init.d/iptables status | grep REJECT | grep all | grep 0.0.0.0/0 | grep icmp-host-prohibited |  wc -l" "1"
	  fi
}

function test_chkconfig()
{
 
	if [ $RHEL == 5 ]; then
    new_test "## Verify  chkconfig ... "
	assert "chkconfig --list | grep crond | cut -f 5" "3:on"
	assert "chkconfig --list | grep  iptables | cut -f 5" "3:on"
	assert "chkconfig --list | grep yum-updatesd | cut -f 5" "3:on"
    else
    new_test "## Verify  chkconfig ... "
	assert "chkconfig --list | grep crond | cut -f 5" "3:on"
	assert "chkconfig --list | grep  iptables | cut -f 5" "3:on"
    fi
}

function test_sshSettings()
{
	new_test "## Verify sshd_config settings ..."
	assert "cat /etc/ssh/sshd_config  | grep  PasswordAuthentication | grep no | wc -l" "1"
}

function test_libc6-xen.conf()
{
	new_test "## Verify /etc/ld.so.conf.d/libc6-xen.conf is not present ... "
	if [ $UNAMEI == "x86_64" ]; then
  	 assert "ls /etc/ld.so.conf.d/libc6-xen.conf" "2"
	else
	 assert "ls /etc/ld.so.conf.d/libc6-xen.conf" "2"	
	fi
}

function test_syslog()
{
        new_test "## Verify rsyslog is on ... " 
	assert "chkconfig --list | grep rsyslog | cut -f 5" "3:on"
	new_test "## Verify rsyslog config ... "
	if [ $RHEL == 5 ] ; then
	  assert "md5sum /etc/rsyslog.conf | cut -f 1 -d  \" \"" "bd4e328df4b59d41979ef7202a05e074"  "15936b6fe4e8fadcea87b54de495f975"
	  #assert "md5sum /etc/rsyslog.conf | cut -f 1 -d  \" \"" "15936b6fe4e8fadcea87b54de495f975"
	else
	 assert "md5sum /etc/rsyslog.conf | cut -f 1 -d  \" \"" "dd356958ca9c4e779f7fac13dde3c1b5"
	fi
}

function test_auditd()
{
    new_test "## Verify auditd is on ... "
	assert "/sbin/chkconfig --list auditd | grep 3:on"
        assert "/sbin/chkconfig --list auditd | grep 5:on"

	new_test "## Verify audit.rules ... "
	assert "md5sum /etc/audit/audit.rules | cut -f 1 -d  \" \"" "f9869e1191838c461f5b9051c78a638d"

	new_test "## Verify auditd.conf ... "
	assert "md5sum /etc/audit/auditd.conf | cut -f 1 -d  \" \"" "612ddf28c3916530d47ef56a1b1ed1ed"

	new_test "## Verify auditd sysconfig ... "
	assert "md5sum /etc/sysconfig/auditd | cut -f 1 -d  \" \"" "123beb3a97a32d96eba4f11509e39da2"
}

function test_uname()
{
        new_test "## Verify kernel name ... "
	assert "/bin/uname -s" Linux

	new_test "## Verify latest installed kernel is running ... "
	if [ $RHEL == 5 ] ; then
	 echo "LATEST_RPM_KERNEL_VERSION=`rpm -q kernel-xen | tail -n 1 | cut -c 12-50| sed 's/\(.*\)..../\1/'`" >> $LOGFILE
	 LATEST_RPM_KERNEL_VERSION=`rpm -q kernel-xen | tail -n 1 | cut -c 12-50| sed 's/\(.*\)..../\1/'`
	 echo "CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed 's/\(.*\)......./\1/'`" >> $LOGFILE
	 CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed 's/\(.*\)......./\1/'`
	 echo "assert latest rpm kernel = uname -r" >> $LOGFILE
         #assert "rpm -q kernel-xen | sort -n | tail -n 1 | cut -c 12-50| sed 's/\(.*\)..../\1/'"  $CURRENT_UNAME_KERNAL_VERSION
	 assert "uname -r | sed 's/\(.*\)......./\1/'"  $LATEST_RPM_KERNEL_VERSION
	elif [[ $RHEL == 6 ]] && [[ $UNAMEI == "i386" ]] ; then
	 echo "RHEL VERSION IS $RHEL" >> $LOGFILE
	 echo "LATEST_RPM_KERNEL_VERSION=rpm -q kernel --last | head -n 1 |  cut -c 8-60 | cut -d ' ' -f 1" >> $LOGFILE
	 LATEST_RPM_KERNEL_VERSION=`rpm -q kernel --last | head -n 1 |  cut -c 8-60 | cut -d ' ' -f 1`
	 echo "CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed  's/\(.*\)...../\1/'`" >> $LOGFILE
	 CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed  's/\(.*\)...../\1/'`
	 echo "assert latest rpm kernel = uname -r" >> $LOGFILE
         #assert "rpm -q kernel-xen | sort -n | tail -n 1 | cut -c 12-50| sed 's/\(.*\)..../\1/'"  $CURRENT_UNAME_KERNAL_VERSION
	 assert "uname -r | sed  's/\(.*\)...../\1/'"  $LATEST_RPM_KERNEL_VERSION
	elif [[ $RHEL == 6 ]] && [[ $UNAMEI == "x86_64" ]] ; then
	 echo "RHEL VERSION IS $RHEL" >> $LOGFILE
	 echo "LATEST_RPM_KERNEL_VERSION=rpm -q kernel --last | head -n 1 |  cut -c 8-60 | cut -d ' ' -f 1" >> $LOGFILE
	 LATEST_RPM_KERNEL_VERSION=`rpm -q kernel --last | head -n 1 |  cut -c 8-60 | cut -d ' ' -f 1`
	 echo "CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed  's/\(.*\)......./\1/'`" >> $LOGFILE
	 CURRENT_UNAME_KERNAL_VERSION=`uname -r | sed  's/\(.*\)......./\1/'`
	 echo "assert latest rpm kernel = uname -r" >> $LOGFILE
         #assert "rpm -q kernel-xen | sort -n | tail -n 1 | cut -c 12-50| sed 's/\(.*\)..../\1/'"  $CURRENT_UNAME_KERNAL_VERSION
	 assert "uname -r | sed  's/\(.*\)......./\1/'"  $LATEST_RPM_KERNEL_VERSION
	fi
 
	new_test "## Verify latest kenerl is in /boot/grub/menu.1st ... "
	assert "cat /boot/grub/menu.lst | grep $LATEST_RPM_KERNEL_VERSION"

	new_test "## Verify operating system ... "
	assert "/bin/uname -o" GNU/Linux
	
        new_test "## Verify /etc/sysconfig/kernel ... "
	assert "ls /etc/sysconfig/kernel"
 
	new_test "## Verify /etc/sysconfig/kernel contains UPDATEDEFAULT ... "
  	assert "cat /etc/sysconfig/kernel | grep UPDATEDEFAULT=yes"
	
	new_test "## Verify /etc/sysconfig/kernel contains DEFAULTKERNEL ... "
  	assert "cat /etc/sysconfig/kernel | grep DEFAULTKERNEL=kernel"

}

function test_resize2fs()
{
	new_test "## Verify resize2fs ... "
	if [ $RHEL == 6 ] ; then
	 [ -b /dev/xvde1 ] && rc "resize2fs -p /dev/xvde1 15000M"
	 [ -b /dev/xvda1 ] && rc "resize2fs -p /dev/xvda1 15000M"
	fi
	if [ $RHEL == 5 ] ; then
	 rc "resize2fs -p /dev/sda1 15000M"
	fi
	sleep 10
	assert "df -h | grep 15G | wc -l " 1
}

function installTestKernel()
{
	new_test "## install custom kernel"
	#cat /proc/cpuinfo | grep nonstop_tsc >> $LOGFILE
	echo "yumlocalinstall -y /root/kernel/*" >> $LOGFILE
	rc "yum localinstall -y  /root/kernel/* --nogpgcheck"
	
	#cat /boot/grub/grub.conf > /boot/grub/menu.lst
	#/bin/sed -i -e 's/(hd0,0)/(hd0)/' /boot/grub/menu.lst
}

function test_grub()
{
	new_test "##test menu.lst ... "
	assert "file /boot/grub/menu.lst  | grep symbolic | wc -l" "1"
	assert "file /boot/grub/menu.lst  | grep grub.conf | wc -l" "1"
	assert "cat /boot/grub/grub.conf  | grep \"(hd0,0)\" | wc -l" "0"
}

function test_memory()
{
	new_test "##Verify memory match hwp ... "
	echo "cat /proc/meminfo | grep MemTotal: | awk '{print $2}'" >> $LOGFILE
	MEM=`cat /proc/meminfo | grep "MemTotal:" | awk '{print $2}'`
	echo "EXPECTED MINIMUM MEMORY = $MEM_HWP"
	echo "MEMORY FOUND = $MEM"
	if [[ $MEM -gt $MEM_HWP ]]; then
	 echo "FOUND MEMORY OF $MEM > hwp MEMORY of $MEM_HWP" >> $LOGFILE
	 assert "echo true"
	else
	 echo "FAILED!! FOUND MEMORY OF $MEM > hwp MEMORY of $MEM_HWP" >> $LOGFILE
	 assert "echo false" "1"
	fi	
}

function sos_report()
{
	echo "## Create a sosreport ... "
	echo "This may take 5 - 10 minutes"
	sosreport -a --batch --ticket-number=${BUGZILLA} 1>/dev/null
	echo ""
	#echo "Please attach the sosreport bz2 in file /tmp to https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"

}

function open_bugzilla()
{
	#echo "######### /etc/rc.local ########" >> $LOGFILE
	#cat /etc/rc.local >> $LOGFILE	
	#echo "######### /etc/rc.local ########" >> $LOGFILE

 	BUGZILLACOMMAND=$DIFFDIR/bugzilla-command
	new_test "## Open a bugzilla"
	echo ""
	echo "Logging into bugilla"
	echo ""
	$BUGZILLACOMMAND --bugzilla=https://bugzilla.redhat.com/xmlrpc.cgi --user=$BUG_USERNAME --password=$BUG_PASSWORD login
	if [ -z $BUG_NUM ]; then 
	 BUGZILLA=`$BUGZILLACOMMAND new  -p"Cloud Image Validation" -v"RHEL$RHELV" -a"$UNAMEI" -c"images" -l"initial bug opening" -s"$IMAGEID $RHELV $UNAMEI " | cut -b "2-8"`
	 echo ""
	 echo "new bug created: $BUGZILLA https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"
	 echo ""
	else
         BUGZILLA=$BUG_NUM
	 echo $BUGZILLA > /tmp/bugzilla
	fi
}

function bugzilla_comments()
{
	echo "Adding log file contents to bugzilla"
	split ${LOGFILE} -l 500 splitValid.log

 	for part in $(ls splitValid.log*);do
	 BUG_COMMENTS=`cat $part`
         $BUGZILLACOMMAND modify $BUGZILLA -l "${BUG_COMMENTS}"
	done
        #BUG_COMMENTS02=`tail -n $(expr $(cat ${LOGFILE} | wc -l ) / 3) ${LOGFILE}`
        #BUG_COMMENTS03=`tail -n $(expr $(cat ${LOGFILE} | wc -l ) / 3) ${LOGFILE}`
        #$BUGZILLACOMMAND modify $BUGZILLA -l "${BUG_COMMENTS01}"
        #$BUGZILLACOMMAND modify $BUGZILLA -l "${BUG_COMMENTS02}"
        #$BUGZILLACOMMAND modify $BUGZILLA -l "${BUG_COMMENTS03}"

	echo "Finished with the bugzilla https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"

}

function verify_bugzilla()
{
	echo "If no failures found move bug to verified"
	if [ $FAILURES == 0 ];then
          echo "MOVING BUG TO VERIFIED: test has $FAILURES failures"
	  $BUGZILLACOMMAND modify --status="VERIFIED" $BUGZILLA	
	else
	   echo "MOVING BUG TO ON_QA: test has $FAILURES failures"
	  $BUGZILLACOMMAND modify --status="ON_QA" $BUGZILLA	
	fi

}


function remove_bugzilla_rpms()
{
	echo ""
	echo "Removing epel-release and python-bugzilla"
	rpm -e epel-release python-bugzilla
        rpm -e gpg-pubkey-0608b895-4bd22942 gpg-pubkey-217521f6-45e8a532 	
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "Please attach the sosreport bz2 in file /tmp to https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

function setup_rc.local()
{
	echo "####################### cat of /etc/rc.local ##################" >> $LOGFILE
	echo "cd /root/valid/src" >> /etc/rc.local
	echo "./image_validation_postreboot.sh --imageID=${IMAGEID} --RHEL=$RHELV --full-yum-suite=no --skip-questions=yes --bugzilla-username=$BUG_USERNAME --bugzilla-password=$BUG_PASSWORD --bugzilla-num=$BUGZILLA --failures=$FAILURES --memory=$MEM_HWP >> /var/log/messages" >> /etc/rc.local
	cat /etc/rc.local >> $LOGFILE

	echo "####################### cat of /etc/rc.local ##################" >> $LOGFILE
}

function postReboot()
{
	echo  "###### TEST KERNEL AFTER REBOOT ####  " >> $LOGFILE
}



function show_failures()
{
	echo "" | $DLOG
        echo "## Summary ##" | $DLOG
	echo "FAILURES = ${FAILURES}" | $DLOG
	echo $TEST_FAILED >> $PWD/failed_tests
	FAILED=`cat $PWD/failed_tests`
	echo "FAILED TESTS = ${FAILED}" | $DLOG
	echo "LOG FILE = ${LOGFILE}" | $DLOG
        echo "## Summary ##" |  $DLOG
	echo "" | $DLOG
}

function im_exit()
{
	echo "" 
        echo "## Summary ##" 
	echo "FAILURES = ${FAILURES}" 
	echo "FAILED TESTS = ${FAILED}" 
	echo "LOG FILE = ${LOGFILE}" 
        echo "## Summary ##" 
	echo "" 
	exit ${FAILURES}
}
