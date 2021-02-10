#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/Regression/Regression/bz1873953-Filtering-rules-by-label
#   Description: Testing if usbguard list-rules --label "something" does not end with an error if at least one rule does not have an attribute set
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="usbguard"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "rlServiceStart usbguard"
        rlRun "sleep 3s"
    rlPhaseEnd

    rlPhaseStartTest "Filtering rules by attribute"
        label="This is a test label"
        rule="allow label \"$label\""
        rlRun "usbguard append-rule --temporary '$rule'" 0 "Create a rule that has a valid label"
        rlRun -s "usbguard list-rules --label \"$label\"" 0 "Filtering by an existing label should have '0' exit code."
        rlAssertGrep "$rule" $rlRun_LOG

        rlRun "usbguard append-rule 'allow'"
        # If there is a rule which does not have optional attribute label, then filtering by label should not cause an error.
        rlRun -s "usbguard list-rules --label \"Non existing label\"" 0 "Filtering by a non-existing label should have '0' exit code."
        rlAssertNotGrep "Non existing label" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceStop usbguard"
        rlRun "sleep 3s"
        rlRun "popd"
        rlRun "rm -r $TmpDir $rlRun_LOG" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
