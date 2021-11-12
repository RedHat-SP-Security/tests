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
    rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'MODULES_MMNORMALIZE')
    rsyslogConfigAddTo --begin "RULES" < <(rsyslogConfigCreateSection 'RULES_MMNORMALIZE')
    rsyslogConfigReplace "MODULES_MMNORMALIZE" <<'EOF'
      module(load="mmnormalize")
      template(name="cef" type="string" string="%$!%\n")
EOF

  rlPhaseEnd; }

    rlPhaseStartTest "CEF" && {
      rsyslogConfigReplace "RULES_MMNORMALIZE" <<EOF
        local2.* action(type="mmnormalize" rule="rule=:%cef:cef%")
        local2.* action(type="omfile" file="/var/log/rsyslog.test-cef.log" template="cef")
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
      :> /var/log/rsyslog.test-cef.log
      rlRun "rsyslogServiceStart"
      rlRun "logger -p local2.info 'CEF:0|Vendor|Product|Version|Signature ID|some name|Severity| aa=field1 bb=this is a value cc=field 3'"
      rlRun "sleep 3s"
      rlRun -s "cat /var/log/rsyslog.test-cef.log"
      rlAssertGrep '"cef": { "DeviceVendor": "Vendor", "DeviceProduct": "Product", "DeviceVersion": "Version", "SignatureID": "Signature ID", "Name": "some name", "Severity": "Severity", "Extensions": { "aa": "field1", "bb": "this is a value", "cc": "field 3" } }' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
