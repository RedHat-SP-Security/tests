#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz886004-rsyslog-not-understaning-rfc5424-messages-through
#   Description: Test for BZ#886004 (rsyslog not understaning rfc5424 messages through)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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
rpm -q rsyslog5 && PACKAGE="rsyslog5"

TESTDIR=$PWD

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	rlRun "gcc -o test $TESTDIR/test.c" 0 "Compile the test program"
	rlFileBackup /etc/rsyslog.conf
	rlLog "Updating /etc/rsyslog.conf"
	cat > /etc/rsyslog.conf <<EOF
\$WorkDirectory /var/lib/rsyslog
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
\$modload imuxsock
\$SystemLogSocketName /dev/bz886004log
\$OmitLocalLogging off
\$SystemLogSocketIgnoreMsgTimestamp off
\$systemlogusesystimestamp off   # not RHEL6
*.* /var/log/bz886004.log
EOF
	rlIsRHEL 6 && rlRun 'sed -i "/not RHEL6/d" /etc/rsyslog.conf'
	cat /etc/rsyslog.conf
	rlServiceStart rsyslog
	sleep 3
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "./test" 0 "Executing the test program"
	rlAssertExists /var/log/bz886004.log
	cat /var/log/bz886004.log
	HOSTNAME=`hostname -s`
	rlAssertGrep "Dec 10 16:47:28 $HOSTNAME this is a test message" /var/log/bz886004.log
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
	rlFileRestore
	rlServiceRestore rsyslog
        rlRun "rm -r $TmpDir /var/log/bz886004.log" 0 "Removing tmp files"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
