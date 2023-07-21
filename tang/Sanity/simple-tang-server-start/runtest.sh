#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang/Sanity/simple-tang-server-start
#   Description: Smoke run tang server
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="tang"
PACKAGES="${PACKAGE} http-parser curl"
TANG="tangd.socket"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
        [[ "${IN_PLACE_UPGRADE,,}" == "old" ]] && rlRun "systemctl enable ${TANG}"
        [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
          rlRun "systemctl start ${TANG}"
          rlRun "sleep 1"
        }

        # Backup any possibly existing keys then remove them.
        rlRun "rlFileBackup --clean /var/db/tang/"
        rlRun "rm -f /var/db/tang/*.jwk"
        rlRun "rm -f /var/db/tang/.*.jwk"
    rlPhaseEnd

    rlPhaseStartTest "Check for active socket"
        rlRun "systemctl status ${TANG}"
    rlPhaseEnd

    rlPhaseStartTest "Force server to generate advertisment and get it by curl"
        # Make sure there are no leftover keys.
        rlRun "rm -f /var/db/tang/*.jwk"
        rlRun "rm -f /var/db/tang/.*.jwk"

        rlRun -s "curl -sS http://localhost/adv" 0
        rlAssertGrep '"payload":' $rlRun_LOG
        rlAssertGrep '"protected":' $rlRun_LOG
        rlAssertGrep '"signature":' $rlRun_LOG
        rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartTest "Test tangd-keygen"
        # Make sure there are no leftover keys.
        rlRun "rm -f /var/db/tang/*.jwk"
        rlRun "rm -f /var/db/tang/.*.jwk"

        # Run the keygen.
        KEYGEN=/usr/libexec/tangd-keygen
        rlRun "${KEYGEN} /var/db/tang" 0

        rlRun -s "curl -sS http://localhost/adv" 0
        rlAssertGrep '"payload":' $rlRun_LOG
        rlAssertGrep '"protected":' $rlRun_LOG
        rlAssertGrep '"signature":' $rlRun_LOG
        rm -f $rlRun_LOG
    rlPhaseEnd

    [[ -z "${IN_PLACE_UPGRADE}" ]] && {
      rlPhaseStartCleanup
          rlRun "systemctl stop ${TANG}"
          rlRun "sleep 1"
          rlRun "systemctl status ${TANG}" 1-100
          rlRun "rlFileRestore"
      rlPhaseEnd
    }
rlJournalPrintText
rlJournalEnd
