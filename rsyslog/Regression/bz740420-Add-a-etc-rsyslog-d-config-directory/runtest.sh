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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"

rlJournalStart
    rlPhaseStartSetup
      rlRun "rlImport --all" || rlDie 'cannot continue'
      tcfTry "Setup phase" && {
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	rlRun "echo 'local1.* /var/log/bz740420.log1' > /etc/rsyslog.d/bz740420-1.conf"
	rlRun "echo 'local2.* /var/log/bz740420.log2' > /etc/rsyslog.d/bz740420-2.conf"
	rlServiceStart rsyslog
      tcfFin; }
    rlPhaseEnd

  # run the test only in case rsyslog5 is installed on RHEL-5 or RHEL >=6
  if rsyslogVersion '<5'; then
    rlPhaseStartTest
	rlLogInfo "not valid for RHEL-5, unless you have rsyslog5 installed"
    rlPhaseEnd
  else
    rlPhaseStartTest
      tcfTry "Test phase" && {
        rlAssertExists /etc/rsyslog.d
        rlRun "logger -p local1.info 'test message 1'"
        rlRun "logger -p local2.info 'test message 2'"
	sleep 1
	rlAssertGrep "test message 1" /var/log/bz740420.log1
	rlAssertGrep "test message 2" /var/log/bz740420.log2
      tcfFin; }
    rlPhaseEnd

  fi

    rlPhaseStartCleanup
      rlChk "Cleanup phase" && {
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlRun "rm /etc/rsyslog.d/bz740420-1.conf /etc/rsyslog.d/bz740420-2.conf /var/log/bz740420.log1 /var/log/bz740420.log2"
	rlServiceRestore rsyslog
      tcfFin; }
      tcfCheckFinal
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
