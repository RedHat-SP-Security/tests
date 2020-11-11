#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/trust-db
#   Description: Test for BZ#1817413 (Rebase FAPOLICYD to the latest upstream version)
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

PACKAGE="fapolicyd"

Stop() {
  fapStop
}
Start() {
  fapStart
}
Update() {
  rlRun "fapolicyd-cli --update"
  rlRun "sleep 10s"
}

Trust() {
  rlRun "sed -r -i '/^trust/d' /etc/fapolicyd/fapolicyd.conf"
  rlRun "echo 'trust = $1' >> /etc/fapolicyd/fapolicyd.conf"
  rlRun "fapolicyd-cli --delete-db"
  rlRun "cat /etc/fapolicyd/fapolicyd.conf"
  rlRun "pidof fapolicyd" 0-255
}

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    test_dir="$PWD"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister "rlFileRestore"
    rlRun "rlFileBackup --clean /opt/testdir/ /opt/testfile"
    rlRun "mkdir -p '/opt/testdir/subdir'"
    rlRun "touch /opt/testfile"
    rlRun "echo 'allow perm=any all : all' > /etc/fapolicyd/fapolicyd.rules"
    rlRun "fapolicyd-cli -f add /opt/testfile"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "config option trust=rpmdb AC16" && {
      Trust 'rpmdb'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertNotGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file AC17" && {
      Trust 'file'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertNotGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=rpmdb,file AC15" && {
      Trust 'rpmdb,file'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      rlRun "cat db_dump | cut -d ' ' -f 1 | uniq"
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file,rpmdb AC15" && {
      Trust 'file,rpmdb'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      rlRun "cat db_dump | cut -d ' ' -f 1 | uniq"
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file,rpmdb AC23" && {
      rlRun "sed -r -i '/^trust/d' /etc/fapolicyd/fapolicyd.conf"
      rlRun "fapolicyd-cli --delete-db"
      rlRun "cat /etc/fapolicyd/fapolicyd.conf"
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file rpmdb AC21" && {
      Trust 'file,rpmdb'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file;rpmdb AC21" && {
      Trust 'file,rpmdb'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=blabla AC22" && {
      Trust 'file,rpmdb'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertGrep '^rpmdb' db_dump
      rlAssertGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "config option trust=file, while db is empty" && {
      rlRun "fapolicyd-cli -f delete /opt/testfile"
      Trust 'file'
      CleanupRegister --mark 'rlRun "Stop"'
      rlRun "Start"
      rlRun "fapolicyd-cli -D > db_dump"
      rlAssertNotGrep '^rpmdb' db_dump
      rlAssertNotGrep '^filedb' db_dump
      CleanupDo --mark
    rlPhaseEnd; }

  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
