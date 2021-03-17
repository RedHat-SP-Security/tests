#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /usbguard/Sanity/auditing
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

PACKAGE="usbguard"
set_config_option() {
  local file=/etc/usbguard/usbguard-daemon.conf
  sed -i -r "/^${1}\\s*=/d"   $file
  [[ -n "$2" ]] && {
    echo           >> $file
    echo "$1=$2" >> $file
  }
  echo "# grep -v -e '^\s*#' -e '^\s*$' \"$file\""
  grep -v -e '^\s*#' -e '^\s*$' "$file"
  echo "---"
}


rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard"
    CleanupRegister 'rlRun "rlServiceRestore usbguard"'
    rlRun "rlServiceStop usbguard"
  rlPhaseEnd; }

  if [[ "$auditTARGET" != "audit" ]]; then
    # file
    rlPhaseStartTest "$auditTARGET" && {
      start_time=`LC_ALL='en_US.UTF-8' date "+%x %T"`
      > /var/log/usbguard/usbguard-audit.log
      set_config_option AuditBackend FileAudit
      rlRun "rlServiceStart usbguard"
      rlRun -s "cat /var/log/usbguard/usbguard-audit.log"
      rlAssertGrep "result='SUCCESS" $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "LC_ALL='en_US.UTF-8' ausearch -m USER_DEVICE -ts $start_time" 0,1
      rlAssertNotGrep 'USER_DEVICE' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }
  elif [[ "$auditTARGET" != "file" ]]; then
    # audit
    rlPhaseStartTest "$auditTARGET" && {
      start_time=`LC_ALL='en_US.UTF-8' date "+%x %T"`
      > /var/log/usbguard/usbguard-audit.log
      set_config_option AuditBackend LinuxAudit
      rlRun "rlServiceStart usbguard"
      rlRun -s "LC_ALL='en_US.UTF-8' ausearch -m USER_DEVICE -ts $start_time" 0,1
      rlAssertGrep 'USER_DEVICE' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "cat /var/log/usbguard/usbguard-audit.log"
      rlAssertNotGrep "result='SUCCESS" $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "rlServiceStop usbguard"
    rlPhaseEnd; }
  fi

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
