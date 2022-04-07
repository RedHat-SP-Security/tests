#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Attila Lakatos <alakatos@redhat.com>
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
module(load="imfile" mode="inotify")
EOF
    rsyslogConfigAddTo "RULES" /etc/rsyslog.conf <<EOF
input(type="imfile"
      File="/var/log/input.log"
      Tag="imfile:"
      Severity="info"
      Facility="local6"
)

local6.info			/var/log/output.log
EOF
    CleanupRegister 'rlRun "rsyslogServiceRestore"'
    CleanupRegister 'rlRun "rsyslogServiceStop"; rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/lib/rsyslog /var/log/input.log* /var/log/output.log"
    touch /var/log/input.log
    rlRun "rsyslogServiceStart"
  rlPhaseEnd

  rlPhaseStartTest && {
    input="/var/log/input.log"
    pattern="imfile: internal error\? inotify provided watch descriptor [0-9]+ which we could not find in our tables - ignored"

    rlRun -s "rsyslogServiceStatus"
    rlRun "egrep \"$pattern\" $rlRun_LOG" 1 "Output should not contain the pattern"

    rlRun "mv $input $input-save"
    rlRun "echo testmessage >> $input-save"

    rlRun -s "rsyslogServiceStatus"
    rlRun "egrep \"$pattern\" $rlRun_LOG" 1 "Output should not contain the pattern"

  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
