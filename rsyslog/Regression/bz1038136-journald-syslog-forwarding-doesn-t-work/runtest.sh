#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1038136-journald-syslog-forwarding-doesn-t-work
#   Description: Test for BZ#1038136 (journald syslog forwarding doesn't work)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc. All rights reserved.
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
PYTHON='/usr/bin/python'
[[ -x $PYTHON ]] || PYTHON='/usr/bin/python2'
[[ -x $PYTHON ]] || PYTHON='/usr/bin/python3'
[[ -x $PYTHON ]] || PYTHON='/usr/libexec/platform-python'


rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "rlServiceStart rsyslog"
    rlPhaseEnd

    rlPhaseStartTest
	for I in `seq 5`; do
	    rlRun "$PYTHON -c 'from systemd import journal; journal.send(\"bz1038136 process $$ test message $I\")'"
	done
	sleep 3
	for I in `seq 5`; do
	    rlAssertGrep "bz1038136 process $$ test message $I" /var/log/messages
	done
	tail /var/log/messages
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore rsyslog"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
