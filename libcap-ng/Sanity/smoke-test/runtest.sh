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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libcap-ng"

TESTUSER="libcapngtestuser"
SPECFILE="~${TESTUSER}/rpmbuild/SPECS/libcap-ng.spec"

rlJournalStart

    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "useradd $TESTUSER" 0-255
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlFetchSrcForInstalled $PACKAGE
        rlRun "chown -R ${TESTUSER}:${TESTUSER} ${TmpDir}"
        rlRun "SRC_RPM=$(ls libcap-ng*.src.rpm)"
    rlPhaseEnd

    rlPhaseStartTest "Rebuilding ${SRC_RPM}"
        rlRun "/sbin/runuser -s /bin/sh -c 'rpm -ihv ${SRC_RPM}' -- ${TESTUSER}" 0 "Installing libcap-ng source RPM"
        rlRun "dnf builddep ${SPECFILE} -y"

        rlRun "/sbin/runuser -s /bin/sh -c 'rpmbuild -vv -bc ${SPECFILE}' -- ${TESTUSER}" 0 "Building libcap-ng source RPM"

        rlRun "/sbin/runuser -s /bin/sh -c \"make -C ~/rpmbuild/BUILD/libcap-ng* check\" > make.check.out -- ${TESTUSER}" 0 "Running libcap-ng self-test (as non-root user)"
        rlRun "cat make.check.out"

        if rlIsRHEL 6; then
            rlAssertNotGrep "failed"  make.check.out
            rlAssertNotGrep "skipped" make.check.out
            rlRun "[ `grep passed make.check.out | wc -l` -eq 2 ]" 0 "All tests should pass."
        else
            rlAssertEquals "1st set of tests should pass" \
            `grep '# PASS:' make.check.out | awk 'NR==1 {print $3}'` \
            `grep '# TOTAL:' make.check.out | awk 'NR==1 {print $3}'`

            if rlIsRHEL "<8"; then
                rlAssertEquals "2nd set of tests should pass" \
                `grep '# PASS:' make.check.out | awk 'NR==2 {print $3}'` \
                `grep '# TOTAL:' make.check.out | awk 'NR==2 {print $3}'`
            fi
        fi
        rm -f make.check.out
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "userdel -fr ${TESTUSER}" 0
        rlRun "popd"
        rlRun "rm -r ${TmpDir}" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd

