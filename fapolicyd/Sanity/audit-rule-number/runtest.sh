#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegisterCond 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    CleanupRegister 'rlRun "rlServiceRestore auditd"'
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/audit/rules.d"
    rlRun "echo \"-D\"\$'\\n'\"-w /etc/shadow -p w\" > /etc/audit/rules.d/audit.rules"
    rlRun "rlServiceStart auditd"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "fapStop"'
    rlRun "cp /usr/bin/ls $PWD/ls"
    rlRun "echo 'deny_audit perm=execute uid=$testUserUID : path=$PWD/ls' > /etc/fapolicyd/rules.d/00-audit_log.rules"
    for (( i=2; i<12; i++)); do
      rlRun "cp /usr/bin/ls $PWD/ls$i"
      rlRun "echo 'deny_audit perm=execute uid=$testUserUID : path=$PWD/ls$i' >> /etc/fapolicyd/rules.d/00-audit_log.rules"
    done
    rlRun "fapServiceStart"
    rlRun "chmod -R a+rx $PWD"
  rlPhaseEnd

  rlPhaseStartTest "support info message" && {
    rlRun "fapStart"
    rlRun "fapStop"
    rlRun -s "fapServiceOut"
    rlAssertGrep 'Rule number API supported yes' "$rlRun_LOG" -iq
  rlPhaseEnd; }

  rlPhaseStartTest "check the actual rule number" && {
    rlRun "fapServiceStart"
    rlRun "rlServiceStatus fapolicyd"
    STAMP=`LC_ALL=en_US.UTF-8 date "+%x %T"`
    sleep 1
    rlRun "su -c '$PWD/ls' - $testUser" 126
    rlRun -s "LC_ALL='en_US.UTF-8' ausearch --input-logs -m FANOTIFY -ts $STAMP"
    rlAssertGrep 'fan_info=1 ' "$rlRun_LOG"
    sleep 1
    STAMP=`LC_ALL=en_US.UTF-8 date "+%x %T"`
    sleep 1
    rlRun "su -c '$PWD/ls2' - $testUser" 126
    rlRun -s "LC_ALL='en_US.UTF-8' ausearch --input-logs -m FANOTIFY -ts $STAMP"
    rlAssertGrep 'fan_info=2 ' "$rlRun_LOG"
  rlPhaseEnd; }

  rlPhaseStartTest "check the actual rule number translation by the new audit" && {
    rlRun "fapServiceStart"
    rlRun "rlServiceStatus fapolicyd"
    STAMP=`LC_ALL=en_US.UTF-8 date "+%x %T"`
    sleep 1
    rlRun "su -c '$PWD/ls11' - $testUser" 126
    rlRun -s "LC_ALL='en_US.UTF-8' ausearch --input-logs -m FANOTIFY -ts $STAMP"
    rlAssertGrep 'fan_info=11 ' "$rlRun_LOG"
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
