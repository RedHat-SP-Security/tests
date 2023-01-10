#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/inter-package-dependency
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "usbguard dependency" && {
      rlRun -s "rpm -q --requires usbguard"
      rlAssertNotGrep '\\busbguard\\b' $rlRun_LOG -Eq
      rm -f $rlRun_LOG
      rlRun -s "rpm -q --recommends usbguard"
      rlAssertGrep 'usbguard-selinux[^0-9]*$' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "rpm -q --conflicts usbguard"
      rlAssertNotGrep '^usbguard$' $rlRun_LOG
      rlAssertNotGrep 'usbguard-selinux' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartTest "usbguard-selinux dependency" && {
      rlRun -s "rpm -q --requires usbguard-selinux"
      rlAssertGrep 'selinux-policy-targeted' $rlRun_LOG
      rlAssertNotGrep 'usbguard' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "rpm -q --recommends usbguard-selinux"
      rlAssertNotGrep 'usbguard' $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun -s "rpm -q --conflicts usbguard-selinux"
      rlAssertNotGrep 'usbguard' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
