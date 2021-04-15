#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/udpspoof-module-test
#   Description: basic testing of rsyslog udpspoof module
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
PACKAGE="${COMPONENT:-$PACKAGE}"
TEST_FILE="/var/log/rsyslog.test-udpspoof"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister "rlRun 'popd'"
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rm -f /var/log/rsyslog.test-*"'
        rsyslogPrepareConf
        rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'OMUDPSPOOF-MODLOAD')
        rsyslogConfigAddTo --begin "RULES"  < <(rsyslogConfigCreateSection 'OMUDPSPOOF-RULES')
    rlPhaseEnd

    # SETUP: Receive TCP messages on port 514 and forward those messages
    # to host(localhost) via omudpspoof module.
    # In order to test it, we use imudp to receive syslog message via UDP from the omudpspoof module.
    rlPhaseStartSetup "Setup test environment" && {
        rsyslogConfigReplace 'OMUDPSPOOF-MODLOAD' <<'EOF'
module(load="imudp")
module(load="imtcp")
module(load="omudpspoof")
EOF
        rsyslogConfigReplace 'OMUDPSPOOF-RULES' <<'EOF'
input(type="imudp" port="514" ruleset="rsImudp")
template(name="outfmt" type="string" string="%msg%\n")

ruleset(name="rsImudp") {
    action( name="UDPOUT"
        type="omfile"
        file="/var/log/rsyslog.test-udpspoof"
        template="outfmt")
}

# this listener is for message generation by the test framework!
input(type="imtcp" port="514" ruleset="rsImtcp")

template(name="spoofaddr" type="string" string="127.0.0.1")
ruleset(name="rsImtcp") {
    action( name="MTUTEST"
        type="omudpspoof"
        Target="127.0.0.1"
        Port="514"
        SourceTemplate="spoofaddr"
        mtu="1500")
}
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "restorecon -Rv /var/log"
        rlRun "rm -rf /var/log/rsyslog.test-udpspoof"
        rlRun "rsyslogServiceStart"
    rlPhaseEnd; }

    # TEST: Send TCP packets to 127.0.0.1:514
    rlPhaseStartTest "rsyslog-udpspoof test" && {
        rlRun "systemctl status -l rsyslog"
        rlRun "cat /etc/rsyslog.conf"
        for i in {0..15}; do
            rlRun "echo 'Sending a small text message with content of: rsyslog-udspoof test multiple times' > /dev/tcp/127.0.0.1/514" 0 "Send tcp packets to 127.0.0.1::514"
        done
        sleep 1
        rlAssertGrep "rsyslog-udspoof test" "/var/log/rsyslog.test-udpspoof"
    rlPhaseEnd; }

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

