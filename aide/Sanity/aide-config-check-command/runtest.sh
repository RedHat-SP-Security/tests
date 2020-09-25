#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-config-check-command
#   Description: tests aide --config-check command
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

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	rlRun "echo -e '@@define DBDIR /var/lib/aide\nfoo' > aide.conf"
    rlPhaseEnd

    rlPhaseStartTest "Checking the default /etc/aide.conf should succeed"
        rlRun "aide -D"
        rlRun "aide --config-check"
    rlPhaseEnd

    rlPhaseStartTest "Checking the faulty configuration file"
        rlRun -s "aide -D -c $TmpDir/aide.conf" 17
	rlAssertGrep "2:syntax error" $rlRun_LOG
	rlAssertGrep "2:Error while reading configuration:" $rlRun_LOG
	rlAssertGrep "Configuration error" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Passing non-existing filepath"
        rlRun -s "aide -D -c /nosuchfile" 17
	rlAssertGrep "Cannot access config file: ?/nosuchfile: ?No such file or directory" $rlRun_LOG -E
	rlAssertGrep "No config defined" $rlRun_LOG
	rlAssertGrep "Configuration error" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
