#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-db-update-and-compare
#   Description: tests --update and --compare aide commands
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

PACKAGE="aide"

TESTDIR=`pwd`

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	rlRun "sed 's%AIDE_DIR%$TmpDir%g' $TESTDIR/aide.conf > $TmpDir/aide.conf" 0 "Prepare aide.conf file"
	rlRun "mkdir -p data log db"
	rlRun "aide -i -c $TmpDir/aide.conf"
	rlRun "cp -p db/aide.db.out.gz db/aide.db.gz"
	rlRun "cp -p db/aide.db.out.gz db/aide.db.new.gz"
    rlPhaseEnd

    rlPhaseStartTest "testing aide --update"
        rlRun "touch data/foo" 0 "Creating the data/foo test file"
	rlRun -s "aide --update -c $TmpDir/aide.conf" 1
    if rlIsRHEL '<=7'; then
	    rlAssertGrep "added: $TmpDir/data/foo" $rlRun_LOG
    else
        rlRun "grep -A 3 'Added entries:' $rlRun_LOG | grep '$TmpDir/data/foo'"
    fi
	rlRun "cmp db/aide.db.gz db/aide.db.out.gz" 1 "aide.db.out.gz should be updated"
    rlPhaseEnd

    rlPhaseStartTest "testing aide --compare"
        rlRun "mv db/aide.db.out.gz db/aide.db.gz" 0 "Use the updated aide db file"
	rlLogInfo "Using the original db as the NEW one, aide should report the test file as removed"
	rlRun -s "aide --compare -c $TmpDir/aide.conf" 2
    if rlIsRHEL '<=7'; then
	    rlAssertGrep "removed: $TmpDir/data/foo" $rlRun_LOG
    else
        rlRun "grep -A 3 'Removed entries:' $rlRun_LOG | grep '$TmpDir/data/foo'"
    fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
