#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1223566-RFE-imrelp-does-not-support-binding-to-a-specific
#   Description: Test for BZ#1223566 (RFE imrelp does not support binding to a specific)
#   Author: Stefan Dordevic <sdordevi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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
#rsyslogSyntax="NEW"
RUN=50

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "rsyslogServiceStop"
        sleep 3
        CleanupRegister 'rlRun "rlSEPortRestore"'
        rlRun "rlSEPortAdd tcp 5555 syslogd_port_t"
        rlRun "rlSEPortAdd tcp 6666 syslogd_port_t"
        rlRun "mkdir /var/log/test"
        TmpDir="/var/log/test"
        rlRun "pushd $TmpDir"
        CleanupRegister "rlRun 'rm -rf $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
    rlPhaseEnd

    rsyslogConfigIsNewSyntax && rlPhaseStartTest "\"ruleset\" in module directive (Sanity)" && {
        rsyslogPrepareConf
        rsyslogConfigAppend --begin "MODULES" /etc/rsyslog.conf <<EOF
module(load="imrelp" ruleset="relp")
module(load="omrelp")
EOF
        rsyslogConfigAppend --begin "RULES" /etc/rsyslog.conf <<EOF
ruleset(name="relp"){
action(type="omfile" file="$TmpDir/relp.log")
}

input(type="imrelp" port="5555")
input(type="imuxsock" socket="/var/run/rsyslog.socket" createpath="on")

local6.* action(type="omrelp" target="127.0.0.1" port="5555")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun 'runcon system_u:system_r:initrc_t:s0 bash -c "(/sbin/rsyslogd -n -d &> $TmpDir/rsyslog.log)&"'
        rlWaitForSocket -t 15 "5555"
        rlAssertNotGrep "parameter 'ruleset' not known" $TmpDir/rsyslog.log
        i=0
        while [[ $i -lt $RUN ]]; do
            rlRun "logger -u /var/run/rsyslog.socket -p local6.info RELP$i"
            sleep 0.2
            rlAssertGrep "RELP$i" $TmpDir/relp.log
            i=$[$i+1]
        done
        rlRun "while pidof rsyslogd &> /dev/null ; do kill `pidof rsyslogd` ; done" 0-255
        rlRun "rm -f /var/run/syslogd.pid"
    rlPhaseEnd; }

    rlPhaseStartTest "\"rulesets\" in action directives (Sanity+Multi rulesets)"
        rsyslogPrepareConf
        rsyslogConfigIsNewSyntax && {
        rsyslogConfigAppend --begin "MODULES" /etc/rsyslog.conf <<EOF
module(load="imrelp")
module(load="omrelp")
EOF

        rsyslogConfigAppend --begin "RULES" /etc/rsyslog.conf <<EOF
ruleset(name="relp1"){
action(type="omfile" file="$TmpDir/relp1.log")
}

ruleset(name="relp2"){
action(type="omfile" file="$TmpDir/relp2.log")
}

input(type="imrelp" port="5555" ruleset="relp1")
input(type="imrelp" port="6666" ruleset="relp2")

input(type="imuxsock" socket="/var/run/rsyslog.socket" createpath="on")
local6.* action(type="omrelp" target="127.0.0.1" port="5555")
local5.* action(type="omrelp" target="127.0.0.1" port="6666")
EOF
}
        rsyslogConfigIsNewSyntax || {
        rsyslogConfigAppend --begin "MODULES" /etc/rsyslog.conf <<EOF
\$ModLoad imrelp
\$ModLoad omrelp
\$ModLoad imtcp
EOF
        rsyslogConfigAppend --end "MODULES" /etc/rsyslog.conf <<EOF
\$AddUnixListenSocket /var/run/rsyslog.socket
EOF
        rsyslogConfigAppend --end "RULES" /etc/rsyslog.conf <<EOF
local6.* :omrelp:localhost:5555
local5.* :omrelp:localhost:6666

\$RuleSet relp1
local6.* /var/log/test/relp1.log

\$RuleSet relp2
local5.* /var/log/test/relp2.log

\$InputRELPServerBindRuleset relp1
\$InputRELPServerRun 5555

\$InputRELPServerBindRuleset relp2
\$InputRELPServerRun 6666
EOF
}
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun 'runcon system_u:system_r:initrc_t:s0 bash -c "(/sbin/rsyslogd -n -d &> $TmpDir/rsyslog.log)&"'
        rlWaitForSocket -t 15 "5555"
        rlWaitForSocket -t 15 "6666"
        rlAssertNotGrep "parameter 'ruleset' not known" $TmpDir/rsyslog.log
        i=0
        while [[ $i -lt $RUN ]]; do
            rlRun "logger -u /var/run/rsyslog.socket -p local6.info RELP$i"
            rlRun "logger -u /var/run/rsyslog.socket -p local5.info RELP$i"
            sleep 0.2
            rlAssertGrep "RELP$i" $TmpDir/relp1.log
            rlAssertGrep "RELP$i" $TmpDir/relp2.log
            i=$[$i+1]
        done
        rlRun "while pidof /usr/sbin/rsyslogd &> /dev/null ; do kill `pidof rsyslogd` ; sleep 2 ; done" 0-255
        [ -f /var/run/syslogd.pid ] && rlRun "rm -f /var/run/syslogd.pid"
    rlPhaseEnd

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
