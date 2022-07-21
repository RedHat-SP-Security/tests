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
    rlRun "sed -i '/systlog_format/d' /etc/fapolicyd/fapolicyd.conf"
    rlRun "echo 'syslog_format = rule,dec,perm,auid,pid,ppid,exe,:,path,ftype,trust' >> /etc/fapolicyd/fapolicyd.conf"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "match allow rule based on the ppid attribute" && {
      rlRun 'echo "allow perm=any ppid=$$ : all" > /etc/fapolicyd/rules.d/00-ppid.rules'
      CleanupRegister --mark 'rlRun "fapStop"'
      rlRun "fapStart --debug"
      rlRun "rlServiceStatus fapolicyd"
      rlRun -s "fapServiceOut"
      rlAssertGrep "rule=1 .* ppid=$$ " $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }

    rlIsRHEL '<9' && rlPhaseStartTest "match kworker processes" && {
      rlRun 'echo "allow perm=any ppid=2 : all" > /etc/fapolicyd/rules.d/00-ppid.rules'
      CleanupRegister --mark 'rlRun "fapStop"'
      CleanupRegister 'rlRun "rlServiceRestore atd"'
      rlRun "fapStart --debug"
      rlRun "rlServiceStart atd"
      rlRun "rlServiceStop atd"
      rlRun "rlServiceStatus fapolicyd"
      rlRun -s "fapServiceOut | grep kworker"
      rlAssertGrep "rule=1 .* exe=kworker/u[0-9]+:[0-9]+ " $rlRun_LOG -Eq
      CleanupDo --mark
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
