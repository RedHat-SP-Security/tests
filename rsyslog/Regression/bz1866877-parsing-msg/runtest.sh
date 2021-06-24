#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Regression/bz1866877-parsing-msg
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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

. /usr/share/beakerlib/beakerlib.sh || exit 1
PACKAGE="rsyslog"

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" || rlDie 'cannot continue'
    CleanupRegister 'rlRun "RpmSnapshotRevert"; rlRun "RpmSnapshotDiscard"'
    rlRun "RpmSnapshotCreate"
    rlRun "epel yum install -y Lmod ansible"
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    cat > playbook.yaml <<EOF
---
- hosts: localhost
  tasks:
    - name: "EL8: Use Lmod"
      alternatives:
        name: modules.sh
        path: /usr/share/lmod/lmod/init/profile
      become: yes
EOF
    rsyslogPrepareConf
    rsyslogServiceStart
    rsyslogResetLogFilePointer /var/log/messages
  rlPhaseEnd

  rlPhaseStartTest && {
    rlRun "logger 'test message'"
    rlRun "ansible-playbook ./playbook.yaml"
    rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
    rlAssertGrep "test message" $rlRun_LOG
    rlAssertNotGrep "unexpected length" $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
