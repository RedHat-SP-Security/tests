#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz654379-service-rsyslog-start-cat-hangs
#   Description: Test for bz654379 (service rsyslog start | cat hangs)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"
PACKAGE="${COMPONENT:-$PACKAGE}"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
	rlIsRHEL 4 5 && rlServiceStop syslog
	rlServiceStart rsyslog
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "service rsyslog restart | cat &" 
	PID=$!
	sleep 10
	rlRun "jobs | egrep 'Running.*service rsyslog restart \| cat'" 1 "cat should not be running"
        rlRun "service rsyslog status" 0 "rsyslog should be running"
    rlPhaseEnd

    rlPhaseStartCleanup
	rlRun "service rsyslog stop"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlServiceRestore rsyslog
	rlIsRHEL 4 5 && rlServiceRestore syslog
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
