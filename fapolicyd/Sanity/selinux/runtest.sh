#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/selinux
#   Description: Test for BZ#1714529 - SELinux policy (daemons) changes required for package: fapolicyd
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
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "file contexts" && {
      rlSEMatchPathCon "/etc/fapolicyd" "fapolicyd_config_t"
      rlSEMatchPathCon "/etc/fapolicyd/fapolicyd.conf" "fapolicyd_config_t"
      rlSEMatchPathCon "/etc/fapolicyd/fapolicyd.rules" "fapolicyd_config_t"
      rlSEMatchPathCon "/etc/fapolicyd/fapolicyd.trust" "fapolicyd_config_t"
      rlSEMatchPathCon "/usr/sbin/fapolicyd" "fapolicyd_exec_t"
      rlSEMatchPathCon "/var/log/fapolicyd-access.log" "fapolicyd_log_t"
      rlSEMatchPathCon "/var/lib/fapolicyd" "fapolicyd_var_lib_t"
      rlSEMatchPathCon "/var/lib/fapolicyd/data.mdb" "fapolicyd_var_lib_t"
      rlSEMatchPathCon "/var/run/fapolicyd/fapolicyd.fifo" "fapolicyd_var_run_t"
      rlSEMatchPathCon "/var/run/fapolicyd.pid" "fapolicyd_var_run_t"
    rlPhaseEnd; }

    rlPhaseStartTest "policy rules" && {
      rlSESearchRule "allow init_t fapolicyd_exec_t : file { getattr open read execute } [ ]"
      rlSESearchRule "allow init_t fapolicyd_t : process { transition } [ ]"
      rlSESearchRule "type_transition fapolicyd_t var_run_t : file fapolicyd_var_run_t [ ]"
      rlSESearchRule "type_transition fapolicyd_t var_run_t : dir fapolicyd_var_run_t [ ]"
      rlSESearchRule "type_transition fapolicyd_t var_run_t : fifo_file fapolicyd_var_run_t [ ]"
      rlSESearchRule "type_transition fapolicyd_t var_run_t : lnk_file fapolicyd_var_run_t [ ]"
      rlSESearchRule "type_transition init_t fapolicyd_exec_t : process fapolicyd_t [ ]"
      rlSESearchRule "allow fapolicyd_t fapolicyd_t : unix_stream_socket { connect create getattr read write } [ ]"
      rlSESearchRule "allow fapolicyd_t fapolicyd_config_t : file { open read } [ ]"
      rlSESearchRule "allow fapolicyd_t fapolicyd_var_lib_t : file { create open read write } [ ]"
      rlSESearchRule "allow fapolicyd_t fapolicyd_log_t : file { create open read write } [ ]"
      rlSESearchRule "allow fapolicyd_t fapolicyd_var_run_t : file { create open read write } [ ]"
    rlPhaseEnd; }

    rlPhaseStartTest "runnign daemon" && {
      CleanupRegister --mark 'rlRun "fapServiceStop"'
      rlRun "fapServiceStart"
      rlRun "sleep 3s"
      rlRun -s "ps uaxZ | grep -v grep | grep fapolicyd"
      rlAssertGrep ':fapolicyd_t:' $rlRun_LOG -E
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
