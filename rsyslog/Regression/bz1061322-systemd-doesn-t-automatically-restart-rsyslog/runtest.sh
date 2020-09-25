#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1061322-systemd-doesn-t-automatically-restart-rsyslog
#   Description: Test for BZ#1061322 (systemd doesn't automatically restart rsyslog)
#   Author: Marek Marusic <mmarusic@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rsyslogServiceStart
        touch /tmp/disable-qe-abrt  # disable https://wiki.test.redhat.com/BaseOs/AutomatedCrashProcessing
    rlPhaseEnd

    rlPhaseStartTest
        #Check if the Restart on failure is in rsyslog.service
        rlAssertGrep "Restart=on-failure" /lib/systemd/system/rsyslog.service
        rlRun "kill -s ABRT `pidof rsyslogd`" 0 "Simulate failure of rsyslogd"
        sleep 1
        rlRun -s "service rsyslog status" 0 "Get status of rsyslog service"
        rlAssertGrep "active (running)" $rlRun_LOG
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        #rlFileRestore
        rsyslogServiceRestore
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rm /tmp/disable-qe-abrt
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
