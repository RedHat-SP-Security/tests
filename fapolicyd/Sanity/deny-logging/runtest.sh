#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/deny-logging
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
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    rlRun "cp $(readlink -m /bin/ls) ./"
    rlRun "chmod -R a+rx $PWD"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "rlServiceRestore auditd"'
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/audit/rules.d"
    rlRun "echo \"-D\"\$'\\n'\"-w /etc/shadow -p w\" > /etc/audit/rules.d/audit.rules"
    rlRun "rlServiceStart auditd"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "default deny_audit check" && {
      CleanupRegister --mark 'rlRun "fapServiceStop"'
      rlRun "fapServiceStart"
      start_time=`LC_ALL='en_US.UTF-8' date "+%x %T"`
      rlRun "su - $testUser -c '$PWD/ls'" 126
      rlRun -s "LC_ALL='en_US.UTF-8' ausearch -m fanotify -ts $start_time"
      rlAssertGrep 'name="/tmp/[^/]*/ls"' $rlRun_LOG -Eq
      rlAssertGrep 'exe="/usr/bin/bash"' $rlRun_LOG -Eq
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "deny_syslog check" && {
      rlRun "sed -r -i 's/deny_audit/deny_syslog/' /etc/fapolicyd/fapolicyd.rules"
      CleanupRegister --mark 'rlRun "fapServiceStop"'
      rlRun "sed -r -i '/^syslog_format = /d' /etc/fapolicyd/fapolicyd.conf"
      rlRun "echo 'syslog_format = rule,dec,perm,auid,pid,exe,:,path,ftype' >> /etc/fapolicyd/fapolicyd.conf"
      rlRun "fapServiceStart"
      start_time=$(date +"%F %T")
      rlRun "su - $testUser -c '$PWD/ls'" 126
      rlRun -s "journalctl --no-pager --since=\"$start_time\""
      rlAssertGrep 'rule=[0-9]+ dec=deny_syslog perm=execute auid=[0-9]+ pid=[0-9]+ exe=/usr/bin/bash : path=/tmp/[^/]+/ls ftype=application/x-executable' $rlRun_LOG -Eq
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
