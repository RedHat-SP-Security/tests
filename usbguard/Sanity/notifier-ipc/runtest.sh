#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /usbguard/Sanity/notifier-ipc
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

PACKAGE="usbguard"

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
    rlRun "rlServiceStart usbguard"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
  rlPhaseEnd; }

  rlPhaseStartTest "$auditTARGET" && {
    rlRun -s "
    expect << EOE
      spawn ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $testUser@127.0.0.1 \"sleep 3; ps x; sleep 5\"
      expect assword { send \"$testUserPasswd\\\\r\" }
      expect eof
EOE"
    rlAssertGrep 'usbguard-notifier' $rlRun_LOG
    rm -f $rlRun_LOG
    rlRun "ps aux | grep usbguard[-]notifier"
    rlRun -s "rlServiceStatus usbguard"
    rlAssertNotGrep "IPC connection denied" $rlRun_LOG
    rlAssertGrep "running" $rlRun_LOG -iq
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
