#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang/Sanity/simple-tang-server-start-different-port
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
PORT=7500

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
        [[ "${IN_PLACE_UPGRADE,,}" == "old" ]] && rlRun "systemctl enable ${TANG}"
        [[ "${IN_PLACE_UPGRADE,,}" != "new" ]] && {
          mkdir -p /etc/systemd/system/tangd.socket.d
          cat >/etc/systemd/system/tangd.socket.d/override.conf <<EOF
[Socket]
ListenStream=
ListenStream=$PORT
EOF
          rlRun "systemctl daemon-reload"
          rlRun "semanage port -a -t tangd_port_t -p tcp $PORT"
          rlRun "systemctl restart ${TANG}"
          rlRun "sleep 1"
        }
    rlPhaseEnd

    rlPhaseStartTest "Check for active socket"
        rlRun "systemctl status ${TANG} --no-page -l"
    rlPhaseEnd

    rlPhaseStartTest "Force server to generate advertisment and get it by curl"
        rlRun -s "curl -sS http://localhost:$PORT/adv" 0
        rlAssertGrep '"payload":' $rlRun_LOG
        rlAssertGrep '"protected":' $rlRun_LOG
        rlAssertGrep '"signature":' $rlRun_LOG
        rm -f $rlRun_LOG
    rlPhaseEnd

    [[ -z "${IN_PLACE_UPGRADE}" ]] && {
      rlPhaseStartCleanup
          rm -rf /etc/systemd/system/tangd.socket.d
          rlRun "systemctl daemon-reload"
          rlRun "systemctl stop ${TANG}"
          rlRun "semanage port -d -t tangd_port_t -p tcp $PORT"
          rlRun "sleep 1"
          rlRun "systemctl status ${TANG} --no-page -l" 1-100
      rlPhaseEnd
    }
rlJournalPrintText
rlJournalEnd
