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
      CleanupRegister --mark "rlRun '$comm remove -y fapTestPackage'"
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
      CleanupDo --mark
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
      rlRun "fapStart"
    rlPhaseEnd; }
  done

  rlPhaseStartTest "rpm" && {
    CleanupRegister --mark "rlRun 'rpm -evh fapTestPackage'"
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
    CleanupDo --mark
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep $fapTestProgram" 1-255
    rlRun "fapStart"
  rlPhaseEnd; }

  rlPhaseStartTest "rpm-plugin restart during update" && {
    CleanupRegister --mark 'rlRun "rm -rf ~/rpmbuild"'

    fapPrepareTestPackageContent
    rlRun "sed -i -r 's/(Version:).*/\1 3/' ~/rpmbuild/SPECS/fapTestPackage.spec"
    rlRun "sed -i -r 's/fapTestProgram/\03/' ~/rpmbuild/SOURCES/fapTestProgram.c"
    rlRun "sed -i -r 's/#scriptlet/%pretrans\necho \"restart fapolicyd\"; systemctl restart fapolicyd; echo \"wait 10s\"; sleep 10; echo \"done\"/' ~/rpmbuild/SPECS/fapTestPackage.spec"
    rlRun "rpmbuild -ba ~/rpmbuild/SPECS/fapTestPackage.spec"
    pkg=$(ls -1 ~/rpmbuild/RPMS/*/fapTestPackage-*)

    rlRun "fapolicyd-cli -D | grep fapTestProgram" 1-255
    CleanupRegister "rlRun 'rpm -evh fapTestPackage'"
    rlRun -s "yum install -y $pkg"
    rlRun "fapolicyd-cli -D | grep fapTestProgram" 0
    rlRun -s "fapServiceOut"
    rlAssertGrep "/usr/local/bin/fapTestProgram" $rlRun_LOG
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "rpm-plugin stop during update" && {
    CleanupRegister --mark 'rlRun "rm -rf ~/rpmbuild"'
    CleanupRegister 'rlRun "fapStart"'

    fapPrepareTestPackageContent
    rlRun "cp ~/rpmbuild/SPECS/fapTestPackage.spec ~/rpmbuild/SPECS/fapTestPackage2.spec"
    rlRun "sed -i -r 's/(Name:).*/\1 fapTestPackage2/' ~/rpmbuild/SPECS/fapTestPackage2.spec"
    rlRun "sed -i -r 's/(Version:).*/\1 1/' ~/rpmbuild/SPECS/fapTestPackage2.spec"
    rlRun "sed -i -r 's|/fapTestProgram$|\02|' ~/rpmbuild/SPECS/fapTestPackage2.spec"
    rlRun "sed -i -r 's/#scriptlet/%pretrans\necho \"stoping fapolicyd\"; systemctl stop fapolicyd; echo \"wait 10s\"; sleep 10; echo \"done\"/' ~/rpmbuild/SPECS/fapTestPackage2.spec"
    rlRun "rpmbuild -ba ~/rpmbuild/SPECS/fapTestPackage2.spec"
    pkg=$(ls -1 ~/rpmbuild/RPMS/*/fapTestPackage*)

    rlRun "fapStart"

    CleanupRegister --mark "rlRun 'rpm -evh fapTestPackage2'"
    rlRun -s "/usr/bin/time -f 'time:%e' yum install -y $pkg"
    t1=$(grep 'time:' $rlRun_LOG | sed -r 's/time://;s/\.[0-9]{2}//')
    CleanupDo --mark

    rlRun "fapStart"

    CleanupRegister --mark "rlRun 'rpm -evh fapTestPackage fapTestPackage2'"
    rlRun -s "/usr/bin/time -f 'time:%e' yum install -y $pkg ${fapTestPackage[1]}"
    t2=$(grep 'time:' $rlRun_LOG | sed -r 's/time://;s/\.[0-9]{2}//')
    CleanupDo --mark

    rlRun "compare_with_tolerance $t1 $t2 10"

    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "rpm-plugin pipe without the service" && {
    CleanupRegister --mark 'rlRun "fapStart"'
    rlRun "fapStop"
    rlRun "mkfifo /run/fapolicyd/fapolicyd.fifo"
    rlRun "chmod 660 /run/fapolicyd/fapolicyd.fifo"
    rlRun "chown :fapolicyd /run/fapolicyd/fapolicyd.fifo"
    CleanupRegister "rlRun 'rpm -evh fapTestPackage'"
    rlRun "yum install -y ${fapTestPackage[0]}"
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
