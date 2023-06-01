#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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
#   Boston, MA 02110-1$_p01, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckRecommended; rlCheckRequired" || rlDie "cannot continue"
    rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
  rlPhaseEnd; }

  rlPhaseStartTest "default configuration contains the UsePid=\"system\"" && {
    rlAssertGrep 'UsePid="system"' /var/tmp/library_rsyslog_basic_orig_config -iq
  rlPhaseEnd; }

  _up=1
  while [[ -d /proc/${_up} ]]; do
    (( _up++ ))
  done

  _p=1
  rlPhaseStartTest "root, used PID, usepid=syslog" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="syslog")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "logger -t testd --id=$_p testmessage"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertGrep "testd\[$_p\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "root, used PID, usepid=system" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="system")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "logger -t testd --id=$_p testmessage"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertGrep "testd\[$_p\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "root, unused PID, usepid=syslog" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="syslog")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "logger -t testd --id=$_up testmessage"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertGrep "testd\[$_up\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "root, unused PID, usepid=system" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="system")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "logger -t testd --id=$_up testmessage"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertNotGrep "testd\[$_up\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "non-root, used PID, usepid=syslog" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="syslog")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "su -c 'logger -t testd --id=$_p testmessage' - $testUser"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertGrep "testd\[$_p\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "non-root, used PID, usepid=system" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="system")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "su -c 'logger -t testd --id=$_p testmessage' - $testUser"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertNotGrep "testd\[$_p\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "non-root, unused PID, usepid=syslog" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="syslog")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "su -c 'logger -t testd --id=$_up testmessage' - $testUser"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertGrep "testd\[$_up\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartTest "non-root, unused PID, usepid=system" && {
    rsyslogConfigReplace "MODLOAD IMJOURNAL" <<EOF
module(load="imjournal" StateFile="imjournal.state" UsePid="system")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rsyslogServiceStart"
    rsyslogResetLogFilePointer /var/log/messages
    rlRun "su -c 'logger -t testd --id=$_up testmessage' - $testUser"
    sleep 1
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep 'testmessage' $rlRun_LOG
    rlAssertNotGrep "testd\[$_up\]" $rlRun_LOG -Eq
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd

  rlJournalPrintText
rlJournalEnd; }
