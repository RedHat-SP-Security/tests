#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz847568-The-IncludeConfig-behavior-of-rsyslog-is-wrong
#   Description: Test for BZ#847568 (The $IncludeConfig behavior of rsyslog is wrong.)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

rpm -q rsyslog5 && PACKAGE=rsyslog5

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
	rlFileBackup /etc/rsyslog.conf
	[ -d /etc/rsyslog.d ] || rlRun "mkdir -p /etc/rsyslog.d/ && restorecon /etc/rsyslog.d"
	cat > /etc/rsyslog.conf <<EOF
\$ModLoad imuxsock.so
\$ModLoad imklog.so
\$ModLoad imjournal                       # RHEL7only
\$WorkDirectory /var/lib/rsyslog          # RHEL7only
\$IncludeConfig /etc/rsyslog.d/*.conf     # RHEL7only
\$OmitLocalLogging on                     # RHEL7only
\$IMJournalStateFile imjournal.state      # RHEL7only

\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

local1.*  /var/log/bz847568-local1.log
local2.*  /var/log/bz847568-local2.log
\$IncludeConfig /etc/rsyslog.d/bz847568-local3.conf.noauto
EOF
	rlIsRHEL 4 5 6 && rlRun "sed -i '/RHEL7only/d' /etc/rsyslog.conf" 0 "Delete RHEL-7 specific configuration"
	cat > /etc/rsyslog.d/bz847568-local3.conf.noauto <<EOF
local3.*  /var/log/bz847568-local3.log
:fromhost-ip, isequal, "127.0.0.1" ~
EOF
        if rlIsRHEL 5; then
                rlServiceStop syslog
        fi
	rlServiceStart rsyslog
	sleep 5
    rlPhaseEnd

    rlPhaseStartTest
	for I in `seq 3`; do
		rlRun "logger -p local$I.info 'test message $I'"
	done
	sleep 5
	for I in `seq 3`; do
		cat /var/log/bz847568-local$I.log
		rlAssertGrep "test message $I" /var/log/bz847568-local$I.log
	done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm /var/log/bz847568-local[1-3].log" 0 "Removing test log files"
	rlRun "rm -rf /etc/rsyslog.d/bz847568-local3.conf.noauto"
	rlFileRestore
	rlServiceRestore rsyslog
        if rlIsRHEL 5; then
                rlServiceRestore syslog
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

