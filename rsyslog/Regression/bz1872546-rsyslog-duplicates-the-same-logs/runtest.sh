#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1872546-rsyslog-duplicates-the-same-logs
#   Description: Test for BZ#1872546 (rsyslog duplicates the same logs)
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

PACKAGE="rsyslog"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlServiceRestore systemd-journald"'
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/systemd/journald.conf"
    rlRun "sed -i 's/#RateLimitInterval=.*/RateLimitInterval=0/g' /etc/systemd/journald.conf"
    rlRun "sed -i 's/#RateLimitBurst=.*/RateLimitBurst=0/g' /etc/systemd/journald.conf"
    rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "RULES" <<EOF
\$SystemLogRateLimitInterval 1
\$SystemLogRateLimitBurst 60000
\$imjournalRatelimitInterval 1
\$imjournalRatelimitBurst    60000
EOF
    rlRun "rsyslogServiceStart"
    rlRun "rlServiceStart systemd-journald"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      rsyslogResetLogFilePointer /var/log/messages
      rlLog "generate messages"
      progressHeader 20000 1
      for ((x=1; x <= 20000; x++)); do
        progressDraw $x
        logger "test message $x."
      done
      progressFooter
      sleepWithProgress 10
      rlRun "rsyslogCheckDelivered 20000" < <(rsyslogCatLogFileFromPointer /var/log/messages | grep -o 'test message.*$' | grep -o '[0-9]*')
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
