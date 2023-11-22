#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /fapolicyd/Sanity/integrity-advanced
#   Description: Test for BZ#1887451 (Rebase FAPOLICYD to the latest upstream version)
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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

# Include Beaker environment
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

# $1 - command
# $2 - expected result, default 0
uRun() {
  rlRun "timeout 2 su - $testUser -c \"$1\"" ${2:-0}
}

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    rlRun "chmod -R a+rwx $TmpDir"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    CleanupRegister 'fapCleanup'
    rlRun "fapSetup"
    fapPrepareTestPackages
    CleanupRegister 'rlRun "rpm -e fapTestPackage"'
    rlRun "rpm -ivh ${fapTestPackage[1]}"
    cat $fapTestProgram > fapTestProgram
    rlRun "rpm -e fapTestPackage"
  rlPhaseEnd; }

  rlPhaseStartTest "functionality check" && {
    rlRun "cp /bin/ls ./"
    CleanupRegister --mark 'rlRun "fapStop"'
    rlRun "fapStart --debug"
    uRun "$TmpDir/ls" 126
    CleanupDo --mark
    rlRun "fapServiceOut -t"
  rlPhaseEnd; }

  rlPhaseStartTest "integrity none" && {
    # any binary in the trusted path should work
    rlRun "rpm -ivh --force $fapTestPackage"
    set_config_option integrity 'none'
    CleanupRegister --mark 'rlRun "fapStop"'
    rlRun "fapStart"
    uRun "$fapTestProgram" 124
    rlRun "cat fapTestProgram > $fapTestProgram"
    uRun "$fapTestProgram" 124
    rlRun "cat /bin/ls > $fapTestProgram"
    uRun "$fapTestProgram"
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "integrity ima" && {
    rlRun "rpm -ivh --force $fapTestPackage"
    HASH=($(sha256sum ${fapTestProgram}))
    sleep 5
    set_config_option integrity 'IMA'
    CleanupRegister --mark 'rlRun "fapStop"'
    #label IMA to all files file attr
    find / -fstype ext4 -type f -uid 0 -exec dd if='{}' of=/dev/null count=0 status=none \;
    rlRun "fapStart --debug"
    uRun "$fapTestProgram" 124
    rlRun -s "getfattr -m - -d -e hex /usr/local/bin/fapTestProgram | grep ${HASH}"
    rlRun "cat fapTestProgram > $fapTestProgram"
    uRun "$fapTestProgram" 126
    rlRun "cat /bin/ls > $fapTestProgram"
    uRun "$fapTestProgram" 126
    bash
    CleanupDo --mark
    rlRun "fapServiceOut -t"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
