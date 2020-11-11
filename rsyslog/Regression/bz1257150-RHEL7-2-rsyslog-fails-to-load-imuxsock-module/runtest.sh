#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1257150-RHEL7-2-rsyslog-fails-to-load-imuxsock-module
#   Description: Test for BZ#1257150 ([RHEL7.2] rsyslog fails to  load imuxsock module)
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
rpm -q rsyslog7 && PACKAGE="rsyslog7"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlFileBackup /etc/rsyslog.conf /var/log/messages /dev/log
        echo "" > /var/log/messages
        cat > /etc/rsyslog.conf << EOF
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
\$ModLoad imuxsock
*.info;mail.none;authpriv.none;cron.none                /var/log/messages
EOF
    rlPhaseEnd

    rlPhaseStartTest
        rlServiceStart rsyslog
        rlAssertNotGrep ".*Permission denied" /var/log/messages
        rlAssertNotGrep "rsyslogd.*cannot.*create" /var/log/messages
        rlRun "logger 'BZ#1257150 test message'"
        rlAssertGrep "BZ#1257150 test message" /var/log/messages
    rlPhaseEnd

    rlPhaseStartCleanup
        rlServiceStop rsyslog
        rlFileRestore
        rlServiceRestore rsyslog
        # need for /dev/log restore
        if rlIsRHEL 7 ; then
            rlRun "systemctl restart systemd-journald.socket"
        elif rlIsRHEL 8 ; then
            rlRun "systemctl stop systemd-journald-dev-log.socket"
            rlRun "systemctl stop systemd-journald.socket"
            rlRun "systemctl stop systemd-journald"
            rlRun "systemctl restart systemd-journald.socket"
            rlRun "systemctl restart systemd-journald-dev-log.socket"
            rlRun "systemctl start systemd-journald"
        fi
        rlRun "ls -l /dev/log"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
