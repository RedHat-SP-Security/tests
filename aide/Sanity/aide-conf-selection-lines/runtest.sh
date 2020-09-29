#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-conf-selection-lines
#   Description: Check the proper file verficaton accroding to the selectors in aide.conf
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

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d --tmpdir=/)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "rlFileBackup --clean --namespace mainBackup ${AIDE_CONF}"
        rlRun "sed -i '/^[/!#]/d' ${AIDE_CONF}" 0 "Delete all paths and comments in aide config"
        rlRun "sed -i '/^$/d' ${AIDE_CONF}" 0 "Delete empty lines"

        if ! grep -q -e 'CONTENT_EX' ${AIDE_CONF}; then
            rlRun "echo \"CONTENT_EX = sha256+p+u+g+n+acl+selinux+xattrs\" >> ${AIDE_CONF}" 0 "Adding CONTENT_EX group"
        fi

        rlAssertGrep 'CONTENT_EX' ${AIDE_CONF}
        rlRun "aide --config-check" 0 "No harm on changing config - cleaning config"
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '/' functionlity"
        [ "$(pwd)" == "${TmpDir}" ] || rlFail
        rlRun "mkdir myRoot"

        rlRun "echo \"${TmpDir}/myRoot/ CONTENT_EX\" >> ${AIDE_CONF}" 0 "Adding regular selection line"
        rlRun "tail -1 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding regular selection line"

        aideInit
        rlRun "aide" 0 "All files match AIDE database"

        rlRun "touch myRoot/untrackedFile"
        rlRun "aide" 1 "Finding untracked file"
        rlRun "rm myRoot/untrackedFile"
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '!' functionlity"
        rlRun "mkdir myRoot/dirNotCheck"
        rlRun "echo \"!${TmpDir}/myRoot/dirNotCheck/\" >> ${AIDE_CONF}" 0 "Adding negative selection line"
        rlRun "tail -2 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding negative selection line"

        aideInit
        rlRun "aide" 0 "All files match AIDE database"

        rlRun "touch myRoot/dirNotCheck/fileNotToTrack"
        rlRun "aide" 0 "All files match AIDE database"
    rlPhaseEnd

    rlPhaseStartTest "Checking selector '=' functionlity"
        rlRun "mkdir dirCheckJustThis"
        rlRun "echo \"=${TmpDir}/dirCheckJustThis CONTENT_EX\" >> ${AIDE_CONF}" 0 "Adding equals selection line"
        rlRun "tail -3 ${AIDE_CONF}" 0 "Listing AIDE config"
        rlRun "aide --config-check" 0 "No harm on changing config - adding equals selection line"

        aideInit
        rlRun "aide" 0 "All files match AIDE database"

        rlRun "rlFileBackup --clean --namespace chmodChange dirCheckJustThis"
        rlRun "chmod 777 dirCheckJustThis" 0 "Make configuration change on tracked directory"
        rlRun "aide" 4 "Find changed file"
        rlRun "rlFileRestore --namespace chmodChange"

        rlRun "aide" 0 "All files match AIDE database"

        rlRun "touch dirCheckJustThis/fileNotToTrack2"
        rlRun "aide" 0 "All files match AIDE database"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm ${DB}" 0 "Removing AIDE datbase after finish all tests"
        rlRun "rlFileRestore --namespace mainBackup" 0 "Restore aide config"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

