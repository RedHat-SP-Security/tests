#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libcap-ng/Sanity/smoke-test
#   Description: Test calls upstream test suite.
#   Author: Ondrej Moris <omoris@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="libcap-ng"

TESTUSER="libcapngtestuser"

rlJournalStart

    rlPhaseStartSetup
    
        rlAssertRpm $PACKAGE	
	rlRun "useradd $TESTUSER" 0-255
	rlFetchSrcForInstalled $PACKAGE

    rlPhaseEnd

    rlPhaseStartTest
    
         rlRun "cp *.rpm /tmp/libcap.src.rpm" 0

	 rlRun "/sbin/runuser -s /bin/sh -c \
                'rpm -ihv /tmp/libcap.src.rpm' -- $TESTUSER" 0 \
	     "Installing libcap-ng source RPM"
	 
         rlRun "/sbin/runuser -s /bin/sh -c \
                'rpmbuild -vv -bc ~/rpmbuild/SPECS/libcap-ng.spec' \
                -- $TESTUSER" 0 \
	     "Building libcap-ng source RPM"

         rlRun "/sbin/runuser -s /bin/sh -c \
                \"make -C ~/rpmbuild/BUILD/libcap-ng* check\" \
                >/tmp/make.check.out -- $TESTUSER" 0 \
	     "Running libcap-ng self-test (as non-root user)"

	 
	 cat /tmp/make.check.out

	if rlIsRHEL 6; then
            rlAssertNotGrep "failed"  /tmp/make.check.out
            rlAssertNotGrep "skipped" /tmp/make.check.out
            rlRun "[ `grep passed /tmp/make.check.out | wc -l` -eq 2 ]" 0 "All tests should pass."
	else
	    rlAssertEquals "1st set of tests should pass" \
                       `grep '# PASS:' /tmp/make.check.out | awk 'NR==1 {print $3}'` \
                       `grep '# TOTAL:' /tmp/make.check.out | awk 'NR==1 {print $3}'`
            if rlIsRHEL "<8"; then
	        rlAssertEquals "2nd set of tests should pass" \
                               `grep '# PASS:' /tmp/make.check.out | awk 'NR==2 {print $3}'` \
                               `grep '# TOTAL:' /tmp/make.check.out | awk 'NR==2 {print $3}'`
            fi
	fi
	 rm -f /tmp/make.check.out
	 
    rlPhaseEnd

    rlPhaseStartCleanup

	rlRun "userdel $TESTUSER" 0
	rlRun "rm -rf /home/$TESTUSER" 0

    rlPhaseEnd

rlJournalPrintText

rlJournalEnd
