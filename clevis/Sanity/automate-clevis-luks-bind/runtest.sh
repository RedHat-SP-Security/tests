#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/automate-clevis-luks-bind
#   Description: This test validates the newly added -y (assume-yes)
#   parameter that helps automate clevis luks bind
#
#   Author: Sergio Correia <scorreia@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
PACKAGES="${PACKAGE} ${PACKAGE}-luks tang cryptsetup"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd ${TmpDir}"

        rlRun "dd if=/dev/zero of=loopfile1 bs=100M count=1"
        rlRun "dd if=/dev/zero of=loopfile2 bs=100M count=1"

        rlRun "luks1=\$(losetup -f --show loopfile1)" 0 "Create device from file (loopfile1)"
        rlRun "luks2=\$(losetup -f --show loopfile2)" 0 "Create device from file (loopfile2)"

        rlRun "pass=redhat123"
        rlRun "cryptsetup luksFormat --type luks1 --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --batch-mode --force-password ${luks1} <<< ${pass}"
        rlRun "cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --batch-mode --force-password ${luks2} <<< ${pass}"

        rlRun "rlServiceStart tangd.socket"
    rlPhaseEnd

    rlPhaseStartTest "Automate bind using tang pin"
        for d in ${luks1} ${luks2}; do
            rlRun "slot=3"
            cfg='{"url":"localhost"}'
            rlRun "clevis luks bind -y -d ${d} -s ${slot} tang '${cfg}' <<< ${pass}" 0 "clevis luks bind - ${d}:${slot}"
            rlRun "clevis luks unlock -d ${d}" 0 "clevis luks unlock - ${d}"
            rlRun "find /dev/mapper -name 'luks*' -exec cryptsetup close {} +"
            rlRun "clevis luks unbind -f -d ${d} -s ${slot}" 0 "clevis luks unbind - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Automate bind using sss pin"
        for d in ${luks1} ${luks2}; do
            rlRun "slot=5"
            cfg='{"t":2,"pins":{"tang":[{"url":"localhost"},{"url":"localhost"}]}}'
            rlRun "clevis luks bind -y -d ${d} -s ${slot} sss '${cfg}' <<< ${pass}" 0 "clevis luks bind - ${d}:${slot}"
            rlRun "clevis luks unlock -d ${d}" 0 "clevis luks unlock - ${d}"
            rlRun "find /dev/mapper -name 'luks*' -exec cryptsetup close {} +"
            rlRun "clevis luks unbind -f -d ${d} -s ${slot}" 0 "clevis luks unbind - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "find /dev/mapper -name 'luks*' -exec cryptsetup close {} +"
        rlRun "losetup -d ${luks1}"
        rlRun "losetup -d ${luks2}"
        rlRun "popd"
        rlRun "rm -r ${TmpDir}" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
