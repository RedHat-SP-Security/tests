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
      rlRun "rlFileBackup --clean /etc/usbguard"
      CondCleanupRegister 'rlRun "rlServiceRestore usbguard"'
      CondCleanupRegister "rlRun 'testUserCleanup'"
      rlRun "testUserSetup 5"
      
      # testUser[0] - member of wheel
      # testUser[1] - can list devices
      # testUser[2] - can list policy
      # testUserGroup[3] - can list devices
      # testUserGroup[4] - can list policy
      
      rlRun "usermod -aG wheel $testUser"
      rlRun "usbguard add-user ${testUser[1]} --device list"
      rlRun "usbguard add-user ${testUser[2]} --policy list"
      rlRun "usbguard add-user ${testUserGroup[3]} -g --device list"
      rlRun "usbguard add-user ${testUserGroup[4]} -g --policy list"
      
      rlRun "rlServiceEnable usbguard"
      rlRun "rlServiceStart usbguard"
    }
    [[ "${IN_PLACE_UPGRADE,,}" == "old" ]] && declare -p testUser testUserGroup > /var/tmp/usbguard-IPCACL-persistent-storage
    [[ "${IN_PLACE_UPGRADE,,}" == "new" ]] && . /var/tmp/usbguard-IPCACL-persistent-storage
  rlPhaseEnd; }

  rlPhaseStartTest "the service is running" && {
    rlRun "rlServiceStatus usbguard"
  rlPhaseEnd; }

  rlPhaseStartTest "member of wheel group" && {
    rlRunAs $testUser "usbguard list-devices"
    rlRunAs $testUser "usbguard list-rules"
  rlPhaseEnd; }

  rlPhaseStartTest "specific user can list devices" && {
    rlRunAs ${testUser[1]} "usbguard list-devices"
    rlRunAs ${testUser[2]} "usbguard list-devices" 1-255
  rlPhaseEnd; }

  rlPhaseStartTest "specific user can list rules" && {
    rlRunAs ${testUser[1]} "usbguard list-rules" 1-255
    rlRunAs ${testUser[2]} "usbguard list-rules"
  rlPhaseEnd; }

  rlPhaseStartTest "member of specific group can list devices" && {
    rlRunAs ${testUser[3]} "usbguard list-devices"
    rlRunAs ${testUser[4]} "usbguard list-devices" 1-255
  rlPhaseEnd; }

  rlPhaseStartTest "member of specific group can list rules" && {
    rlRunAs ${testUser[3]} "usbguard list-rules" 1-255
    rlRunAs ${testUser[4]} "usbguard list-rules"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
