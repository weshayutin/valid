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

function usage()
{
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
	   echo "Please use all options"
	   echo ""
           echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
           echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
           echo " http://bugzilla.redhat.com/ "
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
           echo ""
           echo "Available options are:"
           echo "--imageID=          :: Please provide a unique id for the image"
           echo "--RHEL=             :: Please specify the correct FULL rhel version eg: --RHEL=5.7 or --RHEL=6.1"
           echo "--full-yum-suite=   :: Please input the value  "yes" OR "no""          
	   echo "--skip-questions=   :: Please input the value  "yes" or "no""
	   echo "--bugzilla-username :: Please specify your bugzilla username@email.com"
	   echo "--bugzilla-password :: Please specify your bugzilla password"
	   echo "--bugzilla-num      :: If a bug has already been opened you can specify the number here "
	   echo "--memory            :: Minium total kb of  memory the system *should* have available "
}


#cli
for i in $*
 do
 case $i in
      --imageID=*)
         IMAGEID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --RHEL=*)
         RHELV="`echo $i | sed 's/[-A-Z]*=//'`"
         ;;
      --full-yum-suite=*)
          yum_test="`echo $i | sed 's/[-a-zA-Z]*=//'`"
          if [ "$yum_test" == "yes" ] || [ "$yum_test" == "no" ]; then
            :
          else
	    usage
            exit 1
          fi
          ;;
      --skip-questions=*)
	  QUESTIONS="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-username=*)
	  BUG_USERNAME="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-password=*)
	  BUG_PASSWORD="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-num=*)
	  BUG_NUM="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --failures=*)
	  FAILURES="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --memory=*)
	  MEM_HWP="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
          ;;
        *)
         # unknown option 
	   usage
           exit 1
           ;;
 esac
done


if [[ -z $IMAGEID ]] || [[ -z $RHELV ]] ||  [[ -z $yum_test ]] || [[ -z $BUG_USERNAME ]] || [[ -z $BUG_PASSWORD ]] ; then
 usage
 exit 1
fi




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
postReboot
echo ""
echo "##### START TESTS #####"
echo ""
test_yum_plugin
test_uname
test_memory
print_rhel_version
#installTestKernel


### DONT REMOVE OR COMMENT OUT ###
show_failures
bugzilla_comments()
verify_bugzilla
#sos_report
im_exit
##################################






