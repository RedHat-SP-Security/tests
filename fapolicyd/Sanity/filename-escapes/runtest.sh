#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie 'cannot continue'
      rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
  rlPhaseEnd; }

  rlPhaseStartTest && {
    rlRun "touch './test file'"
    fapStart
    CleanupRegister "rlRun 'fapolicyd-cli -f delete \"./test file\"'"
    rlRun "fapolicyd-cli -f add './test file'"
    rlRun "fapolicyd-cli --update"
    fapStop
    rlRun -s "fapolicyd-cli --dump-db | grep 'test file'"
    rlAssertGrep "test file" $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
rlJournalPrintText
rlJournalEnd; }
