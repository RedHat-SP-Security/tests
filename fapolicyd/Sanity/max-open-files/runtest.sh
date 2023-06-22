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
      rlRun "rlCheckRecommended; rlCheckRequired" || rlDie 'cannot continue'
      rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
      CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
      CleanupRegister 'rlRun "popd"'
      rlRun "pushd $TmpDir"
      CleanupRegister 'rlRun "fapCleanup"'
      rlRun "fapSetup"
      rlRun "fapStart"
    rlPhaseEnd

    rlPhaseStartTest && {
      rlRun -s 'cat /proc/$(pidof fapolicyd)/limits | grep -i "Max open files"'
      [[ "$(cat "$rlRun_LOG")" =~ [^0-9]+([0-9]+)[^0-9]+([0-9]+) ]] && {
        soft=${BASH_REMATCH[1]}
        hard=${BASH_REMATCH[2]}
      }
      rlAssertGreaterOrEqual 'soft limit is big enought' $soft 16384
      rlAssertGreaterOrEqual 'soft limit is big enought' $hard 524288
    rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
