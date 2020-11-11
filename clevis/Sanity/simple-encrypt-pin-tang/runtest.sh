#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/simple-encrypt-pin-tang
#   Description: Simple way how to test 'clevis encrypt tang'
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
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

PACKAGE="clevis"
PACKAGES="${PACKAGE} tang"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "rlServiceStart tangd.socket"
        rlRun "sleep 1"
        rlRun "wget -nv -O adv.json \"http://localhost/adv\"" 0 "Get advertisement from tang server"

        echo "testing data string" > plainFile
    rlPhaseEnd

    rlPhaseStartTest "clevis encrypt tang"
        rlRun "test -s plainFile" 0 "File exists and has a size greater than zero"
        rlRun "cat plainFile"

        rlRun "clevis encrypt tang '{ \"url\": \"localhost\", \"adv\": \"adv.json\" }' < plainFile > encryptedFile"
        rlRun "test -s encryptedFile" 0 "File exists and has a size greater than zero"
        rlRun "cat encryptedFile"

        rlRun "clevis decrypt < encryptedFile > decryptedFile"
        rlRun "cat decryptedFile"

        rlAssertNotDiffer plainFile decryptedFile
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"

        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
