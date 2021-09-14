#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang/Sanity/tang-operator
#   Description: Deployment and basic functionality of the tang operator
#   Author: Martin Zeleny <mzeleny@redhat.com>
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

PACKAGE="tang"
VERSION="v0.0.16" # TODO: check how to get latest version appropriately
TIMEOUT="5m"

rlJournalStart
    rlPhaseStartSetup
        rlRun "crc status > /dev/null" 0 "Checking Code Ready Containers installation"
        rlRun "oc status > /dev/null"  0 "Checking OpenshiftClient installation"
        rlRun "operator-sdk version > /dev/null" 0 "Checking operator-sdk version"
        rlRun "operator-sdk run bundle --timeout ${TIMEOUT} quay.io/sarroutb/tang-operator-bundle:${VERSION}" 0 "Installing tang-operator-bundler version:${VERSION}"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/conf_test/minimal/" 0 "Creating minimal configuration"
        rlRun "oc delete -f reg_test/conf_test/minimal/" 0 "Deleting minimal configuration"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "operator-sdk cleanup tang-operator" 0 "Removing tang-operator"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
