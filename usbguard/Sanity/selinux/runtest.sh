#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/selinux
#   Description: Test for BZ#1683567 ([RFE] SELinux policy (daemons) changes required)
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="usbguard"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "file contexts" && {
      rlSEMatchPathCon "/etc/usbguard" "usbguard_conf_t"
      rlSEMatchPathCon "/etc/usbguard/rules.conf" "usbguard_rules_t"
      rlSEMatchPathCon "/etc/usbguard/rules.d" "usbguard_rules_t"
      rlSEMatchPathCon "/etc/usbguard/rules.d/test" "usbguard_rules_t"
      rlSEMatchPathCon "/etc/usbguard/usbguard-daemon.conf" "usbguard_conf_t"
      rlSEMatchPathCon "/usr/sbin/usbguard-daemon" "usbguard_exec_t"
      rlSEMatchPathCon "/var/run/usbguard.pid" "usbguard_var_run_t"
    rlPhaseEnd; }

    rlPhaseStartTest "policy rules" && {
      rlSESearchRule "allow init_t usbguard_exec_t : file { getattr open read execute } [ ]"
      rlSESearchRule "allow init_t usbguard_t : process { transition } [ ]"
      rlSESearchRule "type_transition init_t usbguard_exec_t : process usbguard_t [ ]"
      rlSESearchRule "allow usbguard_t usbguard_t : netlink_audit_socket { create nlmsg_relay } [ ]"
      rlSESearchRule "allow usbguard_t usbguard_conf_t : file { getattr ioctl lock open read } [ ]"
      rlSESearchRule "allow usbguard_t usbguard_conf_t : file { lock write append } [ usbguard_daemon_write_conf ]"
      rlSESearchRule "allow usbguard_t usbguard_rules_t : file { getattr ioctl lock open read } [ ]"
      rlSESearchRule "allow usbguard_t usbguard_rules_t : file { lock write append } [ usbguard_daemon_write_rules ]"
      rlSESearchRule "allow usbguard_t usbguard_rules_t : dir { open read getattr search } [ ]"
      rlSESearchRule "allow usbguard_t proc_t : file read [ ]"
      rlSESearchRule "allow usbguard_t usbguard_var_run_t : file { getattr open read write } [ ]"

    rlPhaseEnd; }

    rlPhaseStartTest "runnign daemon" && {
      rlRun "usbguard generate-policy > /etc/usbguard/rules.conf"
      rlRun "sed -r -i 's/^(RestoreControllerDeviceState)=.*/\1=true/' /etc/usbguard/usbguard-daemon.conf"
      CleanupRegister --mark 'rlRun "rlServiceRestore usbguard"'
      rlRun "rlServiceStart usbguard"
      rlRun "sleep 3s"
      rlRun -s "ps uaxZ | grep -v grep | grep usbguard"
      rlAssertGrep ':usbguard_t:' $rlRun_LOG -E
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
