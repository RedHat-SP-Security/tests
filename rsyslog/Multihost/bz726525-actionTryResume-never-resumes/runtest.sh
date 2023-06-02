#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/bz726525-actionTryResume-never-resumes
#   Description: Test for bz726525 (actionTryResume never resumes)
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

# Global variables that can be passed to the test:
# ACTIONQUEUEMAXFILESIZE - the value of $ActionQueueMaxFileSize in rsyslog.conf (1g default)
# ACTIONQUEUESIZE - the value of $ActionQueueSix in rsyslog.conf, default 10000
# MESSAGESSENT - the number of log messages sent during the test, default 5000
# MAXQUEUEFILES - the maximum number of queue files that can be created by rsyslog during the test
#                 we will that that rsyslog didn't create more, default 3
# SHUTDOWNDURATION - number of seconds when the rsyslog server is down, default 60
# RESENDTIMELIMIT - maximum time to wait on server for client resending his logs, default 120

[ -z "$ACTIONQUEUEMAXFILESIZE" ] && ACTIONQUEUEMAXFILESIZE=1g
[ -z "$ACTIONQUEUESIZE" ] && ACTIONQUEUESIZE=10000
[ -z "$MESSAGESSENT" ] && MESSAGESSENT=5000
[ -z "$MAXQUEUEFILES" ] && MAXQUEUEFILES=7
[ -z "$SHUTDOWNDURATION" ] && SHUTDOWNDURATION=60
[ -z "$RESENDTIMELIMIT" ] && RESENDTIMELIMIT=120

#HWM=700
#LWM=100
HWM=$(($MESSAGESSENT*7/10))
LWM=$(($MESSAGESSENT*1/10))


PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie "cannot continue"
        rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "rsyslogServiceStop"
        CleanupRegister 'rlRun "rsyslogServerCleanup"'
        rlRun "rsyslogServerSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rlFileRestore"; rlRun "rlServiceRestore systemd-journald"'
        rlRun "rlFileBackup --clean /var/log/bz701782-rsyslog.log /etc/systemd/journald.conf"
        rlRun "sed -i 's/.*RateLimitInterval=.*/RateLimitInterval=1s/g;s/.*RateLimitBurst=.*/RateLimitBurst=1000000/g' /etc/systemd/journald.conf"
        rlRun "rlServiceStart systemd-journald"
        rlRun "mkdir -p /var/lib/rsyslog && restorecon -v /var/lib/rsyslog"
        rlRun "rm -f /var/log/bz701782-rsyslog.log"
        rsyslogServerConfigAppend "RULES" << EOF
\$ModLoad imtcp.so
\$InputTCPMaxSessions 1000
\$InputTCPServerRun 514

local2.error   /var/log/server/bz701782-rsyslog.log
EOF
        rsyslogConfigAppend "RULES" << EOF
\$MaxOpenFiles 1024

# Configure the work queue files
\$ActionQueueType LinkedList
\$ActionQueueHighWaterMark $HWM
\$ActionQueueLowWaterMark $LWM
\$ActionQueueFileName remoteq
\$ActionQueueSize $ACTIONQUEUESIZE
\$ActionQueueMaxFileSize $ACTIONQUEUEMAXFILESIZE
\$ActionResumeRetryCount -1
\$ActionResumeInterval 20

local2.error    @@127.0.0.1
local2.error    /var/log/bz701782-rsyslog.log
EOF
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "rsyslogServerPrintEffectiveConfig -n"
        rlRun "rsyslogServerStart"
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"

        # communication test
        [[ -e /var/log/bz701782-rsyslog.log ]] && rlAssertNotGrep "bz726525 communication test" /var/log/bz701782-rsyslog.log
        [[ -e /var/log/server/bz701782-rsyslog.log ]] && rlAssertNotGrep "bz726525 communication test" /var/log/server/bz701782-rsyslog.log
        rlRun "logger -p local2.error 'bz726525 communication test'" 0 "Sending a test message to the server"
        sleepWithProgress 6
        rlAssertGrep "bz726525 communication test" /var/log/bz701782-rsyslog.log
        rlAssertGrep "bz726525 communication test" /var/log/server/bz701782-rsyslog.log

        # shut down server
        rlRun "rsyslogServerStop"
        sleepWithProgress 3

        # send messages
        rlLog "Producing $MESSAGESSENT log messages"
        (
          progressHeader $MESSAGESSENT 1
          for ((i=1; i<=MESSAGESSENT; i++)); do
              progressDraw $i
              echo "bz726525 test message $i."
              sleep 0.0001
          done
          progressFooter
        ) | logger -p local2.error

        sleepWithProgress 3

        # check queue file
	rlRun "grep -q 'bz726525 test message 1' /var/lib/rsyslog/remoteq*" 0 "Checking that messages are in the queue at /var/lib/rsyslog/remoteq*"
	rlRun -s "ls -l /var/lib/rsyslog/ 2> /dev/null"
	#rlRun "/sbin/rsyslogd -dn &>> rsyslogd.out &" 0 "Starting rsyslogd in debug mode"
	sleepWithProgress 2
	QUEUES=`cat $rlRun_LOG | grep 'remoteq' | wc -l`
	rlRun "test $QUEUES -le $MAXQUEUEFILES" 0 "There should be at most $MAXQUEUEFILES queue files (was $QUEUES)"

        # start server
        rlLog "Waiting $SHUTDOWNDURATION secs before starting rsyslogd to gather some 'actionTryResume: iRet: -2007, next retry' messages"
        sleepWithProgress $SHUTDOWNDURATION
	rlRun "tail -f $rsyslogServerLogDir/bz701782-rsyslog.log &"
	tail_pid=$!
        rlRun "rsyslogServerStart"

        # wait for messages
        rlRun "rsyslogWaitTillGrowing $rsyslogServerLogDir/bz701782-rsyslog.log '' $RESENDTIMELIMIT 30 \"[[ \\\$(grep -oE 'bz726525 test message [0-9]+\.' $rsyslogServerLogDir/bz701782-rsyslog.log | wc -l) -ge $MESSAGESSENT ]]\"" 0,1
        kill $tail_pid

        # check delivered messages
        rlRun "rsyslogCheckDelivered $MESSAGESSENT 1" 0,1 < <(grep -oE 'bz726525 test message [0-9]+\.' $rsyslogServerLogDir/bz701782-rsyslog.log | grep -oE '[0-9]+\.' | grep -Eo '[0-9]+')
    rlPhaseEnd

    rlPhaseStartCleanup
        [ -f $rsyslogServerLogDir/bz701782-rsyslog.log ] && rlFileSubmit $rsyslogServerLogDir/bz701782-rsyslog.log
        CleanupDo
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd

