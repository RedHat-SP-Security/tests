#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckRecommended; rlCheckRequired" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard/"
    rlRun "sed -r -i '/Rule(File|Folder)/d' /etc/usbguard/usbguard-daemon.conf"
    rlRun "rm -rf /etc/usbguard/rules.conf /etc/usbguard/rules.d/*"
    rlRun "rlFileBackup --clean --namespace test /etc/usbguard/"
    rlRun "rlServiceStop usbguard"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    # * man page describes conditions under which the rules can be stored permanently
    # * if neither RuleFile nor RuleFolder are specified, modification of the permanent policy is not possible; a warning message is reported only once
    # * if RuleFile is specified, the file will be used for the permanent rules management
    # * if RuleFolder is specified, files in the folder will be used for the permanent rules management
    # * if both RuleFile and RuleFolder are specified, both can be used to manage permanent rules, e.g. "usbguard append-rule --after ID"
    rlPhaseStartTest "no RuleFile nor RuleFolder" && {
      rlRun "rlFileRestore --namespace test"
      rlRun "systemctl reset-failed usbguard" 0-255
      timestamp=$(date +"%F %T")
      rlRun "rlServiceStart usbguard"
      rlRun -s "journalctl --since '$timestamp' -u usbguard"
      rlAssertLesserOrEqual "there's only one warning message" $(grep permanent policy $rlRun_LOG | wc -l) 1
      rlRun "usbguard append-rule 'allow with-interface { 08:00:00 07:06:00 }'"
      rlAssertNotExists /etc/usbguard/usbguard.rules
      rlRun -s "ls -1 /etc/usbguard/rules.d/ | wc -l"
      rlAssertGrep '^0$' $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }

    rlPhaseStartTest "RuleFile only" && {
      rlRun "rlFileRestore --namespace test"
      rlRun "echo 'RuleFile=/etc/usbguard/rules.conf' >> /etc/usbguard/usbguard-daemon.conf"
      rlRun "touch /etc/usbguard/rules.conf"
      rlRun "chmod 0600 /etc/usbguard/rules.conf"
      rlRun "restorecon -rv /etc/usbguard"
      rlRun "systemctl reset-failed usbguard" 0-255
      timestamp=$(date +"%F %T")
      rlRun "rlServiceStart usbguard"
      rlRun "journalctl --since '$timestamp' -u usbguard"
      rlRun "usbguard append-rule 'allow with-interface { 08:00:00 07:06:00 }'"
      rlAssertExists /etc/usbguard/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 07:06:00 }' /etc/usbguard/rules.conf
      rlRun -s "ls -1 /etc/usbguard/rules.d/ | wc -l"
      rlAssertGrep '^0$' $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }

    rlPhaseStartTest "RuleFolder only" && {
      rlRun "rlFileRestore --namespace test"
      rlRun "echo 'RuleFolder=/etc/usbguard/rules.d' >> /etc/usbguard/usbguard-daemon.conf"
      rlRun "touch /etc/usbguard/rules.d/rules.conf"
      rlRun "chmod 0600 /etc/usbguard/rules.d/rules.conf"
      rlRun "restorecon -rv /etc/usbguard"
      rlRun "systemctl reset-failed usbguard" 0-255
      timestamp=$(date +"%F %T")
      rlRun "rlServiceStart usbguard"
      rlRun "journalctl --since '$timestamp' -u usbguard"
      rlRun "usbguard append-rule 'allow with-interface { 08:00:00 07:07:00 }'"
      rlAssertNotExists /etc/usbguard/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 07:07:00 }' /etc/usbguard/rules.d/rules.conf
      rlRun -s "ls -1 /etc/usbguard/rules.d/ | wc -l"
      rlAssertGrep '^1$' $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }

    rlPhaseStartTest "both RuleFile and RuleFolder" && {
      rlRun "rlFileRestore --namespace test"
      rlRun "echo 'RuleFile=/etc/usbguard/rules.conf' >> /etc/usbguard/usbguard-daemon.conf"
      rlRun "echo 'RuleFolder=/etc/usbguard/rules.d' >> /etc/usbguard/usbguard-daemon.conf"
      rlRun "echo 'allow with-interface { 08:00:00 07:06:00 }' > /etc/usbguard/rules.conf"
      rlRun "echo 'allow with-interface { 08:00:00 07:07:00 }' > /etc/usbguard/rules.d/rules.conf"
      rlRun "chmod 0600 /etc/usbguard/rules.conf"
      rlRun "chmod 0600 /etc/usbguard/rules.d/rules.conf"
      rlRun "restorecon -rv /etc/usbguard"
      rlRun "systemctl reset-failed usbguard" 0-255
      timestamp=$(date +"%F %T")
      rlRun "rlServiceStart usbguard"
      rlRun "journalctl --since '$timestamp' -u usbguard"
      rlRun "usbguard append-rule --after 1 'allow with-interface { 08:00:00 08:06:00 }'"
      rlRun "usbguard append-rule --after 2 'allow with-interface { 08:00:00 08:07:00 }'"
      rlAssertExists /etc/usbguard/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 07:06:00 }' /etc/usbguard/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 08:06:00 }' /etc/usbguard/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 07:07:00 }' /etc/usbguard/rules.d/rules.conf
      rlAssertGrep 'allow with-interface { 08:00:00 08:07:00 }' /etc/usbguard/rules.d/rules.conf
      rlRun -s "ls -1 /etc/usbguard/rules.d/ | wc -l"
      rlAssertGrep '^1$' $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }

  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
