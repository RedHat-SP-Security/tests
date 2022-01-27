#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /usbguard/Sanity/IPCACL
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlRunAs() {
  local user="$1" command="$2"
  shift 2
  rlRun "su - $user -c '$command'" "$@"
}

CondCleanupRegister() {
  [[ -z "$IN_PLACE_UPGRADE" ]] && CleanupRegister "$@" || echo -n "Skipping cleanup register of '$1'" >&2
}

rlRunAs() {
  local user="$1" command="$2"
  shift 2
  rlRun "su - $user -c '$command'" "$@"
}

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
      CondCleanupRegister 'rlRun "rlFileRestore"'
      rlRun "rlFileBackup --clean /etc/sudoers.d/"
      CondCleanupRegister "rlRun 'testUserCleanup'"
      rlRun "testUserSetup 2"
      
      # testUser[0] - member of wheel
      # testUser[1] - can run id as root
      
      rlRun "usermod -aG wheel $testUser"
      rlRun "echo '${testUser[1]} ALL=(ALL) ALL' > /etc/sudoers.d/${testUser[1]}"
      rlRun "echo 'Defaults !authenticate' > /etc/sudoers.d/nopasswd"
    }
    [[ "${IN_PLACE_UPGRADE,,}" == "old" ]] && declare -p testUser testUserGroup > /var/tmp/sudo-sudoers-sanity-persistent-storage
    [[ "${IN_PLACE_UPGRADE,,}" == "new" ]] && . /var/tmp/sudo-sudoers-sanity-persistent-storage
  rlPhaseEnd; }

  rlPhaseStartTest "member of wheel group" && {
    rlRunAs $testUser "sudo id" -s
    rlAssertGrep 'uid=0' $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartTest "specific user can run command as root" && {
    rlRunAs ${testUser[1]} "sudo id" -s
    rlAssertGrep 'uid=0' $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
