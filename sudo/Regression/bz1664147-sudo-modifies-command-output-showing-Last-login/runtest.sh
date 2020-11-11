#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz1664147-sudo-modifies-command-output-showing-Last-login
#   Description: Test for BZ#1664147 (sudo modifies command output, showing "Last login)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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

PACKAGE="sudo"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister '
      rlRun "sudoCleanup"
      rlRun "pamCleanup"
      rlRun "testUserCleanup"
    '
    rlRun "testUserSetup"
    rlRun "pamSetup"

    rlRun "sudoSetup"
    rlRun "sudoSwitchProvider files"
    rlRun "sudoAddSudoRule defaults"
    rlRun "sudoAddOptionToSudoRule defaults sudoOption !authenticate"
    rlRun "sudoAddOptionToSudoRule defaults sudoOption !requiretty"
    rlRun "sudoAddSudoRule rule1"
    rlRun "sudoAddOptionToSudoRule rule1 sudoUser $testUser"
    rlRun "sudoAddOptionToSudoRule rule1 sudoHost ALL"
    rlRun "sudoAddOptionToSudoRule rule1 sudoCommand ALL"
    rlRun "cat /etc/sudoers"

    rlRun "pamInsertServiceRule sudo session required pam_lastlog.so showfailed"
    rlRun "pamGetServiceRules --prefix sudo session"
  rlPhaseEnd; }

    rlPhaseStartTest && {
      rlRun -s "su -c 'sudo true' -l $testUser"
      rlAssert0 "the output should be empty" $([[ ! -s $rlRun_LOG ]]; echo $?)
      rm -f $rlRun_LOG
      rlRun -s "su -c 'sudo -i true' -l $testUser"
      rlAssert0 "the output should not be empty" $([[ -s $rlRun_LOG ]]; echo $?)
      rm -f $rlRun_LOG
      rlRun -s "su -c 'sudo -s true' -l $testUser"
      rlAssert0 "the output should not be empty" $([[ -s $rlRun_LOG ]]; echo $?)
      rm -f $rlRun_LOG
    rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
