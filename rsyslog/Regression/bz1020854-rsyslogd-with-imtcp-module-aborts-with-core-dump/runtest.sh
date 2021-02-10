#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1020854-rsyslogd-with-imtcp-module-aborts-with-core-dump
#   Description: Test for BZ#1020854 (rsyslogd with imtcp module aborts with core-dump)
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlFileBackup --clean /run/systemd/journal/syslog
	if systemctl status rsyslog.service; then
	    touch rsyslog.running
	    rlRun "systemctl stop rsyslog.service" 0 "Stopping rsyslog.service"
	fi
	if systemctl status syslog.socket; then
	    touch socket.running
	    rlRun "systemctl stop syslog.socket" 0 "Stopping syslog.socket"
	fi
	rlRun "systemctl status rsyslog.service" 3 "rsyslog.service should be stopped"
	rlRun "systemctl status syslog.socket" 3 "syslog.socket should be stopped"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "systemctl start syslog.socket" 0-255 "Start syslog.socket should fail"  #since it is currently useless in RHEL-7
        rlRun "systemctl status syslog.socket" 0-255 "syslog.socket should be stopped"
        rlRun "systemctl status rsyslog.service" 3 "rsyslog.service should be stopped"
        rlRun "systemctl start rsyslog.service" 0 "Starting rsyslog.service"
        rlRun "systemctl status rsyslog.service" 0 "rsyslog.service should be running"
        rlRun "systemctl status syslog.socket" 0-255 "syslog.socket should be stopped"
        rlRun "systemctl stop rsyslog.service" 0 "Stopping rsyslog.service"
        rlRun "systemctl status rsyslog.service" 3 "rsyslog.service should be stopped"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
	[ -f rsyslog.running ] && rlRun "systemctl start rsyslog.service"
	[ -f socket.running ] && rlRun "systemctl start syslog.socket"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
