#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/ompipe-module-test
#   Description: Simple test of ompipe rsyslog module
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
PACKAGE="${COMPONENT:-$PACKAGE}"

genMessages() {
  progressHeader $1 1
  for i in `seq 1 $1`; do
    progressDraw $i
    logger -p local6.error "Hello from message number $i-"
  done
  progressFooter
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "rlFileBackup --clean /etc/systemd/journald.conf"
        rlRun "rsyslogPrepareConf"
        rsyslogConfigIsNewSyntax || rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf <<EOF
# ompipe test rule
local0.info    |/var/log/rsyslog.test.pipe
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf <<EOF
# ompipe test rule
local0.info    action(type="ompipe" pipe="/var/log/rsyslog.test.pipe")
EOF
        rlRun "TMPFILE=\`mktemp\`"
        rlRun "mkfifo /var/log/rsyslog.test.pipe"
        rlRun "chcon --reference=/var/log/messages /var/log/rsyslog.test.pipe" 0 "Changing SElinux context on /var/log/rsyslog.test.pipe"
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
    rlPhaseEnd

    rlPhaseStartTest "basic test"
        rlRun "cat /var/log/rsyslog.test.pipe > $TMPFILE &" 0 "Start reading from a pipe"
        pid=$!
        rlRun "logger -p local0.info 'pipe test message'" 0 "Sending the test message"
        sleepWithProgress 10
        rlRun "rsyslogServiceStop"
        sleepWithProgress 3
        rlRun "grep 'pipe test message' $TMPFILE" 0 "Verify that the message was properly logged"
        rlRun "kill $pid" 0-255
    rlPhaseEnd

    rlPhaseStartTest "bz1591819"
        rsyslogPrepareConf
        rsyslogConfigIsNewSyntax || rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf <<EOF
# ompipe test rule
\$SystemLogRateLimitInterval 0
\$SystemLogRateLimitBurst 0

\$ActionQueueFileName pipeRule1
\$ActionQueueMaxDiskSpace 1g
\$ActionQueueSaveOnShutdown on
\$ActionQueueType LinkedList
\$ActionResumeRetryCount -1
local6.info    |/var/log/rsyslog.test.pipe
EOF

        rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf <<EOF
# ompipe test rule
\$SystemLogRateLimitInterval 0
\$SystemLogRateLimitBurst 0

if (\$syslogfacility-text == 'local6' )
then {
    action(type="ompipe"
            queue.type="LinkedList"
            queue.FileName="pipe.queue"
            queue.MaxDiskSpace="1G"
            queue.SaveOnShutdown="on"
            action.resumeRetryCount="-1"

            pipe="/var/log/rsyslog.test.pipe"
            )
    stop
}
EOF
        rlRun "sed -i 's/#RateLimitInterval=.*/RateLimitInterval=0/g' /etc/systemd/journald.conf"
        rlRun "sed -i 's/#RateLimitBurst=.*/RateLimitBurst=0/g' /etc/systemd/journald.conf"
        rlRun "systemctl restart systemd-journald.service"
        rlRun "rsyslogPrintEffectiveConfig -n"

        rlRun "rsyslogServiceStart"

        msgs=2000
        rlRun "genMessages $msgs"
        sleepWithProgress 3
        rlRun "cat /var/log/rsyslog.test.pipe > $TMPFILE &" 0 "Start reading from a pipe"
        pid=$!

        rlRun "rsyslogWaitTillGrowing $TMPFILE '' 60 60 \"[[ \\\$(grep 'Hello from message number' $TMPFILE | wc -l) -eq $msgs ]]\""

        rlRun "grep -Eo 'Hello from message number [0-9]+-' $TMPFILE | grep -Eo '[0-9]+' | rsyslogCheckDelivered $msgs"
        rlGetTestState || rlRun "cat $TMPFILE"

        rlRun "rsyslogServiceStop"
        rlRun "kill $pid" 0-255
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
        rlRun "rm -f /var/log/rsyslog.test.pipe $TMPFILE"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlRun "rsyslogCleanup"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
