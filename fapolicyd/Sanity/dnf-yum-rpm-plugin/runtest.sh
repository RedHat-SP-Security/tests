#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: a sanity for dnf/yum and rpm plugin
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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

PACKAGE="fapolicyd"

spaces=${spaces:-false}

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rm -rf /root/rpmbuild"'
    fapPrepareTestPackages
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "fapStop"'
    rlRun "fapStart"
  rlPhaseEnd


  for comm in dnf yum; do
    which $comm > /dev/null 2>&1 && rlPhaseStartTest "$comm" && {
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
      rlRun "fapStart"
      rlRun "$comm install -y ${fapTestPackage[0]}"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep $fapTestProgram"
      rlRun "fapStart"
      rlRun "$comm install -y ${fapTestPackage[1]}"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep $fapTestProgram"
      rlRun "fapStart"
      rlRun "$comm remove -y fapTestPackage"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
      rlRun "fapStart"
    rlPhaseEnd; }
  done

  rlPhaseStartTest "rpm" && {
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
    rlRun "fapStart"
    rlRun "rpm -ivh ${fapTestPackage[0]}"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep $fapTestProgram"
    rlRun "fapStart"
    rlRun "rpm -Uvh ${fapTestPackage[1]}"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep $fapTestProgram"
    rlRun "fapStart"
    rlRun "rpm -evh fapTestPackage"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
    rlRun "fapStart"
  rlPhaseEnd; }

  rlPhaseStartTest "rpm-plugin restart during update" && {
    #rlRun "rpm -ivh ${fapTestPackage[2]}"
    rlRun "fapolicyd-cli -D | grep fapTestProgram" 1-255
    rlRun "yum install -y ${fapTestPackage[2]}"
    rlRun "fapolicyd-cli -D | grep fapTestProgram" 0
    rlRun -s "fapServiceOut"
    rlAssertGrep "/usr/local/bin/fapTestProgram" $rlRun_LOG
    rlRun "rpm -evh fapTestPackage"
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
