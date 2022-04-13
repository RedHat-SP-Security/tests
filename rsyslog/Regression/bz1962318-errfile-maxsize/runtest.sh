#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Regression/bz1962318-errfile-maxsize
#   Author: Sergio Arroutbi <sarroutb@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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

PACKAGE="rsyslog"
RSYSLOG_ERRFILE=$(mktemp /var/log/tmp.XXXXXXXXXX)
RSYSLOG_ERRFILE_MAXSIZE=1234
NUM_LOGS=200

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "rlImport --all" || rlDie "cannot continue"
        rlRun "rsyslogSetup"
        rlLog "Updating /etc/rsyslog.conf"
        rsyslogConfigAppend "RULES" <<EOF
action(type="omfwd" target="1.2.3.4" port="1234" Protocol="tcp"
       action.errorfile="${RSYSLOG_ERRFILE}" action.errorfile.maxsize="${RSYSLOG_ERRFILE_MAXSIZE}")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        sleep 3
        rlRun "rsyslogServiceStatus"
    rlPhaseEnd

    rlPhaseStartTest "Ensure initially empty error file size limits to ${RSYSLOG_ERRFILE_MAXSIZE}"
        for (( counter=0; counter<${NUM_LOGS}; counter++ ))
        do
             logger "Message:[${counter}]"
        done
        rlAssertExists ${RSYSLOG_ERRFILE}
        size=$(ls -l ${RSYSLOG_ERRFILE} | awk {'print $5'})
        rlAssertEquals "Checking initally empty error file:${RSYSLOG_ERRFILE} has size:${RSYSLOG_ERRFILE_MAXSIZE}" "${size}" "${RSYSLOG_ERRFILE_MAXSIZE}"
    rlPhaseEnd

    rlPhaseStartTest "Ensure non initially empty error file size limits to ${RSYSLOG_ERRFILE_MAXSIZE}"
        rlSESetTimestamp
        rlServiceStop rsyslog
        # Dump some info to error file and check after rebooting it also does not write more than expected
        dd if=/dev/urandom of=${RSYSLOG_ERRFILE} bs=1 count=$((RSYSLOG_ERRFILE_MAXSIZE-100))
        rlServiceStart rsyslog
        for (( counter=0; counter<${NUM_LOGS}; counter++ ))
        do
             logger "Message:[${counter}]"
        done
        rlAssertExists ${RSYSLOG_ERRFILE}
        size=$(ls -l ${RSYSLOG_ERRFILE} | awk {'print $5'})
        rlAssertEquals "Checking not initally empty error file:${RSYSLOG_ERRFILE} has size:${RSYSLOG_ERRFILE_MAXSIZE}" "${size}" "${RSYSLOG_ERRFILE_MAXSIZE}"
        rlRun "rlSEAVCCheck --expect name_connect"
    rlPhaseEnd

    rlPhaseStartCleanup
        rm -fvr ${RSYSLOG_ERRFILE}
        rlFileRestore
        rlRun "rsyslogCleanup"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
