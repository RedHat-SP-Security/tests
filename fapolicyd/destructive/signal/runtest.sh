#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckRecommended; rlCheckRequired" || rlDie 'cannot continue'
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup /etc/rsyslog.conf"
    CleanupRegister "sessionCleanup"
    CleanupRegister 'rlRun "vmCleanup"'
    rlRun "vmSetup"
    CleanupRegister 'rlRun "sessionClose"'
    rlRun "sessionOpen"
  rlPhaseEnd

  rlGetTestState || rlDie "cannot continue"

  rlPhaseStartSetup "prepare a VM"
    CleanupRegister 'rlRun "destructiveCleanup"'
    rlRun "destructiveSetup" || rlDie "could not prepare the testing VM"
  rlPhaseEnd

  sessionRunTIMEOUT=30
  sessionExpectTIMEOUT=300
  CR=$'\r'

  [[ -n "$TMT_TEST_NAME" ]] && SIGNAL=${TMT_TEST_NAME##*/}

  SIGNAL=${SIGNAL:-SEGV}

  rlPhaseStartTest "send signal $SIGNAL" && {
    while :; do

      rlRun "sessionRun 'systemctl restart fapolicyd'"
      LogSleepWithProgress 5
      rlRun "sessionRun 'systemctl kill --signal $SIGNAL fapolicyd'"
      rlRun "sessionRun 'id'" || break

      rlRun "sessionRun 'systemctl -l --no-pager status fapolicyd'"

      break
    done
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd

  rlJournalPrintText

rlJournalEnd
