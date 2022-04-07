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
    ld_elf=$(readelf -e /usr/bin/bash | grep interpreter | grep -o '\s\S*/lib[^ ]*ld[^ ]*\.so[^] ]*')
    ld_elf="${ld_elf:1}"
    ld_root=$(echo "$ld_elf" | sed -r 's|/usr||')
    ld_usr="/usr$ld_root"
    ld_real="$(realpath -e "$ld_elf")"
    ld=( $(echo -e "$ld_elf\n$ld_root\n$ld_usr" | sort | uniq ) )
  rlPhaseEnd; }

  rlPhaseStartTest "check kernel ld path" && {
    # created audit rules to the expected ld path is the last one
    # so the rule number will be greater then 1
    > /etc/fapolicyd/rules.d/00-ld-audit.rules
    ld_num=1
    for _ld in "${ld[@]}"; do
      [[ "$_ld" != "$ld_real" ]] && {
        echo "allow_audit perm=any all : path=$_ld" >> /etc/fapolicyd/rules.d/00-ld-audit.rules
        let ld_num++
      }
    done
    echo "allow_audit perm=any all : path=$ld_real" >> /etc/fapolicyd/rules.d/00-ld-audit.rules
    CleanupRegister --mark "rlRun 'fapStop'"
    rlRun "fapStart --debug"
    rlRun "$ld_real /usr/bin/ls"
    CleanupDo --mark
    rlRun -s "fapServiceOut | grep allow_audit"
    rlAssertGrep "rule=$ld_num dec=allow_audit" $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }

    rlJournalPrintText
rlJournalEnd
