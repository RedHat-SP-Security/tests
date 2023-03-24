#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/trusted-execution
#   Description: The evaluator will configure fapolicyd to allow execution of executable based on path, hash and directory. The evaluator will then attempt to execute executables. The evaluator will ensure that the executables that are allowed to run has been executed and the executables that are not allowed to run will be denied.
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

CleanupRegisterCond() {
  if [[ -z "${IN_PLACE_UPGRADE}" ]]; then
   CleanupRegister "$@"
 else
   echo -n "Skipping cleanup register of '$1'" >&2
 fi
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
          CleanupRegisterCond 'rlRun "testUserCleanup"'
          rlRun "testUserSetup"
          CleanupRegisterCond 'rlRun "fapCleanup"'
          rlRun "fapSetup"
          set_config_option integrity 'sha256'
          echo 'int main(void) { return 0; }' > main.c
          exe1="${testUserHomeDir}/exe1"
          exe2="${testUserHomeDir}/exe2"
          rlRun "gcc main.c -o $exe1" 0 "Creating binary $exe1"
          rlRun "gcc main.c -g -o $exe2" 0 "Creating binary $exe2"
          rlRun "chmod a+rx $exe1 $exe2 ${testUserHomeDir}"
          CleanupRegisterCond "rlRun 'fapolicyd-cli -f delete $exe1'"
          rlRun "fapolicyd-cli -f add $exe1"
          CleanupRegisterCond 'rlRun "fapStop"'
          rlRun "fapStart"
        }
        [[ "${IN_PLACE_UPGRADE,,}" == "old" ]] && {
          declare -p exe1 exe2 testUser > /var/tmp/fapolicyd-trusted-execution-persistent-storage
          rlRun "rlServiceEnable fapolicyd"
        }
        [[ "${IN_PLACE_UPGRADE,,}" == "new" ]] && . /var/tmp/fapolicyd-trusted-execution-persistent-storage
    rlPhaseEnd

    rlPhaseStartTest "cached object" && {
      rlRun "rlServiceStatus fapolicyd"
      rlAssertGrep "^integrity = sha256" /etc/fapolicyd/fapolicyd.conf
      rlRun "su -c '$exe1' - $testUser" 0 "cache trusted binary $exe1"
      rlRun "su -c '$exe2' - $testUser" 126 "check untrusted binary $exe2"
      CleanupRegister --mark "rlRun 'cat ${exe1}a > ${exe1}; rm -f ${exe1}a' 0 'restore $exe1'"
      rlRun "cat $exe1 > ${exe1}a" 0 "backup $exe1"
      rlRun "cat $exe2 > $exe1" 0 "replace $exe1 with $exe2"
      rlRun "su -c '$exe1' - $testUser" 126 "the cached $exe1 is invalidated by the binary change"
      rlRun "su -c '$exe2' - $testUser" 126 "check untrusted binary $exe2"
      rlRun "fapServiceOut"
      [[ -z "${IN_PLACE_UPGRADE}" ]] && {
        rlRun "fapStop"
        rlRun "fapStart"
        rlRun "su -c '$exe1' - $testUser" 126 "the cached $exe1 is invalidated by the binary change"
        rlRun "su -c '$exe2' - $testUser" 126 "check untrusted binary $exe2"
        rlRun "fapServiceOut"
      }
      CleanupDo --mark
    rlPhaseEnd; }

    [[ -z "${IN_PLACE_UPGRADE}" ]] && {
    rlPhaseStartTest "live-update of trustdb" && {
      CleanupRegister --mark "rlRun 'fapolicyd-cli -f add $exe1'; rlRun 'fapolicyd-cli --update'"
      rlRun "fapolicyd-cli -f delete $exe1"
      rlRun "fapStart"
      rlRun "su -c '$exe1' - $testUser" 126 "untrusted binary $exe1"
      rlRun "fapolicyd-cli -f add $exe1"
      rlRun 'fapolicyd-cli --update'
      rlRun "sleep 20s"
      rlRun "fapServiceOut -t"
      rlRun "su -c '$exe1' - $testUser" 0 "trusted binary $exe1"
      rlRun "fapolicyd-cli -f delete $exe1"
      rlRun 'fapolicyd-cli --update'
      rlRun "sleep 20s"
      rlRun "fapServiceOut -t"
      rlRun "su -c '$exe1' - $testUser" 126 "utrusted binary $exe1"
      CleanupDo --mark
    rlPhaseEnd; }
    }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
