#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/bz1614181-fromhost-property-case-sensitive-when-using-UDP
#   Description: Test for BZ#1614181 ("fromhost" property case sensitive when using UDP)
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

PACKAGE="rsyslog"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    rlRun "rsyslogPrepareConf"
    rlRun "rsyslogServiceStop"
    rsyslogConfigAddTo RULES < <(rsyslogConfigCreateSection MYRULE)
    rsyslogConfigAddTo MODULES < <(rsyslogConfigCreateSection MYMODLOAD)
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/hosts"
    syncIsServer && {
      rlRun "rlFileBackup --clean /etc/hosts /var/log/mydebug.log"
      echo "$syncOTHER myCLIENT.example.lab myCLIENT" >> /etc/hosts
    }
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {

   i=0
   while read module Case Expected; do
    let i++
    [[ "$Case" == "-" ]] && Case=''
    Client='@'
    [[ "$module" == "imtcp" ]] && Client='@@'
    syncIsServer && rlPhaseStartTest "test $module $Case" && {
      rsyslogConfigReplace 'MYMODLOAD' <<EOF
module(load="$module" $Case)
input(type="$module" port="514")
EOF
      rsyslogConfigReplace 'MYRULE' <<'EOF'
*.* /var/log/mydebug.log;RSYSLOG_DebugFormat
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
      > /var/log/mydebug.log
      rlRun "rsyslogServiceStart"
      syncSet SERVER_READY_$i
      syncExp CLIENT_DONE_$i
      rlRun "sleep 5s"
      rlAssertGrep "THIS_IS_A_TEST_MESSAGE" /var/log/mydebug.log
      rlAssertGrep "FROMHOST:.*$Expected" /var/log/mydebug.log
      rlRun "grep -i -C 5 THIS_IS_A_TEST_MESSAGE /var/log/mydebug.log"
      rlRun "rsyslogServiceStop"
    rlPhaseEnd; }

    syncIsClient && rlPhaseStartTest "test $module $Case" && {
      rsyslogConfigReplace 'MYRULE' <<EOF
*.* $Client$syncOTHER:514
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
      syncExp SERVER_READY_$i
      rlRun "rsyslogServiceStart"
      rlRun "logger THIS_IS_A_TEST_MESSAGE"
      rlRun "sleep 5s"
      rlRun "rsyslogServiceStop"
      syncSet CLIENT_DONE_$i
    rlPhaseEnd; }
   done <<< "imtcp PreserveCase=\"on\"  myCLIENT.example.lab
             imudp PreserveCase=\"on\"  myCLIENT.example.lab
             imtcp PreserveCase=\"off\" myclient.example.lab
             imudp PreserveCase=\"off\" myclient.example.lab
             imtcp -                    myCLIENT.example.lab
             imudp -                    myclient.example.lab"
       :
     tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd

  rlJournalPrintText
rlJournalEnd; }
