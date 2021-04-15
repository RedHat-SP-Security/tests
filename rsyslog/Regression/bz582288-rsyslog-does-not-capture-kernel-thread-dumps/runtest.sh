#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz582288-rsyslog-does-not-capture-kernel-thread-dumps
#   Description: Test for bz582288 (rsyslog does not capture kernel thread dumps)
#   Author: Karel Srot <ksrot@redhat.com>
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

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlFileBackup /etc/rsyslog.conf
	if rlIsRHEL 5; then
		rlServiceStop syslog
	fi
	rlRun "SYSRQ=\`cat /proc/sys/kernel/sysrq\`" 0 "Store current value in /proc/sys/kernel/sysrq"
        rlRun "echo 1 > /proc/sys/kernel/sysrq" 0 "Enabling SysRq facility in kernel"
    rlPhaseEnd

    rlPhaseStartTest
	# for RHEL5 check whether imklog.so module is enabled by default
	if rlIsRHEL 5; then
	    rlRun "egrep '^\\\$ModLoad imklog' /etc/rsyslog.conf" 0 "Checking if imklog is loaded by default on RHEL5"
	fi
	rlRun "cat test.conf >> /etc/rsyslog.conf" 0 "Updating rsyslog.conf"
	rlServiceStart rsyslog
	rlRun "echo 't' > /proc/sysrq-trigger" 0 "dump thread state information"
	sleep 3
	#cat /var/log/rsyslog.kern.test
	rlRun "egrep -qi 'kernel:.*Call Trace:' /var/log/rsyslog.kern.test" 0 "Searching for dump in the logfile"
    rlPhaseEnd

    rlPhaseStartCleanup
	rlFileRestore
	rlServiceRestore rsyslog
        rlRun "echo $SYSRQ > /proc/sys/kernel/sysrq" 0 "Restore old value in /proc/sys/kernel/sysrq"
        rlRun "rm -f /var/log/rsyslog.kern.test" 0 "Remove test logfile"
	if rlIsRHEL 5; then
		rlServiceRestore syslog
	fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

