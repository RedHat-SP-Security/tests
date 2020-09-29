#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-conf-group-definition
#   Description: Test custom aide groups of what should be checked
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

PACKAGE="aide"
TESTDIR=`pwd`

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "sed 's%AIDE_DIR%$TmpDir%g' $TESTDIR/aide.conf > $TmpDir/aide.conf" 0 "Prepare aide.conf file"
        rlRun "mkdir -p data/permSizeCheck log db"
        rlRun "echo blah > data/testFile" 0 "Make test file"
        rlRun "echo blah > data/permSizeCheck/testFile" 0 "Make test file"

        rlRun "aide -i -c $TmpDir/aide.conf" 0 "Init database again"
        rlRun "cp -p db/aide.db.out.gz db/aide.db.gz" 0 "Copy database to the read database"
    rlPhaseEnd

    rlPhaseStartTest "Checking aide groups"
        rlRun "echo blah blah >> data/testFile" 0 "Change test file"
        rlRun "chmod 777 data/testFile" 0 "Change permission"

        rlRun "echo blah blah >> data/permSizeCheck/testFile" 0 "Change test file"
        rlRun "chmod 777 data/permSizeCheck/testFile" 0 "Change permission"

        rlRun -s "aide -c $TmpDir/aide.conf" 4 "File changed check"
        rlAssertGrep "^  Added .*:[[:space:]]*0" $rlRun_LOG -E
        rlAssertGrep "^  Changed .*:[[:space:]]*2" $rlRun_LOG -E
        rlAssertGrep ":[[:space:]]*${TmpDir}/data/testFile" $rlRun_LOG -E
        rlAssertGrep ":[[:space:]]*${TmpDir}/data/permSizeCheck/testFile" $rlRun_LOG -E

        LOG1=$rlRun_LOG
        rlRun -s "sed -n '\|^File: ${TmpDir}/data/testFile|,/^$/p' $LOG1"
        rlAssertGrep "^ *Size" $rlRun_LOG
        rlAssertGrep "^ *Perm" $rlRun_LOG
        rlAssertGrep "^ *SHA256" $rlRun_LOG
        rlAssertNotGrep "SELinux" $rlRun_LOG
        rlRun "rm $rlRun_LOG"

        rlRun -s "sed -n '\|^File: ${TmpDir}/data/permSizeCheck/testFile|,/^$/p' $LOG1"
        rlAssertGrep "^ *Size" $rlRun_LOG
        rlAssertGrep "^ *Perm" $rlRun_LOG
        rlAssertNotGrep "SHA256" $rlRun_LOG
        rlAssertNotGrep "SELinux" $rlRun_LOG
        rlRun "rm $rlRun_LOG"
        rlRun "rm $LOG1"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

