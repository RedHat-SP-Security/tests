#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/basic-logging-facility
#   Description: Tests basic logging facility
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
        rlRun "rsyslogSetup"
        rlRun "mkdir /var/log/rsyslog_test" 0 "Create directory for test messages"
    rlPhaseEnd

    # test of facilities and priorities

    rlPhaseStartTest "Facility and level test"
        rsyslogPrepareConf
        rlRun "cat /etc/rsyslog.conf"
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do 
            for L in debug info notice warning err crit alert emerg; do
                echo "$F.$L  /var/log/rsyslog_test/${F}_${L}.log"
            done
        done | rsyslogConfigReplace "RULES" /etc/rsyslog.conf
        rlRun "cat /etc/rsyslog.conf"
        rsyslogServiceStart
        sleep 5
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                logger -p "$F.$L" "Test of message to facility $F with level $L"
            done
            sleep 1
        done
        rsyslogServiceStop
        sleep 5
        # now checking the logs
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                FILE="/var/log/rsyslog_test/${F}_${L}.log"
                rlAssertGrep "Test of message to facility $F with level $L" "$FILE"
            done
        done
        rlRun "rm -f /var/log/rsyslog_test/*"
    rlPhaseEnd


    # test of facility star operator

    rlPhaseStartTest "Facility star operator test"
        rsyslogPrepareConf
        for L in debug info notice warning err crit alert emerg; do
            echo "*.$L  /var/log/rsyslog_test/star_${L}.log"
        done | rsyslogConfigReplace "RULES" /etc/rsyslog.conf
        rsyslogServiceStart
        sleep 5
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                logger -p "$F.$L" "Test of message to facility $F with level $L"
            done
            sleep 1
        done
        rsyslogServiceStop
        sleep 5
        # now checking the logs
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                FILE="/var/log/rsyslog_test/star_${L}.log"
                rlAssertGrep "Test of message to facility $F with level $L" "$FILE"
            done
        done
        rlRun "rm -f /var/log/rsyslog_test/*"
    rlPhaseEnd

    # test of level star operator

    rlPhaseStartTest "Level star operator test"
        rsyslogPrepareConf
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do        
            echo "$F.*  /var/log/rsyslog_test/${F}_star.log"
        done | rsyslogConfigReplace "RULES" /etc/rsyslog.conf
        rsyslogServiceStart
        sleep 5
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                logger -p "$F.$L" "Test of message to facility $F with level $L"
            done
            sleep 1
        done
        rsyslogServiceStop
        sleep 5
        # now checking the logs
        for F in auth authpriv cron daemon lpr mail news syslog user uucp local0 local1 local2 local3 local4 local5 local6 local7; do
            for L in debug info notice warning err crit alert emerg; do
                FILE="/var/log/rsyslog_test/${F}_star.log"
                rlAssertGrep "Test of message to facility $F with level $L" "$FILE"
            done
        done
        rlRun "rm -f /var/log/rsyslog_test/*"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf /var/log/rsyslog_test" 0 "Deleting directory with test messages"
        rlRun "rsyslogCleanup"
        rsyslogServiceRestore
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
