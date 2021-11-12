#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Sanity/mmfields-module-test
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1
rlIsRHEL
rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rsyslogServiceStop"; rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/log/rsyslog.test-cef.log"
    rlRun "rsyslogServiceStop"
    rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'MODULES_MMFIELDS')
    rsyslogConfigAddTo --begin "RULES" < <(rsyslogConfigCreateSection 'RULES_MMFIELDS')
    rsyslogConfigReplace "MODULES_MMFIELDS" <<'EOF'
      module(load="mmfields")
      template(name="cef" type="string" string="%$!%\n")
EOF

  rlPhaseEnd; }

  while IFS='~' read -r title options message expected unexpected; do
    rlPhaseStartTest "$title" && {
      rsyslogConfigReplace "RULES_MMFIELDS" <<EOF
        local2.* action(type="mmfields"${options:+" $options"})
        local2.* action(type="omfile" file="/var/log/rsyslog.test-cef.log" template="cef")
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
      :> /var/log/rsyslog.test-cef.log
      rlRun "rsyslogServiceStart"
      rlRun "logger -p local2.info '$message'"
      rlRun "sleep 3s"
      rlRun -s "cat /var/log/rsyslog.test-cef.log"
      rlAssertGrep "$expected" $rlRun_LOG
      [[ -n "$unexpected" ]] && rlAssertNotGrep "$unexpected" $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
  done << 'EOF'
default~~CEF: 0,ArcSight,Logger,5.3.1.6838.0~"f1": "CEF: 0", "f2": "ArcSight", "f3": "Logger", "f4": "5.3.1.6838.0"~"cef": { "
separator pipe~separator="|"~CEF: 0|ArcSight|Logger|5.3.1.6838.0~"f1": "CEF: 0", "f2": "ArcSight", "f3": "Logger", "f4": "5.3.1.6838.0"~"cef": { "
jsonRoot cef~jsonRoot="!cef"~CEF: 0,ArcSight,Logger,5.3.1.6838.0~"cef": { "f1": "CEF: 0", "f2": "ArcSight", "f3": "Logger", "f4": "5.3.1.6838.0" }
EOF

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
