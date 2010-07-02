#! /bin/bash

VERSION=5.5
FAILURES=0

#cli
for i in $*
 do
 case $i in
      --provider=*)
         PROVIDER="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --diff_directory=*)
         DIFF_DIR="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         echo "DIFF_DIR=${DIFF_DIR}"
         ;;
      *)
         # unknown option 
           echo " unknown option " 
           echo ""
           echo "Available options are:"
           echo "--provider         The cloude provider: ibm,ec2"
           echo "--diff_directory   The directory where the authoritive files exist"
           exit 1
           ;;
 esac
done

echo -n "DIFF_DIR"=${DIFF_DIR}

SYSDATE=$( stat /etc/sysconfig/hwconf | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )

## Test 1.0 ##
echo -n "# Selinux enabled ... "
RSLT=$( /usr/sbin/getenforce )
if [ ${RSLT} == 'Enforcing' ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 1.1 ##
echo -n "## Verify SELINUX enforcing ... "

RSLT=$( grep ^SELINUX= /etc/sysconfig/selinux | cut -d\= -f2 )
if [ "${RSLT}" == "enforcing" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 1.2 ##
echo -n "## Verify SELINUXTYPE targeted ... "

RSLT=$( grep ^SELINUXTYPE= /etc/sysconfig/selinux | cut -d\= -f2 )
if [ "${RSLT}" == "targeted" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 1.3 ##
echo -n "# Flip Selinux Permissive ... "
RSLT=$( /usr/sbin/setenforce Permissive && /usr/sbin/getenforce )
if [ ${RSLT} == 'Permissive' ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 1.4 ##
echo -n "# Flip Selinux Enforcing ... "
RSLT=$( /usr/sbin/setenforce Enforcing && /usr/sbin/getenforce )
if [ ${RSLT} == 'Enforcing' ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 2.0 ##
echo -n  "# Verify Package set, appropriate packages installed ... "
UNAMEI=$( /bin/uname -i )
if [ ${UNAMEI} == 'i386' ]; then
  /bin/rpm -qa --queryformat="%{NAME}\n" | sort -f > /tmp/rpmqa.i386
elif [ ${UNAMEI} == 'x86_64' ]; then
  /bin/rpm -qa --queryformat="%{NAME}.%{ARCH}\n" | sort -f > /tmp/rpmqa.x86_64
else 
  echo "Do not recognize hardware platform: ${UNAMEI}"
  exit -1
fi

## Test 2.1 ##
echo -n  "## Verify no missing packages ... "
#echo  "PACKAGE FILE = ${DIFF_DIR}/packages.${UNAMEI}"
RSLT=$( /usr/bin/comm -23 ${DIFF_DIR}/packages.${UNAMEI} /tmp/rpmqa.${UNAMEI} )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 2.2 ##
echo -n "## Verify no extra packages ... "

RSLT=$( for i in $( /usr/bin/comm -13 ${DIFF_DIR}/packages.${UNAMEI} /tmp/rpmqa.${UNAMEI} | grep -v ^gpg-pubkey | grep -v ^xulrunner | cut -d\. -f1); do /bin/rpm -q --whatrequires $i; done | grep '^no package requires ')
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 2.3 ##
echo -n "## Verify imported GPG keys ... "

/bin/rpm -qa gpg-pubkey* | sort -f > /tmp/gpg_keys.txt
RSLT=$( /usr/bin/diff ${DIFF_DIR}/gpg_keys.txt /tmp/gpg_keys.txt )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 2.4 ##
#echo -n "## Verify RPMs ... "

#/bin/rpm -qaV | sort -f > /tmp/rpmqaV.txt
#RSLT=$( /usr/bin/diff -I /etc/yum.repos.d/redhat-.*-.*.repo ${DIFF_DIR}/rpmqaV.${UNAMEI} /tmp/rpmqaV.txt )
#if [ "${RSLT}" == '' ]; then
#  echo "PASS"
#else
#  echo "FAIL"
#  echo ${RSLT}
#  let FAILURES++
#fi

## Test 2.5 ##
echo -n "## Verify Version 1 ... "

/bin/cat /etc/redhat-release > /tmp/redhat-release.txt
RSLT=$( /usr/bin/diff ${DIFF_DIR}/redhat-release.txt /tmp/redhat-release.txt )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 2.6 ##
echo -n "## Verify Version 2 ... "

RPMVERSION=$(/bin/rpm -q --queryformat '%{RELEASE}\n' redhat-release | cut -d. -f1,2)
if [ "${RPMVERSION}" == "${VERSION}" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo "Found ${RPMVERSION} != Expected ${VERSION}"
  let FAILURES++
fi

## Test 2.7 ##
echo -n "## Verify no zsh ... "

YUM=$(/usr/bin/yum -y install zsh)
RSLT=$(/bin/rpm -q --queryformat '%{NAME}\n' zsh)
if [ "${RSLT}" == "zsh" ]; then
  echo "PASS"
  /bin/rpm -e zsh
else
  echo "FAIL"
  echo "Found ${RSLT}"
  echo "${YUM}"
  let FAILURES++
fi

## Test 2.8 ##
echo -n "## Verify yum install of zsh ... "

YUM=
RSLT=$(/bin/rpm -q zsh)
if [ "${RSLT}" == "package zsh is not installed" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo "Found ${RSLT}"
  let FAILURES++
fi

## Test 2.9 ##
echo -n "## Verify yum install of sysstat ... "

YUM=$(/usr/bin/yum -y install sysstat)
RSLT=$(/bin/rpm -q --queryformat '%{NAME}\n' sysstat)
if [ "${RSLT}" == "sysstat" ]; then
  /bin/rpm -e sysstat
  RSLT=$(/bin/rpm -q sysstat)
  if [ "${RSLT}" == "package sysstat is not installed" ]; then
    echo "PASS"
  else
    echo "FAIL"
    echo "Found ${RSLT}"
    let FAILURES++
  fi
else
  echo "FAIL"
  echo "Found ${RSLT}"
  echo "${YUM}"
  let FAILURES++
fi

## Test 3.0 ##
echo "# Verify disks ... "

## Test 3.1 ##
echo -n "## Verify devices and sizes ... "

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
echo  "DSKa = $DSKa"
echo  "DSKb = $DSKb"
echo  "DSKc = $DSKc"
echo ""

/sbin/parted --list | grep $DSKa | sort -f > /tmp/parted.${UNAMEI}
RSLT=$( /usr/bin/diff $DIFF_DIR/parted.$PROVIDER.${UNAMEI} /tmp/parted.${UNAMEI} )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 2.10 ##
echo -n "## Verify yum update ... "

/usr/bin/yum -y update
RSLT=$( echo $? )
if [ "${RSLT}" == "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo "Return: ${RSLT}"
  let FAILURES++
fi

## Test 3.2.1 ##
echo -n "### Verify ${DSKa}1 label ... "

RSLT=$( /sbin/e2label ${DSKa}1 )
if [ "${RSLT}" == '/' ] && [ "${PROVIDER}" == 'ec2' ]; then
  echo "PASS"
elif [ "${RSLT}" == '/boot' ] && [ "${PROVIDER}" == 'ibm' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 3.2.2 ##
echo -n "### Verify ${DSKa}1 filesystem ... "

/sbin/dumpe2fs ${DSKa}1 > /dev/null 2>&1
RSLT=$( echo $? )
if [ "${RSLT}" == 0 ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 3.2.3 ##
echo -n "### Verify mnt label ... "

if [ ${UNAMEI} == 'i386' ]; then
  RSLT=$( /sbin/e2label ${DSKa}2 )
else
  RSLT=$( /sbin/e2label ${DSKb} )
fi
if [ "${RSLT}" == '/' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 3.2.4 ##
echo -n "### Verify mnt filesystem ... "

if [ ${UNAMEI} == 'i386' ]; then
  /sbin/dumpe2fs ${DSKa}2 > /dev/null 2>&1
else
  /sbin/dumpe2fs /dev/${DSKb} > /dev/null 2>&1
fi
RSLT=$( echo $? )
if [ "${RSLT}" == 0 ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 3.2.5 ##
echo -n "### Verify ${DSKa}3 label ... "

RSLT=$( /bin/grep ^${DSKa}3 /etc/fstab | awk '{print $2,$3}' )
if [ ${UNAMEI} == 'i386' -a "${RSLT}" == 'swap swap' ]; then
  echo "PASS"
elif [ ${UNAMEI} == 'x86_64' -a "${RSLT}" == '' ]; then
  echo "PASS"
elif [ ${PROVIDER} == 'ibm' ];then
 echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 3.2.6 ##
if [ ${UNAMEI} == 'i386' ] && [ ${PROVIDER} != 'ibm' ]; then
echo -n "### Verify ${DSKa}3 filesystem ... "

/sbin/swapoff ${DSKa}3 && /sbin/swapon ${DSKa}3 > /dev/null 2>&1
RSLT=$( echo $? )
if [ "${RSLT}" == 0 ]; then
  echo "PASS"
elif [ ${PROVIDER} == 'ibm' ];then
 echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi
fi

## Test 4.1 ##
echo -n "## Verify no .bash_history file ... "

if [ ! -f /root/.bash_history ]; then
  echo "PASS"
elif [ "${PROVIDER}" == 'ibm' ];then
 echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 4.2 ##
echo -n "## Verify no systemid file ... "

if [ ! -f /etc/sysconfig/rhn/systemid ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 5.1 ##
echo -n "## Verify rh-cloud-firstboot is off ... "

if [ "${PROVIDER}" == 'ibm' ];then
 RSLT=""
else
 RSLT=$( /sbin/chkconfig --list rh-cloud-firstboot | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
fi
if [ "${PROVIDER}" == 'ibm' ];then
 echo "PASS"
elif [ "${RSLT}" == 'rh-cloud-firstboot 0:off 1:off 2:off 3:off 4:off 5:off 6:off' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.3 ##
echo -n "## Verify nameserver ... "

RSLT=$( /usr/bin/dig clock.redhat.com | grep 66.187.233.4  | wc -l)
if [ "${RSLT}" == 1 ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 5.5.1 ##
echo -n "### Verify new securetty file ... "

DATE=$( stat /etc/securetty | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
if [ -f /etc/securetty -a "${SYSDATE}" == "${DATE}" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo "${SYSDATE} != ${DATE}"
  let FAILURES++
fi

## Test 5.5.2 ##
echo -n "### Verify group file ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/group.${PROVIDER}.${UNAMEI} /etc/group )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.5.3 ##
echo -n "### Verify new passwd file ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/passwd.${PROVIDER}.${UNAMEI} /etc/passwd )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.5.4 ##
echo -n "### Verify new inittab file ... "

DATE=$( stat /etc/inittab | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
if [ -f /etc/inittab -a "${SYSDATE}" == "${DATE}" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo "${SYSDATE} != ${DATE}"
  let FAILURES++
fi

## Test 5.5.5 ##
echo -n "### Verify new modprobe.conf file ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/modprobe.${PROVIDER}.txt /etc/modprobe.conf )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.5.6 ##
echo -n "### Verify new mtab file ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/mtab.${PROVIDER}.${UNAMEI} /etc/mtab )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.5.7 ##
echo -n "### Verify new shells file ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/shells.txt /etc/shells )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 5.6 ##
echo -n "## Verify new redhat repo file ... "

AZ=$( wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone | cut -d\- -f1,2 )
DATE=$( stat /etc/yum.repos.d/redhat-${AZ}.repo | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )
if [ -f /etc/yum.repos.d/redhat-${AZ}.repo -a "${SYSDATE}" == "${DATE}" ]; then
  echo "PASS"
elif [ ${PROVIDER} == 'ibm' ];then
 echo "PASS"
else
  echo "FAIL"
  echo "${SYSDATE} != ${DATE}"
  let FAILURES++
fi

## Test 5.7 ##
echo -n "## Verify disabled redhat repo files ... "

RSLT=$( grep ^enabled /etc/yum.repos.d/r*.repo | grep -v /etc/yum.repos.d/redhat-${AZ}.repo: | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq )
if [ "${RSLT}" == 0 ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 5.8 ##
echo -n "## Verify disabled yum plugin ... "

RSLT=$( grep ^enabled /etc/yum/pluginconf.d/rhnplugin.conf | grep -v '^#' | cut -d\= -f2 | awk '{print $1}' | sort -f | uniq )
if [ "${RSLT}" == 0 ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 5.9 ##
echo -n "## Verify GPG checking ... "

RSLT=$( grep '^gpgcheck=1' /etc/yum.repos.d/redhat-${AZ}.repo | cut -d\= -f2 | sort -f | uniq )
if [ "${RSLT}" == 1 ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 6.0 ##
#echo -n "## Verify hostname ... "
#
#RSLT=$( grep ^HOSTNAME= /etc/sysconfig/network | cut -d\= -f2 )
#if [ "${RSLT}" == $( /bin/hostname ) ]; then
#  echo "PASS"
#else
#  echo "FAIL"
#  let FAILURES++
#fi

## Test 6.1 ##
echo -n "## Verify IPv6 disabled ... "

RSLT=$( grep ^NETWORKING_IPV6= /etc/sysconfig/network | cut -d\= -f2 )
if [ "${RSLT}" == "no" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 6.2 ##
echo -n "## Verify networking ... "

RSLT=$( grep ^NETWORKING= /etc/sysconfig/network | cut -d\= -f2 )
if [ "${RSLT}" == "yes" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 7.0 ##
echo -n "## Verify device ... "

RSLT=$( grep ^DEVICE= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
if [ "${RSLT}" == "eth0" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 7.1 ##
echo -n "## Verify bootproto ... "

RSLT=$( grep ^BOOTPROTO= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
if [ "${RSLT}" == "dhcp" ]; then
  echo "PASS"
elif [ ${PROVIDER} == 'ibm' ] && [ "${RSLT}" == "static" ];then
 echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 7.2 ##
echo -n "## Verify onboot ... "

RSLT=$( grep ^ONBOOT= /etc/sysconfig/network-scripts/ifcfg-eth0 | cut -d\= -f2 )
if [ "${RSLT}" == "on" ]; then
  echo "PASS"
elif [ ${PROVIDER} == 'ibm' ] && [ "${RSLT}" == "yes" ];then
 echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

## Test 8.0 ##
echo -n "## Verify iptables ... "

/sbin/service iptables status > /tmp/iptables.txt
RSLT=$( /usr/bin/diff ${DIFF_DIR}/iptables.txt /tmp/iptables.txt )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 8.1 ##
echo -n "## Verify sshd is on ... "

RSLT=$( /sbin/chkconfig --list sshd | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
if [ "${RSLT}" == 'sshd 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 8.2 ##
echo -n "## Verify all of chkconfig ... "

/sbin/chkconfig --list > /tmp/chkconfig.txt
RSLT=$( /usr/bin/diff ${DIFF_DIR}/chkconfig.${PROVIDER}.${UNAMEI} /tmp/chkconfig.txt )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 9.0 ##
echo -n "## Verify syslog is on ... "

RSLT=$( /sbin/chkconfig --list syslog | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
if [ "${RSLT}" == 'syslog 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 9.1 ##
echo -n "## Verify syslog config ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/syslog.conf /etc/syslog.conf )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 10.0 ##
echo -n "## Verify auditd is on ... "

RSLT=$( /sbin/chkconfig --list auditd | awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' )
if [ "${RSLT}" == 'auditd 0:off 1:off 2:on 3:on 4:on 5:on 6:off' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 10.1 ##
echo -n "## Verify audit.rules ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/audit.rules /etc/audit/audit.rules )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 10.2 ##
echo -n "## Verify auditd.conf ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/auditd.conf /etc/audit/auditd.conf )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 10.3 ##
echo -n "## Verify auditd sysconfig ... "

RSLT=$( /usr/bin/diff ${DIFF_DIR}/auditd /etc/sysconfig/auditd )
if [ "${RSLT}" == '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.0 ##
echo -n "## Verify kernel name ... "

RSLT=$( /bin/uname -s )
if [ "${RSLT}" == 'Linux' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.1 ##
echo -n "## Verify network node hostname ... "

RSLT=$( /bin/uname -n )
if [ "${RSLT}" == ${HOSTNAME} ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.2 ##
echo -n "## Verify kernel release ... "

RSLT=$( /bin/uname -r | sed -e 's/xen$//g' )
if [ "${RSLT}" == "$(rpm -qa kernel\* --queryformat="%{VERSION}-%{RELEASE}\n" | sort -f | uniq)" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.3 ##
echo -n "## Verify kernel version ... "

RSLT=$( /bin/uname -v )
if [ "${RSLT}" != '' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.4 ##
echo -n "## Verify machine hardware name ... "

RSLT=$( /bin/uname -m )
if [ ${UNAMEI} == 'i386' ]; then
  UNAMEM=i686
else
  UNAMEM=${RSLT}
fi 
if [ "${RSLT}" == "${UNAMEM}" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.5 ##
echo -n "## Verify processor type ... "

RSLT=$( /bin/uname -p )
if [ ${UNAMEI} == 'i686' ]; then
  UNAMEP=athlon
else
  UNAMEP=${RSLT}
fi 
if [ "${RSLT}" == "${UNAMEP}" ]; then
  echo "PASS"
elif [ "${RSLT}" == 'i686' ] && [ ${PROVIDER} == 'ibm' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.6 ##
echo -n "## Verify hardware platform ... "

RSLT=$( /bin/uname -i )
if [ "${RSLT}" == "${UNAMEI}" ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Test 11.7 ##
echo -n "## Verify operating system ... "

RSLT=$( /bin/uname -o )
if [ "${RSLT}" == 'GNU/Linux' ]; then
  echo "PASS"
else
  echo "FAIL"
  echo ${RSLT}
  let FAILURES++
fi

## Summary ##
echo "FAILURES = ${FAILURES}"
exit ${FAILURES}

