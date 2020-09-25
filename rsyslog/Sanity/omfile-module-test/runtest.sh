#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/omfile-module-test
#   Description: Basic testing of omfile rsyslog module
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
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="rsyslog"
PACKAGE="${COMPONENT:-$PACKAGE}"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires"
        VER3=false
        rsyslogVersion 3 && VER3=true
        rlFileBackup /etc/rsyslog.conf
        rsyslogPrepareConf
    rlPhaseEnd

if ! $VER3; then
    rlPhaseStartTest "\$OMFileZipLevel test"   # logfile compression test"
	rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection ZIPTEST <<EOF
# log file compression test
local0.info    action(type="omfile" file="/var/log/rsyslog.test.gz" zipLevel="5")     # set logfile compression on
action(type="omfile" zipLevel="0")     # restore default
EOF
)
    rsyslogConfigIsNewSyntax || rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection ZIPTEST <<EOF
# log file compression test

\$OMFileZipLevel 5     # set logfile compression on
local0.info    /var/log/rsyslog.test.gz
\$OMFileZipLevel 0     # restore default
EOF
)
	rsyslogServiceStart
	rlRun "logger -p local0.info 'logfile compression test'" 0 "Logging the test message"
	sleep 2
	rlRun "file /var/log/rsyslog.test.gz | grep 'gzip compressed data'" 0 "Checking that logfile is a gzip archive"
	rlRun "gunzip -c --stdout /var/log/rsyslog.test.gz | grep 'logfile compression test'" 0 "Searching for the test message"
    rlPhaseEnd

    rlPhaseStartTest "Test logfile with relative path"
        # since rsyslogd changes it's working dir to / after the fork then the relpath is "the same" as absolute path
    rsyslogConfigReplace "ZIPTEST" /etc/rsyslog.conf
	rsyslogConfigIsNewSyntax || rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection RELPATH <<EOF
*.*   ./tmp/rsyslog.rel-path-test.log
EOF
)
    rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection RELPATH <<EOF
*.*   action(type="omfile" file="./tmp/rsyslog.rel-path-test.log")
EOF
)

    rsyslogServiceStart
	rlRun "logger -p local0.info 'relpath test message'" 0 "Logging the test message"
	sleep 2
	rlRun "grep 'relpath test message' /tmp/rsyslog.rel-path-test.log" 0 "Check the message in the log"
    rlPhaseEnd

    rlPhaseStartTest "\$OMFileFlushOnTXEnd and \$OMFileIOBufferSize test"  # check that messages are flushed in batch
	rsyslogConfigReplace "RELPATH" /etc/rsyslog.conf
	rsyslogConfigIsNewSyntax && rsyslogConfigAppend --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection FLUSHTEST <<EOF
local0.info    action(type="omfile" file="/var/log/rsyslog.test.log" IOBufferSize="1k" FlushOnTXEnd="off")    # default is 4k
EOF
)
    rsyslogConfigIsNewSyntax || rsyslogConfigAppend --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection FLUSHTEST <<EOF
\$OMFileIOBufferSize 1k    # default is 4k
\$OMFileFlushOnTXEnd off
local0.info    /var/log/rsyslog.test.log
EOF
)
        rsyslogServiceStart
	rlRun "logger -p local0.info 'flush test message1'" 0 "Logging the test message1"
	rlRun "logger -p local0.info 'flush test message2'" 0 "Logging the test message2"
	rlRun "logger -p local0.info 'flush test message3'" 0 "Logging the test message3"
	sleep 2
	# now check the log - there should be no messages since they are still in the buffer
	rlRun "grep 'flush test message1' /var/log/rsyslog.test.log" 1 "The message1 should not be in the log"
	rlRun "grep 'flush test message2' /var/log/rsyslog.test.log" 1 "The message2 should not be in the log"
	rlRun "grep 'flush test message3' /var/log/rsyslog.test.log" 1 "The message3 should not be in the log"
	rlRun "for i in \`seq 150\`; do logger -p local0.info 'dummy message to fill the buffer'; done" 0 "Sending 150 messages just to fill the buffer"  # this is not enough to fill default 4k buffer but enough for 1k buffer
	# not flush the buffer
	#rlRun "kill -s SIGHUP \`pidof rsyslogd\`" 0 "Send SIGHUP to rsyslogd to flush the buffer"
	rlRun "grep 'flush test message1' /var/log/rsyslog.test.log" 0 "The message1 should be in the log now"
	rlRun "grep 'flush test message2' /var/log/rsyslog.test.log" 0 "The message2 should be in the log now"
	rlRun "grep 'flush test message3' /var/log/rsyslog.test.log" 0 "The message3 should be in the log now"
    rlPhaseEnd
fi

    rlPhaseStartCleanup
        rlFileRestore
        rsyslogServiceRestore
        rlRun "rm -f /var/log/rsyslog.test.log /var/log/rsyslog.test.gz /tmp/rsyslog.rel-path-test.log"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
