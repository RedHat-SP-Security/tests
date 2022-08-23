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
    CleanupRegister 'rlRun "fapStop"'
    rlRun "fapStart"
    CleanupRegister --mark "rlRun 'RpmSnapshotRevert'; rlRun 'RpmSnapshotDiscard'"
    rlRun "RpmSnapshotCreate"
    #rlRun 'yum install --skip-broken -y `repoquery -al 2>/dev/null | grep "/usr/lib64/python[^/]*/site-packages/.*__init__.py"`'
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "pydoc -k modules" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      rlRun "fapStart"
      (sleep 1; top -b -d 1 -p $(cat /run/fapolicyd.pid )) > >(grep -A1 %CPU  | awk '{print $9}' | grep -oE '^[0-9]+' | tee load.log) &
      pid=$!
      LogProgressHeader 30
      for ((i=0; i<30; i++)); do
        pydoc3 -k modules >& /dev/null &
        pids+="$! "
        LogProgressDraw $i
        sleep 2
      done
      LogProgressFooter
      sleep 1
      killall top
      killall -9 $pids
      rlLog "the load MIN $(cat load.log | sort -n | head -n 1)"
      rlLog "the load AVG $(awk '{ total += $1; count++ } END { print total/count }' load.log)"
      rlLog "the load MAX $(cat load.log | sort -n | tail -n 1)"
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "python -c 'help(\"modules\")'" && {
      CleanupRegister --mark 'rlRun "fapStop"'
      rlRun "fapStart"
      (sleep 1; top -b -d 1 -p $(cat /run/fapolicyd.pid )) > >(grep -A1 %CPU  | awk '{print $9}' | grep -oE '^[0-9]+' | tee load.log) &
      pid=$!
      pids=''
      LogProgressHeader 30
      for ((i=0; i<30; i++)); do
        python3 -c 'help("modules")' >& /dev/null &
        pids+="$! "
        LogProgressDraw $i
        sleep 2
      done
      LogProgressFooter
      sleep 1
      killall top
      killall -9 $pids
      rlLog "the load MIN $(cat load.log | sort -n | head -n 1)"
      rlLog "the load AVG $(awk '{ total += $1; count++ } END { print total/count }' load.log)"
      rlLog "the load MAX $(cat load.log | sort -n | tail -n 1)"
      CleanupDo --mark
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
