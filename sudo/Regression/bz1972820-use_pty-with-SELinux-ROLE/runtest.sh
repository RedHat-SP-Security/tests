#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz500942-sudo-su-user-test
#   Description: It tests desired behaviour: sudo su - user
#   Author: Ales Marecek <amarecek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"

    CleanupRegister "rlRun 'sudoCleanup'"
    rlRun "sudoSetup"

    CleanupRegister "rlRun 'testUserCleanup'"
    rlRun "testUserSetup"

    rlRun "echo 'Defaults use_pty' >> /etc/sudoers"
    rlRun "echo '$testUser ALL=(ALL) ROLE=unconfined_r NOPASSWD: ALL' >> /etc/sudoers"
  rlPhaseEnd; }

  rlPhaseStartTest && {
    rlRun -s "expect" << EOE
      spawn su - $testUser
      expect_after {
        timeout { puts TIMEOUT; exit 3; }
        eof { puts EOF; exit 2; }
      }
      expect {\\\$} { send "id\r"; }
      expect {\\\$} { send "sudo -i\r"; }
      expect {#} { send "exit\r"; }
      expect {\\\$} { send "exit\r"; }
      expect eof
EOE
    rlAssertGrep "uid=[0-9]+\($testUser\)" $rlRun_LOG -Eq
    rlAssertNotGrep "cannot set terminal process group" $rlRun_LOG -iEq
    rlAssertNotGrep "-1" $rlRun_LOG -iEq
    rlAssertNotGrep "Inappropriate ioctl for device" $rlRun_LOG -iEq
    rlAssertNotGrep "no job control in this shell" $rlRun_LOG -iEq
    rm -rf $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }
