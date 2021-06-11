#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Regression/bz1960536-imjournal-fsync-fd-leak
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

. /usr/share/beakerlib/beakerlib.sh || exit 1
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
        rsyslogPrepareConf
        rsyslogServiceStart
    rlPhaseEnd

    rlPhaseStartTest 'bz1960536' && {
      rsyslogConfigReplace "MODLOAD IMJOURNAL" /etc/rsyslog.conf <<EOF
module(load="imjournal"
StateFile="imjournal.state"
#IgnoreNonValidStatefile="on"
#IgnorePreviousMessages="on"
FSync="on"
Ratelimit.Interval="0"
)
EOF
      rsyslogResetLogFilePointer /var/log/messages
      rlRun "rsyslogServiceStart"
      i=0
      for (( ; i<50; i++ )); do
        logger "mujtest $i"
        sleep 0.1
      done
      fds1=$(lsof -p $(pidof rsyslogd) | grep /var/lib/rsyslog |wc -l)
      fds21=$(ls -1 /proc/$(pidof rsyslogd)/fd | wc -l)
      for (( ; i<200; i++ )); do
        logger "mujtest $i"
        sleep 0.1
      done
      fds2=$(lsof -p $(pidof rsyslogd) | grep /var/lib/rsyslog |wc -l)
      fds22=$(ls -1 /proc/$(pidof rsyslogd)/fd | wc -l)
      rlRun "rsyslogServiceStop"
      rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
      rlAssertGrep 'mujtest' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "compare_with_tolerance $fds1 $fds2 5" 0 "check leaked FDs"
      rlRun "compare_with_tolerance $fds21 $fds22 25" 0 "check open FDs"
    rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
