#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1817413-segfault-on-update
#   Description: Crash on update of the db while killing the daemon
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
  rlPhaseEnd; }

  test() {
    rlLog "trying scenario $1 ::::::::"
    rlRun "fapStart"
    fapServiceOut -b -t -f
    CleanupRegister --mark "disown $!; kill $!"
    rlRun "$1" 0-255
    i=120
    while let i--; do
      pidof fapolicyd >& /dev/null || break
      sleep 1s
      echo -n .
    done
    fapServiceOut > fapolicyd_out
    rlAssertGrep 'shutting down' fapolicyd_out
    rlAssertGrep 'succeeded' fapolicyd_out -iq
    rlRun -s "rlServiceStatus fapolicyd" 1-255
    rlAssertNotGrep 'SEGV' $rlRun_LOG
    rm -f $rlRun_LOG
    CleanupDo --mark
  }

  rlPhaseStartTest && {
    test "kill \$(pidof fapolicyd) & fapolicyd-cli --update"
    test "fapolicyd-cli --update & kill \$(pidof fapolicyd)"
    test "kill \$(pidof fapolicyd); fapolicyd-cli --update"
    test "fapolicyd-cli --update; kill \$(pidof fapolicyd)"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
