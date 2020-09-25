#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/luks-pass
#   Description: Test the 'clevis luks pass' subcommand with the device and slot as a parameter and check the passphrase used to bind that particular slot.
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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

PACKAGE="clevis"
PACKAGES="${PACKAGE} ${PACKAGE}-luks tang jose luksmeta cryptsetup"
FMT="%{name}-%{version}-%{release}\n"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
        rlRun "packageVersion=$(rpm -q ${PACKAGE} --qf ${FMT})"
        rlTestVersion "${packageVersion}" '>=' 'clevis-11-5' \
            || rlDie "Tested functionality is not in old version ${packageVersion}"
        rlLogInfo "Sufficient version ${packageVersion} for running the test."

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"

        rlRun "dd if=/dev/zero of=loopfile bs=100M count=1"
        rlRun "lodev=\$(losetup -f --show loopfile)" 0 "Create device from file"
        rlRun "echo -n redhat123 | cryptsetup luksFormat --batch-mode --key-file - ${lodev}"

        rlRun "rlServiceStart tangd.socket"
    rlPhaseEnd

    rlPhaseStartTest "clevis luks bind"
        rlRun "luksmeta show -d ${lodev} -s 1" "1-100" "Check if there is no luksmeta data in slot 1"
        rlRun "wget -nv -O adv.json \"http://localhost/adv\"" 0 "Get advertisement from tang server"

        rlRun  "echo -n redhat123 | clevis luks bind -f -k - -d ${lodev} tang '{ \"url\": \"http://localhost\", \"adv\": \"adv.json\" }'" 0 "clevis luks bind"

        if rlIsRHEL '<8'; then
            rlRun "luksmeta show -d ${lodev} -s 1" 0 "Check if there are luksmeta data in slot 1"
        fi

        rlRun -s "lsblk" 0 "Encrypted LUKS volume is not visible"
        rlAssertNotGrep "crypt" $rlRun_LOG
        rm $rlRun_LOG

        rlRun "clevis luks pass -d ${lodev} -s 1 > luksPass" 0 "extract luks passphrase"
        rlRun "cat luksPass"
        rlRun "cryptsetup open ${lodev} luks_bz1436780 --key-file luksPass" 0 "Open LUKS volume manually with extracted password"

        rlRun -s "lsblk" 0 "Encrypted LUKS volume is visible"
        rlAssertGrep "crypt" $rlRun_LOG
        rm $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "find /dev/mapper -name 'luks*' -exec cryptsetup close {} +"
        rlRun "losetup -d ${lodev}"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
