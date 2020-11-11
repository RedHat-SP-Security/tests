#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz740420-Add-a-etc-rsyslog-d-config-directory
#   Description: Test for bz740420 (Add a /etc/rsyslog.d config directory)
#   Author: Dalibor Pospisil <dapospis@dapospis.redhat>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"

rlJournalStart
    rlPhaseStartSetup
      rlImport --all
      rlTry "Setup phase" && {
        rlAssertRpm $PACKAGE; rlE2R
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"; rlE2R
        rlRun "pushd $TmpDir"; rlE2R
	rlRun "echo 'local1.* /var/log/bz740420.log1' > /etc/rsyslog.d/bz740420-1.conf"
	rlRun "echo 'local2.* /var/log/bz740420.log2' > /etc/rsyslog.d/bz740420-2.conf"
	rlServiceStart rsyslog
      rlFin; }
    rlPhaseEnd

  # run the test only in case rsyslog5 is installed on RHEL-5 or RHEL >=6
  if rsyslogVersion '<5'; then
    rlPhaseStartTest
	rlLogInfo "not valid for RHEL-5, unless you have rsyslog5 installed"
    rlPhaseEnd
  else
    rlPhaseStartTest
      rlTry "Test phase" && {
        rlChk "Check that /etc/rsyslog.d exists" && {
          test -d /etc/rsyslog.d
        rlFin; }
        rlRun "logger -p local1.info 'test message 1'"
        rlRun "logger -p local2.info 'test message 2'"
	sleep 1
	rlAssertGrep "test message 1" /var/log/bz740420.log1
	rlAssertGrep "test message 2" /var/log/bz740420.log2
      rlFin; }
    rlPhaseEnd

  fi

    rlPhaseStartCleanup
      rlChk "Cleanup phase" && {
        rlRun "popd"; rlE2R
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"; rlE2R
	rlRun "rm /etc/rsyslog.d/bz740420-1.conf /etc/rsyslog.d/bz740420-2.conf /var/log/bz740420.log1 /var/log/bz740420.log2"
	rlServiceRestore rsyslog
      rlFin; }
      rlTCFcheckFinal
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
