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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

set_config_option() {
  local file=/etc/fapolicyd/fapolicyd.conf
  sed -i -r "/^$1 =/d"   $file
  [[ -n "$2" ]] && {
    echo           >> $file
    echo "$1 = $2" >> $file
  }
  echo "# grep$numbers -v -e '^\s*#' -e '^\s*$' \"$file\""
  grep$numbers -v -e '^\s*#' -e '^\s*$' "$file"
  echo "---"
}

ITER=${ITER:-34 21 13 8 5 3 2 1 1}
STEPS=${STEPS:-5}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "testUserCleanup"'
        rlRun "testUserSetup"
        CleanupRegister 'rlRun "fapCleanup"'
        rlRun "fapSetup"
        rlRun "cp /bin/ls /tmp/"
    rlPhaseEnd

    rlPhaseStartTest && {
      iter=( $ITER )
      steps=$STEPS
      while let steps--; do
        tcfChk "$iter iterations" && {
          CleanupRegister --mark 'rlRun "fapStop"'
          rlRun "fapStart --timeout 300 '$(command -v valgrind) /usr/sbin/'"
          iter=( $((iter+iter[1])) $iter )
          progressHeader $iter 1
          for ((i=1; i<=$iter; i++)); do
            progressDraw $i
            su -c 'ls' - $testUser >& /dev/null
            su -c '/tmp/ls' - $testUser >& /dev/null
          done
          progressFooter
          CleanupDo --mark
          rlRun -s "fapServiceOut | tail -n 30"
          val=$(cat $rlRun_LOG | tail -n 20 | grep -A 1000 "LEAK SUMMARY:" )
          leak_d+=( $(echo "$val" | grep -Eo "definitely lost: .* bytes" | tr -d ',' | grep -Eo '[0-9]+' ) )
          leak_i+=( $(echo "$val" | grep -Eo "indirectly lost: .* bytes" | tr -d ',' | grep -Eo '[0-9]+' ) )
          leak_p+=( $(echo "$val" | grep -Eo "possibly lost: .* bytes" | tr -d ',' | grep -Eo '[0-9]+' ) )
          rlLog "$(echo; declare -p messages leak_d leak_i leak_p)"
        tcfFin; }
      done
    rlPhaseEnd; }

    rlPhaseStartTest "evaluate" && {
      rlLog "$(echo; declare -p leak_d leak_i leak_p)"
      rlAssert0 "definitely lost leaked memory should not growth" $(( $(echo ${leak_d[*]} | tr ' ' '\n' | sort | uniq | wc -l ) - 1 ))
      rlAssert0 "indirectly lost leaked memory should not growth" $(( $(echo ${leak_i[*]} | tr ' ' '\n' | sort | uniq | wc -l ) - 1 ))
      rlAssert0 "possibly lost leaked memory should not growth" $(( $(echo ${leak_p[*]} | tr ' ' '\n' | sort | uniq | wc -l ) - 1 ))
    rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
