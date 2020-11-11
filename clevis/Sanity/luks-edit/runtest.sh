#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/luks-edit
#   Description: Tests for the clevis luks edit command
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="clevis"
PACKAGES="${PACKAGE} ${PACKAGE}-luks tang"

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

    rlPhaseStartTest "Bind slot 3 with tang for the next tests"
        rlRun "slot=3"
        cfg='{"url":"localhost"}'
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks bind -y -d ${d} -s ${slot} tang '${cfg}' <<< ${pass}" 0 "clevis luks bind tang - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Try the same config"
        cfg='{"url":"localhost"}'
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 1 "clevis luks edit should fail with the same config - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Try an invalid configuration"
        cfg='{"url&:"localhost"}'
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 1 "clevis luks edit should fail with invalid JSON - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Change the tang url"
        cfg='{"url":"http://localhost"}'
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 0 "clevis luks edit change tang url - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Unbind slot 3 - end of tang tests"
        rlRun "slot=3"
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks unbind -f -d ${d} -s ${slot} <<< ${pass}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Bind slot 4 with sss for the next tests"
        rlRun "slot=4"
        cfg=$(printf '{"t":1,"pins":{"tang":[{"url":"%s"}]}}' "localhost")
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks bind -y -d ${d} -s ${slot} sss '${cfg}' <<< ${pass}" 0 "clevis luks bind sss - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Add a new tang server to the sss config"
        cfg=$(printf '{"t":1,"pins":{"tang":[{"url":"%s"},{"url":"%s"}]}}' "localhost" "localhost")
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 0 "clevis luks edit add tang server to sss - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Edit one of the servers in the sss pin"
        cfg=$(printf '{"t":1,"pins":{"tang":[{"url":"%s"},{"url":"%s"}]}}' "http://localhost" "localhost")
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 0 "clevis luks edit tang server in sss - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Change threshold to 2"
        cfg=$(printf '{"t":2,"pins":{"tang":[{"url":"%s"},{"url":"%s"}]}}' "localhost" "localhost")
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 0 "clevis luks edit change threshold to 2 - ${d}:${slot}"
        done
    rlPhaseEnd

    rlPhaseStartTest "Change threshold to 3 - broken config"
        cfg=$(printf '{"t":3,"pins":{"tang":[{"url":"%s"},{"url":"%s"}]}}' "localhost" "localhost")
        for d in ${luks1} ${luks2}; do
            rlRun "clevis luks edit -d ${d} -s ${slot} -c '${cfg}'" 1 "clevis luks edit change threshold to 3 - broken - ${d}:${slot}"
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
