#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Regression/aide-check-exit-codes
#   Description: Check all possible exit codes according to the test coverage.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="aide"
AIDE_CONF="/etc/aide.conf"

DBDIR=$(sed -n -e 's/@@define DBDIR \([a-z/]\+\)/\1/p' "$AIDE_CONF")
DB=$(grep "^database=" "$AIDE_CONF" | cut -d/ -f2-)
DB="${DBDIR}/${DB}"

DBnew=$(grep "^database_out=" "$AIDE_CONF" | cut -d/ -f2-)
DBnew="${DBDIR}/${DBnew}"

aideInit() {
    rlRun -s "aide -i" 0 "AIDE database initialization"
    [ -f "$DBnew" ] || rlFail "New database is not initialized"
    [ -n "$DB" ] || rlFail "Database path is not set correctly"

    rlRun "mv ${DBnew} ${DB}" 0 "Move new AIDE initialed database to the place of the default one."
    rlRun "rm $rlRun_LOG"
}

aideCheck() {
    rlRun -s "aide" 0 "Checking default behaviour -- database check"
    rlAssertGrep "Looks okay!" $rlRun_LOG
    rlRun "rm $rlRun_LOG"
}

rlJournalStart
    rlPhaseStartSetup "Temp directory creation"
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "rlFileBackup --clean ${AIDE_CONF}"
        rlRun "sed -i '/^[/!#]/d' ${AIDE_CONF}" 0 "Delete all paths and comments in aide config"

        if ! grep -q -e 'CONTENT_EX' ${AIDE_CONF}; then
            rlRun "echo \"CONTENT_EX = sha256+ftype+p+u+g+n+acl+selinux+xattrs\" >> ${AIDE_CONF}" 0 "Adding CONTENT_EX group"
        fi

        rlAssertGrep 'CONTENT_EX' ${AIDE_CONF}
        rlRun "echo '/root/ CONTENT_EX' >> ${AIDE_CONF}" 0 "Add just one path aide the config"
        rlRun "aide --config-check" 0 "No harm on changing config"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 1 (new files detected)"
        aideInit
        aideCheck

        rlRun "testingFile=\$(mktemp --tmpdir=/root)" 0 "Add new temporary file - cannot be in /tmp"
        rlRun -s "aide" 1 "Recheck consistency between database and filesystem"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"

        rlRun "rm ${testingFile}"
        aideCheck
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 2 (removed files detected)"
        rlRun "testingFile=\$(mktemp --tmpdir=/root)" 0 "Add new temporary file - cannot be in /tmp"
        aideInit
        aideCheck

        rlRun "rm ${testingFile}"
        rlRun -s "aide" 2 "Recheck consistency -- one file is missing"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 4 (changed files detected)"
        rlRun "testingFile=\$(mktemp --tmpdir=/root)" 0 "Add new temporary file - cannot be in /tmp"
        aideInit
        aideCheck

        rlRun "echo 'test data' > ${testingFile}" 0 "Overwriting testing file"
        rlRun -s "aide" 4 "Recheck consistency -- one file is changed"
        rlAssertGrep "found differences between database and filesystem" $rlRun_LOG
        rlAssertGrep ":\t*1" $rlRun_LOG -P
        rlRun "rm $rlRun_LOG"

        rlRun "> ${testingFile}" 0 "Clearing testing file"
        aideCheck

        rlRun "rm ${testingFile}"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 15 (Invalid argument error)"
        rlRun "aide blahblah" 15
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 16 (Unimplemented function error)"
        rlLog "This exit code is not implemented in aide source code"
    rlPhaseEnd

    rlPhaseStartTest "Checking exit code 18 (IO error)"
        rlRun "rm ${DB}" 0 "Removing AIDE datbase for testing purpose"
        rlRun "aide" 18
        aideInit
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm ${DB}" 0 "Removing AIDE datbase after finish all tests"
        rlRun "rlFileRestore" 0 "Restore aide config"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

