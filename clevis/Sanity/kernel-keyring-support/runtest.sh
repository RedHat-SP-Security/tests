#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/kernel-keyring-support
#   Description: Test clevis to check parameter that allows reading
#                a LUKS2 token id to avoid password prompt for existing LUKS2
#                password and read it from the key description associated to
#                that token id
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="clevis"
PACKAGES="${PACKAGE} clevis-luks tang"

PASSWORD="redhat123"
KEY_DEST="testkey"
TOKEN_ID="5"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "rlServiceStart tangd.socket"
        rlRun "sleep 1"
        rlRun "wget -nv -O adv.json \"http://localhost/adv\"" 0 "Get advertisement from tang server"

        rlRun "dd if=/dev/zero of=loopfile bs=100M count=1" 0 "Create dummy file for device"
        rlRun "lodev=$(losetup -f --show loopfile)" 0 "Create device"
        rlRun "echo -n ${PASSWORD} | cryptsetup luksFormat --batch-mode --key-file - ${lodev}" 0 "Format device"
    rlPhaseEnd


    rlPhaseStartTest "Register password"
        rlRun "keyctl add user ${KEY_DEST} ${PASSWORD} @s" 0 "Register password into kernel keyring"
        rlRun "cryptsetup token add --token-id ${TOKEN_ID} --key-description ${KEY_DEST} ${lodev}" \
            0 "Add token with password from kernel keyring"
    rlPhaseEnd


    rlPhaseStartTest "Misuse clevis bind with both -k and -e option"
        rlRun "touch keyfile"
        rlRun -s "clevis luks bind -d ${lodev} -k keyfile -e ${TOKEN_ID} tang '{\"url\": \"http://localhost\", \"adv\": \"adv.json\" }'" \
            1 "Misuse: both -e and -k options"
        rlAssertGrep "Cannot specify kernel keyring description together with key file" $rlRun_LOG

        rlRun "clevis luks unlock -d ${lodev}" 1 "Failed in unlock"
    rlPhaseEnd


    rlPhaseStartTest "Clevis bind with -e option"
        rlRun "clevis luks bind -d ${lodev} -e ${TOKEN_ID} tang '{\"url\": \"http://localhost\", \"adv\": \"adv.json\" }'" 0 "Test -e option (no password prompt)"
        rlRun "clevis luks unlock -d ${lodev}" 0 "Test unlock"
    rlPhaseEnd


    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
