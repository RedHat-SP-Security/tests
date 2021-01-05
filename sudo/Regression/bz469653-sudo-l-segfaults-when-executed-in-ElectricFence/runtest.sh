#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz469653-sudo-l-segfaults-when-executed-in-ElectricFence
#   Description: Test for bz469653 ("sudo -l" segfaults when executed in ElectricFence)
#   Author: Karel Srot <ksrot@redhat.com>
#   Edit: Ales "alich" Marecek <amarecek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="sudo"
_LIB_EFENCE_F=""

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlAssertRpm ElectricFence
	rlFileBackup /etc/sudoers
	rlRun "sed -i '/requiretty/d' /etc/sudoers" 0 "Removing 'requiretty' settings from config file"
	rlRun "echo \"Defaults !requiretty\" >>/etc/sudoers" 0 "Setting 'Defaults !requiretty' option"
	_LIB_EFENCE_F="`rpm -ql ElectricFence | grep "^.*\/lib.*\/libefence.so$"`"
	rlRun "[ ! -z '${_LIB_EFENCE_F}' ]" 0 "Setting path of ElectricFence library"
	rlRun "TmpFile=\`mktemp\`"
    rlPhaseEnd

    rlPhaseStartTest
	rlGetTestState
	if [ $? -eq 0 ]; then
	        rlRun "LD_PRELOAD=${_LIB_EFENCE_F} EF_PROTECT_BELOW=1 sudo -l >$TmpFile 2>&1" 0 "Running sudo with ElectricFence"
		cat $TmpFile
		rlAssertGrep "may run the following commands" $TmpFile
	else
		rlLogError "Error(s) occured, skipping the test."
	fi
    rlPhaseEnd

    rlPhaseStartCleanup
	rlRun "rm $TmpFile"
	rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
