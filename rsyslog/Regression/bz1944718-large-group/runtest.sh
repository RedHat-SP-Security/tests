#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Regression/bz1944718-large-group
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

. /usr/lib/beakerlib/beakerlib.sh || exit 1
PACKAGE="rsyslog"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rlFileRestore"'
        rlRun "rlFileBackup --clean /var/log/bz1659383"
        CleanupRegister 'rlRun "testUserCleanup"'
        rlRun "testUserSetup --fast 200"
        users="$"
        for u in ${testUser[@]:1}; do
          users+=",$u"
        done
        rlRun "sed -i -r 's/^$testUserGroup:[^:]*:[^:]*:.*/\0$users/' /etc/group"
        rsyslogPrepareConf
        rsyslogServiceStart
        rsyslogConfigAddTo "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection TEST1)
    rlPhaseEnd

    rlPhaseStartTest 'bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
*.* action(type="omfile" FileCreateMode="0644" fileOwner="$testUser" fileGroup="$testUserGroup" File="/var/log/bz1659383")
EOF
      rsyslogResetLogFilePointer /var/log/messages
      rlRun "rsyslogServiceStart"
      rlRun "logger mujtest"
      rlRun "sleep 5"
      rlRun "rsyslogServiceStop"
      rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
      rlAssertGrep 'mujtest' $rlRun_LOG
      rlAssertNotGrep "ID for group $testUserGroup could not be found" $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
