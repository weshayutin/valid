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

SYSDATE=$( stat /etc/sysconfig/hwconf | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
UNAMEI=$( /bin/uname -i )
#UNAMEP=$( /bin/uname -p )
#UNAMEM=$( /bin/uname -m )
#HOSTNAME=$( /bin/hostname )
TESTHDA="/dev/hda"
TESTSDA="/dev/sda1"
if [ -e "$TESTHDA" ]; then
 DSKa=/dev/hda
 DSKb=/dev/hdb
 DSKc=/dev/hdc
ilif [  "$UNAMEI" == "i386" ] && [ "$PROVIDER" == "ec2"  ]; then
 DSKa=/dev/sda
 DSKb=/dev/sda
 DSKc=/dev/sda
ilif [  "$UNAMEI" == "x86_64" ] && [ "$PROVIDER" == "ec2"  ]; then
 DSKa=/dev/sda
fi


echo ""
#echo  "DSKa = $DSKa"
#echo  "DSKb = $DSKb"
#echo  "DSKc = $DSKc"
echo ""

txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtrst=$(tput sgr0)       # Text reset


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

#runs a basic command and redirects stdout to file $2
function rc_outFile()
{
	echo "COMMAND: $1 $2" >>$LOGFILE
 	$1 2>>${LOGFILE} 1> $2 
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
        rc "comm -23 ${DIFF_DIR}/packages ${file}"
        comm -23 ${DIFF_DIR}/packages ${file} > /tmp/package_diff
	cat /tmp/package_diff >>$LOGFILE
	assert "cat /tmp/package_diff | wc -l" 1
	echo "Known sorting error on package=fonts-KOI8-R" >>$LOGFILE
}

function test_verify_rpms()
{
	file=/tmp/rpmqaV.txt
        new_test "## Verify RPMs ... " 
        /bin/rpm -Va --nomtime --nosize --nomd5 2>> $LOGFILE | sort -f > ${file}
	cat $file >> $LOGFILE
	cat ${DIFF_DIR}/rpmVerifyTable >> $LOGFILE
        assert "cat ${file} | wc -l" "2"
	
        
        new_test "## Verify Version 1 ... " 
        assert "/bin/cat /etc/redhat-release" "Red Hat Enterprise Linux Server release 5.5 (Tikanga)" # to-do, pass this in
        
        new_test "## Verify Version 2 ... " 
        assert "/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2" "5.5" # to-do, pass this in
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

function test_parted()
{
        new_test "## Verify disks ... " 
	assert "/sbin/parted --list | grep ${DSKa}1" "Disk /dev/sda1: 4096MB" # to-do, pass in the command and answer
	if [  "$UNAMEI" == "i386" ] && [ "$PROVIDER" == "ec2"  ]; then
	 assert "/sbin/parted --list | grep ${DSKa}2" "Disk /dev/sda2: 160GB" # to-do, pass in the command and answer
	 assert "/sbin/parted --list | grep ${DSKa}3" "Disk /dev/sda3: 940MB" # to-do, pass in the command and answer
	fi
}

function test_disk_label()
{
        new_test "## Verify disk labels ... " 
	if [ "${PROVIDER}" == 'ec2' ]; then
	 rc "cat /etc/fstab | grep /dev/sda1"
 	 assert "/sbin/e2label ${DSKa}1" "/"
	elif [  "$UNAMEI" == "i386" ] && [ "$PROVIDER" == "ec2"  ]; then
 	 assert "/sbin/e2label ${DSKa}2" "/mnt"
	fi
	if [ "${PROVIDER}" == 'ibm' ]; then
 	 assert "/sbin/e2label ${DSKa}1" "/boot"
	fi
	
	new_test "### Verify disk filesystem ... "
	assert "/sbin/dumpe2fs ${DSKa}1"
	
	# to-do fix for ibm
	#new_test "## Verify mnt filesystem ... "
	#if [ ${PROVIDER} == 'ec2' ]; then
	# assert "/sbin/dumpe2fs ${DSKb}"
	#else
	# assert "/sbin/dumpe2fs /dev/${DSKb}"
	#fi

	#new_test "### Verify ${DSKa}3 label ... "
	#if [ ${UNAMEI} == 'i386' ]; then
 	# assert "/bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}'" "swap swap"
 	#elif [ ${UNAMEI} == 'x86_64' ]; then	
	# assert "/bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}'" ""
	#elif [ ${PROVIDER} == 'ibm' ];then
	# echo "no test"
	#fi

}

function test_bash_history()
{
	new_test "## Verify bash_history ... "
	assert "cat ~/.bash_history | wc -l " 0 
}

function test_swap_file()
{
	new_test "## Verify swap file ... "
	if [ "${PROVIDER}" == 'ec2' ]; then
	 assert "/sbin/swapoff ${DSKa}3 && /sbin/swapon ${DSKa}3"
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
        new_test "## Verify rh-cloud-firstboot is off ... "
	assert "chkconfig --list | grep rh-cloud | grep -v on"
}

function test_nameserver()
{
	new_test "## Verify nameserver ... "
	assert "/usr/bin/dig clock.redhat.com 2>> $LOGFILE | grep 66.187.233.4  | wc -l"
}


#function test_securetty()
#{
#       echo -n "### Verify new securetty file ... " | $DLOG
#       
#       DATE=$( stat /etc/securetty | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
#       if [ -f /etc/securetty -a "${SYSDATE}" == "${DATE}" ]; then
#         echo "PASS" | $DLOG
#       else
#         echo "FAIL" | $DLOG
#         echo "${SYSDATE} != ${DATE}"
#       fi
#}


function test_group()
{
        new_test "## Verify group file ... " 
	assert "cat /etc/group | grep root:x:0" "root:x:0:root"
	assert "cat /etc/group | grep bin:x:1" "bin:x:1:root,bin,daemon"
	assert "cat /etc/group | grep daemon:x:2" "daemon:x:2:root,bin,daemon"
	assert "cat /etc/group | grep nobody:x:99" "nobody:x:99:"
	rc "useradd test_user"
	assert "cat /etc/group | grep test_user" "test_user:x:500:"
	
}

function test_passwd()
{
	new_test "## Verify new passwd file ... "
	assert "cat /etc/passwd | grep root:x:0" "root:x:0:0:root:/root:/bin/bash"
	assert "cat /etc/passwd | grep nobody:x:99" "nobody:x:99:99:Nobody:/:/sbin/nologin"
	assert "cat /etc/passwd | grep sshd" "sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin"
}


function test_modprobe()
{
        new_test "## Verify new modprobe.conf file ... "
	assert "cat /etc/modprobe.conf" "alias eth0 xennet"
}

function test_inittab()
{
	new_test "## Verify inittab ... " 
	assert "cat /etc/inittab | grep id:" "id:3:initdefault:"
	assert "cat /etc/inittab | grep si:" "si::sysinit:/etc/rc.d/rc.sysinit"

}

function test_mtab()
{
        new_test "## Verify new mtab file ... "
	assert "cat /etc/mtab | grep ${DSKa}1" "/dev/sda1 / ext3 rw 0 0"
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
	assert "rpm -qa gpg-pubkey* | tail -n 1" "gpg-pubkey-37017186-45761324"
	assert "rpm -qa gpg-pubkey* | tail -n 3 | grep 2fa6" "gpg-pubkey-2fa658e0-45700c69"
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
	rc "/sbin/service iptables status > /tmp/iptables.txt"
	assert "/usr/bin/diff ${DIFF_DIR}/iptables.txt /tmp/iptables.txt"
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
}

function test_auditd()
{
        new_test "## Verify auditd is on ... "
	assert "/sbin/chkconfig --list auditd | grep 3:on"
        assert "/sbin/chkconfig --list auditd | grep 5:on"

	new_test "## Verify audit.rules ... "
	assert "/usr/bin/diff ${DIFF_DIR}/audit.rules /etc/audit/audit.rules"

	new_test "## Verify auditd.conf ... "
	assert "/usr/bin/diff ${DIFF_DIR}/auditd.conf /etc/audit/auditd.conf"

	new_test "## Verify auditd sysconfig ... "
	assert "/usr/bin/diff ${DIFF_DIR}/auditd /etc/sysconfig/auditd"
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
	sosreport -a --batch --ticket-number=${BUGZILLA}
	echo ""
	echo "Please attach the sosreport bz2 file to https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"

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
	BUG_COMMENTS=`cat ${LOGFILE}` 
        bugzilla modify $BUGZILLA -l "${BUG_COMMENTS}"
	echo "Finished with the bugzilla https://bugzilla.redhat.com/show_bug.cgi?id=$BUGZILLA"

}

function remove_bugzilla_rpms()
{
	echo ""
	echo "Removing epel-release and python-bugzilla"
	rpm -e epel-release python-bugzilla
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
