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
LOGFILE=$PWD/validate.log
DLOG=" tee -a ${LOGFILE} " #Display and log output
cat /dev/null > $LOGFILE
RSLT=""
LOGRESULT="echo ${RSLT} 1>>$LOGFILE 2>>$LOGFILE"
DIFFDIR=$PWD
SYSDATE=$( stat /etc/sysconfig/hwconf | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
UNAMEI=$( /bin/uname -i )

echo ""
echo ""

txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtrst=$(tput sgr0)       # Text reset

### Begin:  Create a list of partitions
rm -Rf disk_partitions
rm -Rf swap_partitions
parted -l  | grep Disk | awk '{print $2}' > tmp1_partitions
for i in `cat tmp1_partitions`;do echo $i | sed '$s/.$//' >> tmp2_partitions;done
for part in `cat tmp2_partitions`;do
   cat /etc/fstab | grep $part | grep swap 2>&1 > /dev/null
   rc=$?
   if [ "$rc" == "1" ]
      then
      echo "$part" >> disk_partitions
   else
      echo "$part" >> swap_partitions
   fi
done
rm -Rf tmp1_partitions tmp2_partitions
### End:  Create a list of partitions

echo "IMAGE ID= ${IMAGEID}" >> $LOGFILE

function new_test()
{
	echo -n $1
	echo "######################################################################################" >> $LOGFILE
	echo "# NEW TEST: $1" >> $LOGFILE
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
        echo "COMMAND:  $1"  >>$LOGFILE
        RSLT=`eval $cmd 2>>$LOGFILE`
        rc=$?
        echo "RESULT: $RSLT " >>$LOGFILE
        echo "EXPECTED RESULT: $option " >>$LOGFILE
        echo "RETURN CODE: $rc" >>$LOGFILE

        if [ "$RSLT" == "$option" ] && [ "$option" != "" ];then
         #echo "IN SECOND TEST" >>$LOGFILE
         echo "${txtgrn}PASS${txtrst}" 
         echo "PASS" >> $LOGFILE
        elif [ -z $option ] && [ "$rc" == 0 ];then
         #echo "IN THIRD TEST" >>$LOGFILE
         echo "${txtgrn}PASS${txtrst}" 
         echo "PASS" >> $LOGFILE
        else
         echo "${txtred}FAIL${txtrst}" 
         echo "FAIL" >>  $LOGFILE
          echo ${RSLT} >>${LOGFILE}
          let FAILURES++
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
	echo "cat /etc/fstab | grep $part | awk '{ print $3 }'" >> $LOGFILE
	result=`cat /etc/fstab | grep $part | awk '{ print $3 }'`
	 assert "echo $result" ext3
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
        rc "comm -23 packages ${file}"
        comm -23 packages ${file} > /tmp/package_diff
	cat /tmp/package_diff >>$LOGFILE
	assert "cat /tmp/package_diff | wc -l" 1
	echo "Known sorting error on package=fonts-KOI8-R" >>$LOGFILE
}

function test_verify_rpms()
{
	file=/tmp/rpmqaV.txt
        new_test "## Verify RPMs ... " 
        /bin/rpm -Va --nomtime --nosize --nomd5 2>> $LOGFILE | sort -fu > ${file}
	cat $file >> $LOGFILE
	cat rpmVerifyTable >> $LOGFILE
        assert "cat ${file} | wc -l" "2"
	
        new_test "## Verify Version 1 ... " 
        assert "/bin/cat /etc/redhat-release" "Red Hat Enterprise Linux Server release 5.5 (Tikanga)" # to-do, pass this in
        
        new_test "## Verify Version 2 ... " 
        assert "/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2" "5.5" # to-do, pass this in

	new_test "## Verify packager ... "
        file=/tmp/Packager
        `cat /dev/null > $file`
        echo "for x in $file ;do echo -n $x >> $file; rpm -qi $x | grep Packager >> $file;done" >>$LOGFILE
        for x in $(cat /tmp/rpmqa);do
         echo -n $x >>$file
         rpm -qi $x | grep Packager >>$file
        done
        assert "cat $file | grep -v 'Red Hat, Inc.' | wc -l" 0
        cat $file | grep -v 'Red Hat, Inc.' >>$LOGFILE	
}

function test_install_package()
{
        new_test "## install zsh ... "
        rc "/usr/bin/yum -y install zsh"
        assert "/bin/rpm -q --queryformat '%{NAME}\n' zsh" zsh

        new_test "## Verify package removal ... "
        rc "/bin/rpm -e zsh"
        assert "/bin/rpm -q zsh" "package zsh is not installed"

}

function test_yum_update()
{
        new_test "## Verify yum update ... " 
	assert "/usr/bin/yum -y update"
}

function test_bash_history()
{
	new_test "## Verify bash_history ... "
	assert "cat ~/.bash_history | wc -l " 0 
}


function test_install_package()
{
        new_test "## install zsh ... "
        rc "/usr/bin/yum -y install zsh"
        assert "/bin/rpm -q --queryformat '%{NAME}\n' zsh" zsh

        new_test "## Verify package removal ... "
        rc "/bin/rpm -e zsh"
        assert "/bin/rpm -q zsh" "package zsh is not installed"

}

function test_yum_update()
{
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
	new_test "## Verify swap file ... "
	swap=`cat swap_partitions`
	assert "/sbin/swapoff $swap && /sbin/swapon $swap"
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
        new_test "## Verify rh-cloud-firstboot is off ... "
	assert "chkconfig --list | grep rh-cloud | grep -v on"
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
	new_test "## Verify inittab ... " 
	assert "cat /etc/inittab | grep id:" "id:3:initdefault:"
	assert "cat /etc/inittab | grep si:" "si::sysinit:/etc/rc.d/rc.sysinit"

}


function test_shells()
{
        new_test "## Verify new shells file ... " 
	assert "cat /etc/shells | grep bash" "/bin/bash"
	assert "cat /etc/shells | grep ksh" "/bin/ksh"
	assert "cat /etc/shells | grep nologin" "/sbin/nologin"
}

function test_repos()
{
	new_test "## test repo files ... "
	assert "ls /etc/yum.repos.d/ | wc -l " 5
	assert "ls /etc/yum.repos.d/redhat* | wc -l" 4
	assert "ls /etc/yum.repos.d/rhel* | wc -l" 1
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
	assert "rpm -qa gpg-pubkey* | wc -l " 2

	new_test "## Verify GPG RPMS ... "
	assert "rpm -qa gpg-pubkey* | sort -f | tail -n 1" "gpg-pubkey-37017186-45761324"
	assert "rpm -qa gpg-pubkey* |  grep 2fa6" "gpg-pubkey-2fa658e0-45700c69"
}

function test_IPv6()
{
        new_test "## Verify IPv6 disabled ... "
	assert "grep ^NETWORKING_IPV6= /etc/sysconfig/network | cut -d\= -f2"
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
        new_test "## Verify iptables ... "
        rc_outFile "/etc/init.d/iptables status | grep REJECT"
	assert "/etc/init.d/iptables status | grep :22 | grep ACCEPT | wc -l " "1" 
	assert "/etc/init.d/iptables status | grep :80 | grep ACCEPT | wc -l " "1" 
	assert "/etc/init.d/iptables status | grep :443 | grep ACCEPT | wc -l " "1" 
	assert "/etc/init.d/iptables status | grep REJECT | grep all | grep 0.0.0.0/0 | grep icmp-host-prohibited |  wc -l " "1" 
}

function test_chkconfig()
{
        new_test "## Verify  chkconfig ... "
	assert "chkconfig --list | grep crond | cut -f 5" "3:on"
	assert "chkconfig --list | grep  iptables | cut -f 5" "3:on"
	assert "chkconfig --list | grep yum-updatesd | cut -f 5" "3:on"
}


function test_syslog()
{
        new_test "## Verify rsyslog is on ... " 
	assert "chkconfig --list | grep rsyslog | cut -f 5" "3:on"

	new_test "## Verify rsyslog config ... "
	assert "md5sum /etc/rsyslog.conf | cut -f 1 -d  \" \"" "bd4e328df4b59d41979ef7202a05e074"
	
    	#deprecated 
	#new_test "## Verify syslog config ... "
	#assert "md5sum /etc/syslog.conf | cut -f 1 -d  \" \"" "213124ef612a63ae63d01e237e103488"
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

	new_test "## Verify kernel release ... "
	rt=`rpm -qa kernel\* --queryformat="%{VERSION}-%{RELEASE}\n" | sort -f | uniq`
	assert "/bin/uname -r | sed -e 's/xen$//g'" $rt

	new_test "## Verify operating system ... "
	assert "/bin/uname -o" GNU/Linux

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
	echo "Installing packages needed to open a bug report. The packages will be removed at the end of the test"
	echo " "
	rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-3.noarch.rpm
	yum -y install python-bugzilla
	new_test "## Open a bugzilla"
	echo ""
	echo "Please enter your bugzilla username and password"
	echo ""
	bugzilla login
	BUGZILLA=`bugzilla new  -p"Cloud Image Validation" -v"1.0" -c"images" -l"initial bug opening" -s"$PROVIDER $USER $DESC" | cut -b "2-8"`
	echo ""
	echo "new bug created: $BUGZILLA https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"
	echo ""
	echo "Adding log file contents to bugzilla"
	BUG_COMMENTS01=`head -n $(expr $(cat ${LOGFILE} | wc -l ) / 2) ${LOGFILE}`
        BUG_COMMENTS02=`tail -n $(expr $(cat ${LOGFILE} | wc -l ) / 2) ${LOGFILE}`
        bugzilla modify $BUGZILLA -l "${BUG_COMMENTS01}"
        bugzilla modify $BUGZILLA -l "${BUG_COMMENTS02}"

	echo "Finished with the bugzilla https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"
}


function remove_bugzilla_rpms()
{
	echo ""
	echo "Removing epel-release and python-bugzilla"
	rpm -e epel-release python-bugzilla
        rpm -e gpg-pubkey-217521f6-45e8a532	
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "Please attach the sosreport bz2 in file /tmp to https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}



function show_failures()
{
	echo "" | $DLOG
        echo "## Summary ##" | $DLOG
	echo "FAILURES = ${FAILURES}" | $DLOG
	echo "LOG FILE = ${LOGFILE}" | $DLOG
        echo "## Summary ##" |  $DLOG
	echo "" | $DLOG
}

function im_exit()
{
	echo "" 
        echo "## Summary ##" 
	echo "FAILURES = ${FAILURES}" 
	echo "LOG FILE = ${LOGFILE}" 
        echo "## Summary ##" 
	echo "" 
	exit ${FAILURES}
}
