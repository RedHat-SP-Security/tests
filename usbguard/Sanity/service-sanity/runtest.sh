#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/service-sanity
#   Description: exercises usbguard service-related daemon functionality
#   Author: Jiri Jaburek <jjaburek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="usbguard"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlServiceStart "usbguard"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest "service start/stop/restart"
        sleep 3  # in case service is type=simple
        rlRun "systemctl status usbguard &>status"
        cat status
        rlAssertGrep "Active: active (running)" status
        rlRun "ps -C usbguard-daemon -o comm,pid"

        rlRun "systemctl stop usbguard"
        sleep 3
        rlRun "systemctl status usbguard &>status" 1-127
        cat status
        rlAssertGrep "Active: inactive (dead)" status
        rlRun "ps -C usbguard-daemon -o comm,pid" 1

        rlRun "systemctl restart usbguard"
        sleep 3
        rlRun "systemctl status usbguard &>status"
        cat status
        rlAssertGrep "Active: active (running)" status
        rlRun "ps -C usbguard-daemon -o comm,pid"
    rlPhaseEnd

    rlPhaseStartTest "service start failure on bad config (BZ#1469399)"
        rlFileBackup /etc/usbguard/rules.conf
        rlRun "echo some-invalid-syntax > /etc/usbguard/rules.conf"
        rlRun "systemctl reset-failed usbguard"
        rlRun "systemctl restart usbguard" 1-127  # failure expected
        rlRun "sleep 10"
        rlRun -s "systemctl status usbguard" 0-127
        rlAssertGrep "code=exited, status=1/FAILURE" $rlRun_LOG
        rm -f $rlRun_LOG
        rlFileRestore
        rlRun "systemctl reset-failed usbguard"
        rlRun "systemctl restart usbguard"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlServiceRestore
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
