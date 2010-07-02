#!/bin/bash

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
fi
if [ -e "$TESTSDA" ]; then
 DSKa=/dev/sda
 DSKb=/dev/sda
 DSKc=/dev/sda
fi
echo ""
#echo  "DSKa = $DSKa"
#echo  "DSKb = $DSKb"
#echo  "DSKc = $DSKc"
echo ""


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
 	RSLT=$1 2>>${LOGFILE}
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
         echo "PASS" | $DLOG
        elif [ -z $option ] && [ "$rc" == 0 ];then
         #echo "IN THIRD TEST" >>$LOGFILE
         echo "PASS" | $DLOG
        else
          echo "FAIL" | $DLOG
          echo ${RSLT} >>${LOGFILE}
          let FAILURES++
        fi
}



function test_selinux()
{
 	echo "SELINUX TESTS"
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
        file=/tmp/rpmqa
        echo "## Verify Package set, appropriate packages installed ... "
        if [ ${UNAMEI} == 'i386' ]; then
         /bin/rpm -qa --queryformat="%{NAME}\n" > ${file}.tmp 
        elif [ ${UNAMEI} == 'x86_64' ]; then
         /bin/rpm -qa --queryformat="%{NAME}.%{ARCH}\n" > ${file}.tmp  
        else
          echo "Do not recognize hardware platform: ${UNAMEI}"
          exit -1
        fi
        cat ${file}.tmp  | sort -f > ${file}
        new_test  "## Verify no missing packages ... "
        assert "/usr/bin/diff ${DIFF_DIR}/packages.${UNAMEI} ${file}"
}

function test_verify_rpms()
{
	file=/tmp/rpmqaV.txt
        new_test "## Verify RPMs ... " 
        /bin/rpm -qaV 2>> $LOGFILE | sort -f > ${file}
        assert "/usr/bin/diff -I /etc/yum.repos.d/redhat-.*-.*.repo ${DIFF_DIR}/rpmqaV.${UNAMEI} /tmp/rpmqaV.txt"
        
        new_test "## Verify Version 1 ... " 
        rc "/bin/cat /etc/redhat-release > /tmp/redhat-release.txt"
        assert "/usr/bin/diff ${DIFF_DIR}/redhat-release.txt /tmp/redhat-release.txt"
        
        new_test "## Verify Version 2 ... " 
        assert "/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2" ${VERSION}
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
        new_test "# Verify disks ... " 
	#NEED TO CHANGE
}

function test_disk_label()
{
        new_test "### Verify ${DSKa}1 label ... " 
	if [ "${PROVIDER}" == 'ec2' ]; then
 	 assert "/sbin/e2label ${DSKa}1" "/"
	fi
	if [ "${PROVIDER}" == 'ibm' ]; then
 	 assert "/sbin/e2label ${DSKa}1" "/boot"
	fi
	
	new_test "### Verify ${DSKa}1 filesystem ... "
	assert "/sbin/dumpe2fs ${DSKa}1"

	new_test "### Verify mnt label ... " 
	if [ ${UNAMEI} == 'i386' ]; then
	 assert "/sbin/e2label ${DSKa}2" "/"
	else
	 assert "/sbin/e2label ${DSKb}" "/"
	fi

	new_test "### Verify mnt filesystem ... "
	if [ ${UNAMEI} == 'i386' ]; then
	 assert "/sbin/dumpe2fs ${DSKa}2"
	else
	 assert "/sbin/dumpe2fs /dev/${DSKb}"
	fi

	#new_test "### Verify ${DSKa}3 label ... "
	#if [ ${UNAMEI} == 'i386' ]; then
 	# assert "/bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}'" "swap swap"
 	#elif [ ${UNAMEI} == 'x86_64' ]; then	
	# assert "/bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}'" ""
	#elif [ ${PROVIDER} == 'ibm' ];then
	# echo "no test"
	#fi

}

function test_swap_file()
{
	new_test "### Verify swap file ... "
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
#         let FAILURES++
#       fi
#}


function test_group()
{
        new_test "### Verify group file ... " 
	assert "/usr/bin/diff ${DIFF_DIR}/group.${PROVIDER}.${UNAMEI} /etc/group"
}

function test_passwd()
{
	new_test "### Verify new passwd file ... "
	assert "/usr/bin/diff ${DIFF_DIR}/passwd.${PROVIDER}.${UNAMEI} /etc/passwd"
}


function test_modprobe()
{
        new_test "### Verify new modprobe.conf file ... "
	assert "/usr/bin/diff ${DIFF_DIR}/modprobe.${PROVIDER}.txt /etc/modprobe.conf"
}

function test_mtab()
{
        new_test "### Verify new mtab file ... "
	assert "/usr/bin/diff ${DIFF_DIR}/mtab.${PROVIDER}.${UNAMEI} /etc/mtab"
}

function test_shells()
{
        new_test "### Verify new shells file ... " 
	assert "/usr/bin/diff ${DIFF_DIR}/shells.txt /etc/shells"
}

function test_repos()
{
	new_test "### test repo files"
	assert "ls /etc/yum.repos.d/ | wc -l " 5
	assert "ls /etc/yum.repos.d/redhat* | wc -l" 4
	assert "ls /etc/yum.repos.d/rhel* | wc -l" 1
}

function test_yum_plugin()
{
        new_test "## Verify disabled yum plugin ... "
	assert "grep ^enabled /etc/yum/pluginconf.d/rhnplugin.conf | grep -v '^#' | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq"
}

function test_gpg_checking()
{
        new_test "## Verify GPG checking ... " 
	assert "grep '^gpgcheck=1' /etc/yum.repos.d/redhat-${AZ}.repo | cut -d\= -f2 | sort -f | uniq"
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


function test_iptables()
{
        new_test "## Verify iptables ... "
	rc "/sbin/service iptables status > /tmp/iptables.txt"
	assert "/usr/bin/diff ${DIFF_DIR}/iptables.txt /tmp/iptables.txt"
}

function test_chkconfig()
{
        new_test "## Verify all of chkconfig ... "
	rc "/sbin/chkconfig --list > /tmp/chkconfig.txt"
	assert "/usr/bin/diff ${DIFF_DIR}/chkconfig.${PROVIDER}.${UNAMEI} /tmp/chkconfig.txt"
}


function test_syslog()
{
        new_test "## Verify syslog is on ... " 
	assert "/sbin/chkconfig --list syslog | grep 3:on" 
	assert "/sbin/chkconfig --list syslog | grep 5:on" 

	new_test "## Verify syslog config ... "
	assert "/usr/bin/diff ${DIFF_DIR}/syslog.conf /etc/syslog.conf"
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







function show_failures()
{
## Summary ##
echo "FAILURES = ${FAILURES}"
echo "LOG FILE = ${LOGFILE}"
exit ${FAILURES}
}

