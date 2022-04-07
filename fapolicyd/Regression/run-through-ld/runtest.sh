#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="fapolicyd"

rlJournalStart
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister "testUserCleanup"
    rlRun "testUserSetup"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /usr/bin/ls2"
    rlRun "cp /usr/bin/ls /usr/bin/ls2"
    CleanupRegister "rlRun 'fapServiceRestore'"
    rlRun "fapServiceStart"
  rlPhaseEnd; }

  rlPhaseStartTest "check rules expansion" && {
    rlRun "grep -R 'path= ' /usr/share/fapolicyd" 1-255
    ld=$(readelf -e /usr/bin/bash | grep interpreter | grep -o ' /lib[^ ]*ld[^ ]*\.so[^] ]*')
    rlRun "grep -R 'path=${ld:1}' /usr/share/fapolicyd"
    grep -R . /usr/share/fapolicyd/sample-rules/*.rules
  rlPhaseEnd; }

  rlPhaseStartTest "direct execution" && {
    rlRun "su -c '/usr/bin/ls -la' - $testUser"
    rlRun "su -c '/usr/bin/ls2 -la' - $testUser" 126
  rlPhaseEnd; }

  rlPhaseStartTest "ld_so execution" && {
    ld_so=`readelf -e /usr/bin/bash | grep interpreter | sed 's/.$//' | rev | cut -d " " -f 1 | rev`
    rlRun "su -c '$ld_so /usr/bin/ls -la' - $testUser" 126
    rlRun "su -c '$ld_so /usr/bin/ls2 -la' - $testUser" 126
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }

    rlJournalPrintText
rlJournalEnd
