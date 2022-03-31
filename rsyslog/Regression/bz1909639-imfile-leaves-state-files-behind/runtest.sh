#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
    rsyslogResetLogFilePointer /var/log/messages
    rsyslogConfigAddTo "MODULES" /etc/rsyslog.conf <<EOF
module(load="imfile" mode="inotify" deleteStateOnFileMove="on")
EOF
    rsyslogConfigAddTo "RULES" /etc/rsyslog.conf <<EOF
input(type="imfile"
      File="/var/log/input.log"
      Tag="imfile:"
      Severity="info"
      Facility="local6"
#      MaxLinesAtOnce="1000000"
)

local6.info			/var/log/output.log
EOF
    CleanupRegister 'rlRun "rsyslogServiceRestore"'
    CleanupRegister 'rlRun "rsyslogServiceStop"; rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/lib/rsyslog /var/log/input.log* /var/log/output.log"
    rlRun "rsyslogServiceStart"
  rlPhaseEnd

  rlPhaseStartTest && {
    file="/var/log/input.log"
    maxfilesize=$((8 * 1024 * 1024))

    maxlogs=20

    rotatelogs() {
      if [ -e "$file.$maxlogs" ]; then
        rm "$file.$maxlogs"
      fi

      for i in $(seq $(($maxlogs - 1)) -1 1); do
        [ -e "$file.$i" ] || continue
        mv "$file.$i" "$file.$(($i + 1))"
      done
      mv "$file" "$file.1"
      touch "$file"
    }

    statlogs() {
      echo
      date
      echo "$file $(stat -c "%i" $file)"
      for i in $(seq 1 $maxlogs); do
        [ -e "$file.$i" ] || break
        echo "$file.$i $(stat -c "%i" $file.$i)"
      done
      rlRun -s "ls -la /var/lib/rsyslog/imfile*" 0-255
      rlAssertLesserOrEqual "there is only up to one state file" $(cat $rlRun_LOG | wc -l) 1
      cat /var/log/output.log | wc -l
    }

    seqnum=1
    filler=$(printf "X%.0s" $(seq 1 250))
    msgsize=$(printf "%09d $filler\n" $seqnum | wc -c)

    #iters=$(($maxfilesize / $msgsize))
    for ((j=1; j<=3; j++)); do
      rlLog "iteration $j/3"
      LogProgressHeader 32140
      for ((i=0; i<=32140; i++)); do
        LogProgressDraw $i
        printf "%09d $filler\n" $seqnum >> "$file"
        let seqnum++
      done
      LogProgressFooter
      rotatelogs
      statlogs
    done
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
