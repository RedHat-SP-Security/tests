#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1747494-suspicious-logs-on-service-start
#   Description: Test for BZ#1747494 (suspicious logs on service start )
#   Author: Radovan Sroka <rsroka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="fapolicyd"
SERVICE="$PACKAGE.service"
_CONFIG_F1="/etc/fapolicyd/fapolicyd.rules"
_CONFIG_F2="/etc/fapolicyd/fapolicyd.conf"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "fapSetup"
        rlRun "rm -rf /var/lib/$PACKAGE/*"
        rlRun "rm -rf /var/run/$PACKAGE/*"
        rlRun "rm -rf /var/db/$PACKAGE/*"

	rlRun "g++ alter-database.cpp -llmdb -o alter"
    rlPhaseEnd

    rlPhaseStartTest
    	rlRun "fapServiceStart"
	rlRun "sleep 3"
	rlRun "fapServiceStop"

	rlRun "sleep 3"
	DATE=`date '+%T'`

	rlRun "./alter /var/lib/fapolicyd /usr/bin/sed"

	rlRun "fapServiceStart"
	rlRun "sleep 3"
	rlRun "fapServiceStop"

	rlRun "journalctl -b -u fapolicyd.service --since=$DATE | tee log"
	rlAssertNotGrep "Data miscompare for /usr/bin/sed" log
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
	rlRun "rm -rf alter log"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
