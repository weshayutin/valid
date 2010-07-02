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
echo "DISK INFORMATION"
echo ""
echo  "DSKa = $DSKa"
echo  "DSKb = $DSKb"
echo  "DSKc = $DSKc"
echo ""

SYSDATE=$( stat /etc/sysconfig/hwconf | grep ^Change:  | awk '{print $2,$3}' | cut -d: -f1,2 )

function selinux()
{
echo -n "# Selinux tests ... "
RSLT=$( /usr/sbin/getenforce )
if [ ${RSLT} == 'Enforcing' ]; then
  echo "PASS"
else
 echo "FAIL"
 let FAILURES++
fi

echo -n "## Verify SELINUX enforcing ... "

RSLT=$( grep ^SELINUX= /etc/sysconfig/selinux | cut -d\= -f2 )
if [ "${RSLT}" == "enforcing" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

echo -n "## Verify SELINUXTYPE targeted ... "

RSLT=$( grep ^SELINUXTYPE= /etc/sysconfig/selinux | cut -d\= -f2 )
if [ "${RSLT}" == "targeted" ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

echo -n "# Flip Selinux Permissive ... "
RSLT=$( /usr/sbin/setenforce Permissive && /usr/sbin/getenforce )
if [ ${RSLT} == 'Permissive' ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi

echo -n "# Flip Selinux Enforcing ... "
RSLT=$( /usr/sbin/setenforce Enforcing && /usr/sbin/getenforce )
if [ ${RSLT} == 'Enforcing' ]; then
  echo "PASS"
else
  echo "FAIL"
  let FAILURES++
fi
}

