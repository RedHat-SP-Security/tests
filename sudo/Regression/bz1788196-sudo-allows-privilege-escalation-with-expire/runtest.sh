#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz1788196-sudo-allows-privilege-escalation-with-expire
#   Description: Test for BZ#1788196 (sudo allows privilege escalation with expire)
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="sudo"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    CleanupRegister 'rlRun "sudoCleanup"'
    rlRun "sudoSetup"
    rlRun "echo '$testUser ALL=(ALL) ALL' >> /etc/sudoers"
    rlRun "chage -d `date -d '5 days ago' +%F` $testUser"
    rlRun "chage -M 4 $testUser"
  rlPhaseEnd; }

  rlPhaseStartTest && {
    rlRun -s "expect" << EOF
      spawn bash
      expect_after {
        timeout {puts TIMEOUT; exit 2}
        eof {puts EOF; exit 1}
      }
      expect {#} {send "su - ${testUser}\r"}
      expect {\\\$} {send "sudo -k\r"}
      expect {\\\$} {send "sudo id\r"}
      expect {\[sudo\] password for} {send "${testUserPasswd}\r" }
      expect {
        -nocase "current" {puts "providing wrong password"; send "blabla\r"; exp_continue}
        {\\\$} {send "sudo id\r"}
      }
      expect {
        {\[sudo\] password} {
          puts "this is expected"
          send "${testUserPasswd}\r"
          expect -nocase "current" {puts "providing wrong password"; send "blabla\r" }
        }
        -nocase "current" { puts "providing wrong password"; puts "this is unexpected"; send "blabla\r"}
      }
      expect {
        -nocase "current" {puts "providing wrong password"; send "blabla\r"; exp_continue }
        {\\\$} {send "exit\r"}
      }
      expect {#} {send "exit\r"}
      expect eof
EOF
    rlAssertGrep 'this is expected' $rlRun_LOG
    rlAssertNotGrep 'this is unexpected' $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
