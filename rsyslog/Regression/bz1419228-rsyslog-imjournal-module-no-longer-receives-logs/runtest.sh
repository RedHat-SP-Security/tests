#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1419228-rsyslog-imjournal-module-no-longer-receives-logs
#   Description: Test for BZ#1419228 (rsyslog imjournal module no longer receives logs)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

MESSAGES=500
cursor=0

function log_messages() {
  rlLog "sending $MESSAGES messages"
  PREFIX=$1
  for I in `seq $MESSAGES`; do
    logger "$PREFIX $((cursor++))."
  done

}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlCheckMakefileRequires" || rlFail "not all requirements are satisfied"
        rlRun "rlImport --all" || rlDie "cannot continue"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "useradd -m bz1419228usr1"
        rlRun "useradd -m bz1419228usr2"
        rlFileBackup /etc/systemd/journald.conf
        rlRun "rsyslogSetup"
        rlRun "rlServiceStop rsyslog"
        rlRun "rsyslogPrepareConf"
        sleep 3
    rlPhaseEnd

    rlPhaseStartTest "bz1419228" && {
        rlLogInfo "log test messages using the volatile journald storage"
        rlRun "rlServiceStop systemd-journald"  # actual restart
        rlRun "sed -i 's/.*Storage=.*/Storage=auto/' /etc/systemd/journald.conf"
        rlRun "rm -rf /var/log/journal"   # this is important
        rlRun "rlServiceStart systemd-journald"  # actual restart
        rlRun "rlServiceStart rsyslog"
        lines=$(( `cat /var/log/messages | wc -l` + 1 ))
        log_messages "volatile storate test message"
        sleep 3
        rlAssertEquals "Test if all $MESSAGES were delivered" $MESSAGES `tail -n +$lines /var/log/messages | grep "volatile storate test message" | wc -l`

        rlLogInfo "switch to the persistent journald storage"
        rlRun "sed -i 's/.*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf"
        rlRun "mkdir /var/log/journal"
        rlRun "rlServiceStart systemd-journald"  # actual restart
        rlRun -s "systemctl status systemd-journald"
        #rlAssertGrep "systemd-journal.*Permanent journal" $rlRun_LOG -E
        sleep 3
        lines=$(( `cat /var/log/messages | wc -l` + 1 ))
        log_messages "persistent storate test message"
        sleep 3
        rlAssertEquals "Test if all $MESSAGES were delivered" $MESSAGES `tail -n +$lines /var/log/messages | grep "persistent storate test message" | wc -l`
    rlPhaseEnd; }

    rlPhaseStartTest "bz1538372, bz1545580, bz1543992, bz1544394, bz1545582" && {
        rlRun "rsyslogServiceStop"
        MESSAGES=30
        cursor=0
        lines=$(( `cat /var/log/messages | wc -l` + 1 ))
        rlLogInfo "switch to the persistent journald storage"
        rlRun "rlServiceStop systemd-journald"  # actual restart
        rlRun "sed -i 's/.*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf"
        rlRun "cat /etc/systemd/journald.conf"
        rlRun "rm -rf /var/log/journal"   # this is important
        rlRun "mkdir -p /var/log/journal"
        rlRun "rlServiceStart systemd-journald"  # actual restart
        rlRun -s "systemctl status systemd-journald"
        #rlAssertGrep "systemd-journal.*Permanent journal" $rlRun_LOG -E
        rlRun "rsyslogConfigReplace 'MODLOAD IMJOURNAL' << 'EOF'
module(load=\"imjournal\" StateFile=\"imjournal.state\" WorkAroundJournalBug=\"on\")
EOF"
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun "sleep 15"
        rlRun "systemctl --no-page status rsyslog"
        log_messages "storage test message"
        rlRun "sleep 3s"
        rlAssertEquals "Test if all $MESSAGES were delivered" $MESSAGES `tail -n +$lines /var/log/messages | grep "storage test message" | wc -l`
        rlRun "systemctl kill -s SIGUSR2 systemd-journald" 0 "rotate journal"
        rlRun "sleep 3"
        log_messages "storage test message"
        rlRun "sleep 15s"
        rlAssertEquals "Test if all $((MESSAGES*2)) were delivered" $((MESSAGES*2)) `tail -n +$lines /var/log/messages | grep "storage test message" | wc -l`
        rlRun "tail -n +$lines /var/log/messages"
    rlPhaseEnd; }

    rlPhaseStartCleanup
        rlFileSubmit /var/log/messages
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlFileRestore
        rlRun "userdel -r --force bz1419228usr1"
        rlRun "userdel -r --force bz1419228usr2"
        rlRun "rlServiceRestore systemd-journald"
        rlRun "rsyslogCleanup"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
