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

clearACLfolder() {
  rlRun "rm -rf /etc/usbguard/IPCAccessControl.d/*"
}

showACLfolder() {
  ls -1 /etc/usbguard/IPCAccessControl.d/* | while read -r line; do
    echo "$line:"
    cat $line
  done
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
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard"
    CleanupRegister 'rlRun "rlServiceRestore usbguard"'
    CleanupRegister "rlRun 'testUserCleanup'"
    rlRun "testUserSetup --fast 6"
  rlPhaseEnd; }

  rlPhaseStartTest "inclusive permissions propagation" && {
    clearACLfolder
    CleanupRegister --mark "rlRun 'usermod -G \"\" ${testUser[0]}'"
    rlRun "usermod -aG ${testUserGroup[1]} ${testUser[0]}"
    rlRunAs ${testUser[0]} "id"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUser[0]} --device list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUserGroup[0]} -g --policy list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 0
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUserGroup[1]} -g --parameters list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 0
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 0
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "inclusive permissions propagation (UID/GID)" && {
    clearACLfolder
    CleanupRegister --mark "rlRun 'usermod -G \"\" ${testUser[0]}'"
    rlRun "usermod -aG ${testUserGroup[1]} ${testUser[0]}"
    rlRunAs ${testUser[0]} "id"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUserUID[0]} --device list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUserGID[0]} -g --policy list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 0
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 1-255
    rlRun "usbguard add-user ${testUserGID[1]} -g --parameters list"
    rlRun "showACLfolder"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 0
    rlRunAs ${testUser[0]} 'usbguard get-parameter InsertedDevicePolicy' 0
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "separate users" && {
    clearACLfolder
    rlRun "usbguard add-user ${testUser[0]} --device list"
    rlRun "usbguard add-user ${testUser[1]} --policy list"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-rules' 0
  rlPhaseEnd; }

  rlPhaseStartTest "separate groups" && {
    clearACLfolder
    rlRun "usbguard add-user ${testUserGroup[0]} -g --device list"
    rlRun "usbguard add-user ${testUserGroup[1]} -g --policy list"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-rules' 0
  rlPhaseEnd; }

  rlPhaseStartTest "primary group permissions" && {
    clearACLfolder
    rlRun "usbguard add-user ${testUserGroup[2]} -g --device list"
    CleanupRegister --mark "
      rlRun 'usermod -g ${testUserGroup[0]} ${testUser[0]}'
      rlRun 'usermod -g ${testUserGroup[1]} ${testUser[1]}'
    "
    rlRun "usermod -g ${testUserGroup[2]} ${testUser[0]}"
    rlRun "usermod -g ${testUserGroup[2]} ${testUser[1]}"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-devices' 0
    rlRunAs ${testUser[1]} 'usbguard list-rules' 1-255
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "supplementary group permissions" && {
    clearACLfolder
    rlRun "usbguard add-user ${testUserGroup[2]} -g --device list"
    CleanupRegister --mark "
      rlRun 'usermod -G \"\" ${testUser[0]}'
      rlRun 'usermod -G \"\" ${testUser[1]}'
    "
    rlRun "usermod -aG ${testUserGroup[2]} ${testUser[0]}"
    rlRun "usermod -aG ${testUserGroup[2]} ${testUser[1]}"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-devices' 0
    rlRunAs ${testUser[1]} 'usbguard list-rules' 1-255
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartTest "mix of primary and supplementary groups permissions" && {
    clearACLfolder
    rlRun "usbguard add-user ${testUserGroup[4]} -g --device list"
    rlRun "usbguard add-user ${testUserGroup[5]} -g --policy list"
    CleanupRegister --mark "
      rlRun 'usermod -g ${testUserGroup[0]} ${testUser[0]}'
      rlRun 'usermod -g ${testUserGroup[1]} ${testUser[1]}'
    "
    rlRun "usermod -g ${testUserGroup[4]} ${testUser[0]}"
    rlRun "usermod -g ${testUserGroup[4]} ${testUser[1]}"
    CleanupRegister "
      rlRun 'usermod -G \"\" ${testUser[2]}'
      rlRun 'usermod -G \"\" ${testUser[3]}'
    "
    rlRun "usermod -aG ${testUserGroup[5]} ${testUser[2]}"
    rlRun "usermod -aG ${testUserGroup[5]} ${testUser[3]}"
    rlRun "rlServiceStart 'usbguard'"
    rlRunAs ${testUser[0]} 'usbguard list-devices' 0
    rlRunAs ${testUser[0]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[1]} 'usbguard list-devices' 0
    rlRunAs ${testUser[1]} 'usbguard list-rules' 1-255
    rlRunAs ${testUser[2]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[2]} 'usbguard list-rules' 0
    rlRunAs ${testUser[3]} 'usbguard list-devices' 1-255
    rlRunAs ${testUser[3]} 'usbguard list-rules'
    CleanupDo --mark
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
