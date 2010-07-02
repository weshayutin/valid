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


function test_selinux()
{
	echo -n "# Selinux tests ... " | $DLOG
	RSLT=$( /usr/sbin/getenforce )
	if [ ${RSLT} == 'Enforcing' ]; then
	  echo "PASS" | $DLOG
	else
	 echo "FAIL" | $DLOG
	 let FAILURES++
	fi
	
	echo -n "## Verify SELINUX enforcing ... " | $DLOG
	
	RSLT=$( grep ^SELINUX= /etc/sysconfig/selinux | cut -d\= -f2 )
	if [ "${RSLT}" == "enforcing" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "## Verify SELINUXTYPE targeted ... " | $DLOG
	
	RSLT=$( grep ^SELINUXTYPE= /etc/sysconfig/selinux | cut -d\= -f2 )
	if [ "${RSLT}" == "targeted" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "# Flip Selinux Permissive ... " | $DLOG
	RSLT=$( /usr/sbin/setenforce Permissive && /usr/sbin/getenforce )
	if [ ${RSLT} == 'Permissive' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "# Flip Selinux Enforcing ... " | $DLOG
	RSLT=$( /usr/sbin/setenforce Enforcing && /usr/sbin/getenforce )
	if [ ${RSLT} == 'Enforcing' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_package_set()
{
	echo  "# Verify Package set, appropriate packages installed ... " | $DLOG
	if [ ${UNAMEI} == 'i386' ]; then
	  /bin/rpm -qa --queryformat="%{NAME}\n" | sort -f > /tmp/rpmqa.i386
	elif [ ${UNAMEI} == 'x86_64' ]; then
	  /bin/rpm -qa --queryformat="%{NAME}.%{ARCH}\n" | sort -f > /tmp/rpmqa.x86_64
	else 
	  echo "Do not recognize hardware platform: ${UNAMEI}"
	  exit -1
	fi
	
	echo -n  "## Verify no missing packages ... " | $DLOG
	#echo  "PACKAGE FILE = ${DIFF_DIR}/packages.${UNAMEI}"
	RSLT=$( /usr/bin/comm -23 ${DIFF_DIR}/packages.${UNAMEI} /tmp/rpmqa.${UNAMEI} 2>> $LOGFILE ) 
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify no extra packages ... " | $DLOG
	
	RSLT=$( for i in $( /usr/bin/comm -13 ${DIFF_DIR}/packages.${UNAMEI} /tmp/rpmqa.${UNAMEI}  | grep -v ^gpg-pubkey | grep -v ^xulrunner | cut -d\. -f1); do /bin/rpm -q --whatrequires $i; done | grep '^no package requires ' 2>> $LOGFILE )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_gpg_keys()
{
	echo -n "## Verify imported GPG keys ... " | $DLOG
	
	/bin/rpm -qa gpg-pubkey* | sort -f > /tmp/gpg_keys.txt
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/gpg_keys.txt /tmp/gpg_keys.txt )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_verify_rpms()
{
	echo -n "## Verify RPMs ... " | $DLOG
	
	/bin/rpm -qaV 2>> $LOGFILE | sort -f > /tmp/rpmqaV.txt
	RSLT=$( /usr/bin/diff -I /etc/yum.repos.d/redhat-.*-.*.repo ${DIFF_DIR}/rpmqaV.${UNAMEI} /tmp/rpmqaV.txt 2>> $LOGFILE )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify Version 1 ... " | $DLOG
	
	/bin/cat /etc/redhat-release > /tmp/redhat-release.txt
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/redhat-release.txt /tmp/redhat-release.txt )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify Version 2 ... " | $DLOG
	
	RPMVERSION=$(/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2)
	if [ "${RPMVERSION}" == "${VERSION}" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "Found ${RPMVERSION} != Expected ${VERSION}"
	  let FAILURES++
	fi
}

function test_install_package() 
{
	echo -n "## install zsh ... " | $DLOG
	
	YUM=$(/usr/bin/yum -y install zsh)
	RSLT=$(/bin/rpm -q --queryformat '%{NAME}\n' zsh)
	if [ "${RSLT}" == "zsh" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "Found ${RSLT}"
	  echo "${YUM}"
	  let FAILURES++
	fi
	
	echo -n "## Verify package removal ... " | $DLOG
	
	/bin/rpm -e zsh
	RSLT=$(/bin/rpm -q zsh)
	if [ "${RSLT}" == "package zsh is not installed" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "Found ${RSLT}"
	  let FAILURES++
	fi
	
	echo -n "## Verify yum install of sysstat ... " | $DLOG
	
	YUM=$(/usr/bin/yum -y install sysstat)
	RSLT=$(/bin/rpm -q --queryformat '%{NAME}\n' sysstat)
	if [ "${RSLT}" == "sysstat" ]; then
	  /bin/rpm -e sysstat
	  RSLT=$(/bin/rpm -q sysstat)
	  if [ "${RSLT}" == "package sysstat is not installed" ]; then
	    echo "PASS" | $DLOG
	  else
	    echo "FAIL" | $DLOG
	    echo "Found ${RSLT}"
	    let FAILURES++
	  fi
	else
	  echo "FAIL" | $DLOG
	  echo "Found ${RSLT}"
	  echo "${YUM}"
	  let FAILURES++
	fi
}

function test_yum_update()
	{
	echo -n "## Verify yum update ... " | $DLOG
	
	/usr/bin/yum -y update
	RSLT=$( echo $? )
	if [ "${RSLT}" == "0" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "Return: ${RSLT}"
	  let FAILURES++
	fi
}


function test_parted()
{
	echo "# Verify disks ... " | $DLOG
	
	## Test 3.1 ##
	echo -n "## Verify devices and sizes ... " | $DLOG
	
	
	/sbin/parted --list | grep $DSKa | sort -f > /tmp/parted.${UNAMEI}
	RSLT=$( /usr/bin/diff $DIFF_DIR/parted.$PROVIDER.${UNAMEI} /tmp/parted.${UNAMEI} )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_disk_label()
{
	echo -n "### Verify ${DSKa}1 label ... " | $DLOG
	
	RSLT=$( /sbin/e2label ${DSKa}1 )
	if [ "${RSLT}" == '/' ] && [ "${PROVIDER}" == 'ec2' ]; then
	  echo "PASS" | $DLOG
	elif [ "${RSLT}" == '/boot' ] && [ "${PROVIDER}" == 'ibm' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi

	echo -n "### Verify ${DSKa}1 filesystem ... " | $DLOG
	
	/sbin/dumpe2fs ${DSKa}1 > /dev/null 2>&1
	RSLT=$( echo $? )
	if [ "${RSLT}" == 0 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "### Verify mnt label ... " | $DLOG
	
	if [ ${UNAMEI} == 'i386' ]; then
	  RSLT=$( /sbin/e2label ${DSKa}2  )
	else
	  RSLT=$( /sbin/e2label ${DSKb} )
	fi
	if [ "${RSLT}" == '/' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi

	echo -n "### Verify mnt filesystem ... " | $DLOG
	
	if [ ${UNAMEI} == 'i386' ]; then
	  /sbin/dumpe2fs ${DSKa}2 > /dev/null 2>&1
	else
	  /sbin/dumpe2fs /dev/${DSKb} > /dev/null 2>&1
	fi
	RSLT=$( echo $? )
	if [ "${RSLT}" == 0 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "### Verify ${DSKa}3 label ... " | $DLOG
	
	RSLT=$( /bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}' )
	if [ ${UNAMEI} == 'i386' -a "${RSLT}" == 'swap swap' ]; then
	  echo "PASS" | $DLOG
	elif [ ${UNAMEI} == 'x86_64' -a "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	elif [ ${PROVIDER} == 'ibm' ];then
	 echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_swap_file()
{
	if [ ${UNAMEI} == 'i386' ] && [ ${PROVIDER} != 'ibm' ]; then
		echo -n "### Verify ${DSKa}3 filesystem ... " | $DLOG
		
		/sbin/swapoff ${DSKa}3 && /sbin/swapon ${DSKa}3 > /dev/null 2>&1
		RSLT=$( echo $? )
		
		if [ "${RSLT}" == 0 ]; then
		  echo "PASS" | $DLOG
		elif [ ${PROVIDER} == 'ibm' ];then
		 echo "PASS" | $DLOG
		else
		  echo "FAIL" | $DLOG
		  ${LOGRESULT}
		  let FAILURES++
		fi
	fi
}


function test_bash_history()
{
	echo -n "## Verify no .bash_history file ... " | $DLOG
	
	if [ ! -f /root/.bash_history ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_system_id()
{
	echo -n "## Verify no systemid file ... " | $DLOG 
	
	if [ ! -f /etc/sysconfig/rhn/systemid ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_cloud-firstboot()
{
	echo -n "## Verify rh-cloud-firstboot is off ... " | $DLOG 
	
	if [ "${PROVIDER}" == 'ibm' ];then
	 RSLT=""
	else
	 RSLT=$( /sbin/chkconfig --list rh-cloud-firstboot | grep rh-cloud-firstboot | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
	fi
	if [ "${PROVIDER}" == 'ibm' ];then
	 echo "PASS" | $DLOG
	elif [ "${RSLT}" == 'rh-cloud-firstboot 0:off 1:off 2:off 3:off 4:off 5:off 6:off' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_nameserver()
{
echo -n "## Verify nameserver ... " | $DLOG

	RSLT=$( /usr/bin/dig clock.redhat.com 2>> $LOGFILE | grep 66.187.233.4  | wc -l)
	if [ "${RSLT}" == 1 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

#function test_securetty()
#{
#	echo -n "### Verify new securetty file ... " | $DLOG
#	
#	DATE=$( stat /etc/securetty | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
#	if [ -f /etc/securetty -a "${SYSDATE}" == "${DATE}" ]; then
#	  echo "PASS" | $DLOG
#	else
#	  echo "FAIL" | $DLOG
#	  echo "${SYSDATE} != ${DATE}"
#	  let FAILURES++
#	fi
#}

function test_group()
{
	echo -n "### Verify group file ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/group.${PROVIDER}.${UNAMEI} /etc/group )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_passwd()
{
	echo -n "### Verify new passwd file ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/passwd.${PROVIDER}.${UNAMEI} /etc/passwd )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
fi
}

function test_inittab()
{
	echo -n "### Verify new inittab file ... " | $DLOG
	
	DATE=$( stat /etc/inittab | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
	if [ -f /etc/inittab -a "${SYSDATE}" == "${DATE}" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "${SYSDATE} != ${DATE}"
	  let FAILURES++
	fi
}

function test_modprobe()
{
	echo -n "### Verify new modprobe.conf file ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/modprobe.${PROVIDER}.txt /etc/modprobe.conf )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}


function test_mtab()
{
	echo -n "### Verify new mtab file ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/mtab.${PROVIDER}.${UNAMEI} /etc/mtab )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_shells()
{
	echo -n "### Verify new shells file ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/shells.txt /etc/shells )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_repos()
{
	echo -n "## Verify new redhat repo file ... " | $DLOG
	
	AZ=$( wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone | cut -d\- -f1,2 )
	DATE=$( stat /etc/yum.repos.d/redhat-${AZ}.repo | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
	if [ -f /etc/yum.repos.d/redhat-${AZ}.repo -a "${SYSDATE}" == "${DATE}" ]; then
	  echo "PASS" | $DLOG
	elif [ ${PROVIDER} == 'ibm' ];then
	 echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo "${SYSDATE} != ${DATE}"
	  let FAILURES++
	fi

	echo -n "## Verify disabled redhat repo files ... " | $DLOG
	
	RSLT=$( grep ^enabled /etc/yum.repos.d/r*.repo | grep -v /etc/yum.repos.d/redhat-${AZ}.repo: | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq )
	if [ "${RSLT}" == 0 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_yum_plugin()
{
	echo -n "## Verify disabled yum plugin ... " | $DLOG
	
	RSLT=$( grep ^enabled /etc/yum/pluginconf.d/rhnplugin.conf | grep -v '^#' | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq )
	if [ "${RSLT}" == 0 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_gpg_checking()
{
	echo -n "## Verify GPG checking ... " | $DLOG
	
	RSLT=$( grep '^gpgcheck=1' /etc/yum.repos.d/redhat-${AZ}.repo | cut -d\= -f2 | sort -f | uniq )
	if [ "${RSLT}" == 1 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_hostname()
{
	echo -n "## Verify hostname ... " | $DLOG
	
	RSLT=$( grep ^HOSTNAME= /etc/sysconfig/network | cut -d\= -f2 )
	if [ "${RSLT}" == $( /bin/hostname ) ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_IPv6()
{
	echo -n "## Verify IPv6 disabled ... " | $DLOG
	
	RSLT=$( grep ^NETWORKING_IPV6= /etc/sysconfig/network | cut -d\= -f2 )
	if [ "${RSLT}" == "no" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}


function test_networking()
{
	echo -n "## Verify networking ... " | $DLOG
	
	RSLT=$( grep ^NETWORKING= /etc/sysconfig/network | cut -d\= -f2 )
	if [ "${RSLT}" == "yes" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "## Verify device ... " | $DLOG
	
	RSLT=$( grep ^DEVICE= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
	if [ "${RSLT}" == "eth0" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "## Verify bootproto ... " | $DLOG
	
	RSLT=$( grep ^BOOTPROTO= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
	if [ "${RSLT}" == "dhcp" ]; then
	  echo "PASS" | $DLOG
	elif [ ${PROVIDER} == 'ibm' ] && [ "${RSLT}" == "static" ];then
	 echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
	
	echo -n "## Verify onboot ... " | $DLOG
	
	RSLT=$( grep ^ONBOOT= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
	if [ "${RSLT}" == "on" ]; then
	  echo "PASS" | $DLOG
	elif [ ${PROVIDER} == 'ibm' ] && [ "${RSLT}" == "yes" ];then
	 echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  let FAILURES++
	fi
}

function test_iptables()
{
	echo -n "## Verify iptables ... " | $DLOG
	
	/sbin/service iptables status > /tmp/iptables.txt
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/iptables.txt /tmp/iptables.txt )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_sshd()
{
	echo -n "## Verify sshd is on ... " | $DLOG
	
	RSLT=$( /sbin/chkconfig --list sshd | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
	if [ "${RSLT}" == 'sshd 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_chkconfig()
{
	echo -n "## Verify all of chkconfig ... " | $DLOG
	
	/sbin/chkconfig --list > /tmp/chkconfig.txt
	DIFF=$( /usr/bin/diff ${DIFF_DIR}/chkconfig.${PROVIDER}.${UNAMEI} /tmp/chkconfig.txt > /tmp/chkconfig.results )
	RSLT=$( /bin/cat /tmp/chkconfig.results | wc -l )
	if [ "${RSLT}" == 0 ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  echo ${DIFF} &>> $LOGFILE
	  let FAILURES++
	fi
}

function test_syslog()
{
	echo -n "## Verify syslog is on ... " | $DLOG
	
	RSLT=$( /sbin/chkconfig --list syslog | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
	if [ "${RSLT}" == 'syslog 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify syslog config ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/syslog.conf /etc/syslog.conf )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_auditd()
{
	echo -n "## Verify auditd is on ... " | $DLOG
	
	RSLT=$( /sbin/chkconfig --list auditd | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
	if [ "${RSLT}" == 'auditd 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify audit.rules ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/audit.rules /etc/audit/audit.rules )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify auditd.conf ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/auditd.conf /etc/audit/auditd.conf )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify auditd sysconfig ... " | $DLOG
	
	RSLT=$( /usr/bin/diff ${DIFF_DIR}/auditd /etc/sysconfig/auditd )
	if [ "${RSLT}" == '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}

function test_uname()
{
	echo -n "## Verify kernel name ... " | $DLOG
	
	RSLT=$( /bin/uname -s )
	if [ "${RSLT}" == 'Linux' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify network node hostname ... " | $DLOG
	
	RSLT=$( /bin/uname -n )
	if [ "${RSLT}" == ${HOSTNAME} ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify kernel release ... " | $DLOG
	
	RSLT=$( /bin/uname -r | sed -e 's/xen$//g' )
	if [ "${RSLT}" == "$(rpm -qa kernel\* --queryformat="%{VERSION}-%{RELEASE}\n" | sort -f | uniq)" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify kernel version ... " | $DLOG
	
	RSLT=$( /bin/uname -v )
	if [ "${RSLT}" != '' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify machine hardware name ... " | $DLOG
	
	RSLT=$( /bin/uname -m )
	if [ ${UNAMEI} == 'i386' ]; then
	  UNAMEM=i686
	else
	  UNAMEM=${RSLT}
	fi 
	if [ "${RSLT}" == "${UNAMEM}" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  fi
	
	echo -n "## Verify processor type ... " | $DLOG
	
	RSLT=$( /bin/uname -p )
	if [ ${UNAMEI} == 'i686' ]; then
	  UNAMEP=athlon
	else
	  UNAMEP=${RSLT}
	fi 
	if [ "${RSLT}" == "${UNAMEP}" ]; then
	  echo "PASS" | $DLOG
	elif [ "${RSLT}" == 'i686' ] && [ ${PROVIDER} == 'ibm' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify hardware platform ... " | $DLOG
	
	RSLT=$( /bin/uname -i )
	if [ "${RSLT}" == "${UNAMEI}" ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
	
	echo -n "## Verify operating system ... " | $DLOG
	
	RSLT=$( /bin/uname -o )
	if [ "${RSLT}" == 'GNU/Linux' ]; then
	  echo "PASS" | $DLOG
	else
	  echo "FAIL" | $DLOG
	  ${LOGRESULT}
	  let FAILURES++
	fi
}


function show_failures()
{
## Summary ##
echo "FAILURES = ${FAILURES}"
exit ${FAILURES}
}



  

















