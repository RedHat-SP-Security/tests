#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   test.sh of /CoreOS/clevis/Sanity/stderr
#   Description: Test that clevis displays eventual error messages when
#                unlocking fails.
#   Author: Sergio Correia <scorreia@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="clevis"
PACKAGES="${PACKAGE}-luks tang util-linux"

PASSPHRASE=redhat123

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlCheckRecommended; rlCheckRequired" || rlDie 'cannot continue'

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd ${TmpDir}"

        rlRun "dd if=/dev/zero of=loopfile bs=64M count=1"
        rlRun "lodev=\$(losetup -f --show loopfile)" 0 "Create device from file"
        rlRun "printf '%s' ${PASSPHRASE} | cryptsetup luksFormat --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --batch-mode --force-password ${lodev}"

        rlRun "rlServiceStart tangd.socket"

        # Create a clevis binding.
        rlRun "curl -sfo adv.json http://localhost/adv" 0 "Get advertisement from tang server"
        cfg=$(printf '{"url":"%s", "adv": "%s"}' "localhost" "adv.json")

        rlRun  "printf '%s' ${PASSPHRASE} | clevis luks bind -f -k - -d ${lodev} tang '${cfg}'" 0 "clevis luks bind"
    rlPhaseEnd

    rlPhaseStartTest "clevis luks unlock when tang server is unavailable"
        # When unlocking fails, we expect to see the same error message
        # we get when decryption itself fails. Let's find out what should
        # this error message be.
        rlRun "dummyEnc=\$(echo foo | clevis encrypt tang '${cfg}')"

        # Now stop tang and attempt to unlock the device.
        rlRun "rlServiceStop tangd.socket"

        # First we find get the expected error message.
        rlRun "errorMsg=\$(clevis decrypt <<< ${dummyEnc} 2>&1)" 1 "Decryption should fail"

        # Now we can attempt to unlock
        rlRun -s "clevis luks unlock -d ${lodev}" 1 "Unlock should fail"

        rlAssertGrep "${errorMsg}" "${rlRun_LOG}"
        rm -f "${rlRun_LOG}"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "losetup -d ${lodev}"
        rlRun "popd"
        rlRun "rm -r ${TmpDir}" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
