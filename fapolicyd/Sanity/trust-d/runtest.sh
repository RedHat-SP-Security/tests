#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
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

PACKAGE="fapolicyd"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    rlRun "echo a > ./test_file1"
    rlRun "echo a > ./test_file2"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    #  4. fapolicyd-cli -f --trust-file DB handles items in the specified DB file in trust.d
    #  5. fapolicyd uses the trustDB items from all the files located in the trust.d and fapolicyd.trust at the same time
    rlPhaseStartTest "--trust-file parameter" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      rlRun "fapStart"
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file1" 0-255'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file2 --trust-file trust_file2" 0-255'
      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file1"
      rlRun "fapolicyd-cli -f add ./test_file2 --trust-file trust_file2"
      rlRun "fapolicyd-cli --update"
      rlRun "fapStop"
      rlRun -s "fapolicyd-cli -D | grep test_file"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file1"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file2"
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }

    #  8. after fapolicyd-cli -f add XY --trust-file DB1, the fapolicyd-cli -f add XY --trust-file DB2 will say there’s a duplicate / produces an error
    rlPhaseStartTest "cannot add duplicates" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file1" 0-255'
      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file1"
      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file2" 1 "cannot add a duplicate"
      CleanupDo --mark
    rlPhaseEnd; }

    #  7. fapolicyd-cli -f delete XY --trust-file DB will delete the file reference from the DB file and no other (if defined in DB2 an error is produced)
    rlPhaseStartTest "removing duplicate from specific DB" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file1" 0-255'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file2" 0-255'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file2 --trust-file trust_file2" 0-255'
      rlRun "fapolicyd-cli -f add ./test_file2 --trust-file trust_file2"

      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file1"
      rlRun "mv /etc/fapolicyd/trust.d/trust_file1 ./trust_file1"
      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file2" 0 "add a second instance of a file to second trust DB"

      rlRun "cat ./trust_file1 > /etc/fapolicyd/trust.d/trust_file1"
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun -s "fapolicyd-cli -D | grep test_file"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file1"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file2"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      
      rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file2" 0 "delete a filed only from one trust DB even if there is a duplicate elsewhere"
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun -s "fapolicyd-cli -D | grep test_file"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file1"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file2"
      rlAssertNotGrep 'test_file1' $rlRun_LOG
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG

      CleanupDo --mark
    rlPhaseEnd; }

    #  6. fapolicyd-cli -f delete XY will delete the file references from all the files where it was defined
    rlPhaseStartTest "remove all duplicates" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file1" 0-255'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file1 --trust-file trust_file2" 0-255'
      CleanupRegister 'rlRun "fapolicyd-cli -f delete ./test_file2 --trust-file trust_file2" 0-255'
      rlRun "fapolicyd-cli -f add ./test_file2 --trust-file trust_file2"

      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file1"
      rlRun "mv /etc/fapolicyd/trust.d/trust_file1 ./trust_file1"
      rlRun "fapolicyd-cli -f add ./test_file1 --trust-file trust_file2" 0 "add a second instance of a file to second trust DB"

      rlRun "cat ./trust_file1 > /etc/fapolicyd/trust.d/trust_file1"
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun -s "fapolicyd-cli -D | grep test_file"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rlAssertGrep 'test_file2' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file1"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file2"
      rlAssertGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      
      rlRun "fapolicyd-cli -f delete ./test_file1" 0 "delete all apperances of a file from all trust DBs"
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file1"
      rlAssertNotGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /etc/fapolicyd/trust.d/trust_file2"
      rlAssertNotGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun -s "fapolicyd-cli -D | grep test_file"
      rlAssertNotGrep 'test_file1' $rlRun_LOG
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }

  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
