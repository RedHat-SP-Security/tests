#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckRecommended" 0-255
    rlRun "rlCheckRequired"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/sudoers"
    CleanupRegister "rlRun 'sessionClose'"
    rlRun "sessionOpen"
    rlRun "echo 'Defaults !authenticate' >> /etc/sudoers"
    export sessionExpectTIMEOUT=5 sessionRunTIMEOUT=5
    rlRun "sessionRun id"
    echo "test_file_content" > ./test_file
  rlPhaseEnd; }

  while IFS=';' read -r title options edit ec; do
    rlPhaseStartTest "$title" && {
      rlRun "sessionRun --timeout 1 'EDITOR=vi sudoedit $options ./test_file'" 254
      [[ "$?" == "254" ]] && {
        rlRun "sessionExpect 'test_file_content'" 0 "wait for the fiel content to show up"
        [[ $edit -eq 1 ]] && rlRun "sessionSend 'iX'\$'\\033'" 0 "insert X and press ESC"
        rlRun "sessionSend 'ZZ'" 0 "save and exit"
        sessionWaitAPrompt
        rlRun "sessionRun '(exit \$?)'" $ec "check sudoedit exit code"
      }
    rlPhaseEnd; }
  done <<< "simple sudoedit, without file change;;0;0
SELinux role, without file change;-r unconfined_r;0;1
SELinux type, without file change;-t unconfined_t;0;0
SELinux role and type, without file change;-r unconfined_r -t unconfined_t;0;1
simple sudoedit, with file change;;1;0
SELinux role, with file change;-r unconfined_r;1;0
SELinux type, with file change;-t unconfined_t;1;0
SELinux role and type, with file change;-r unconfined_r -t unconfined_t;1;0"

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }
