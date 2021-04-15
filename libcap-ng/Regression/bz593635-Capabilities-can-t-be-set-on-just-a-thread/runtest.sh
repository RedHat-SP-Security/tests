#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libcap-ng/Regression/bz593635-Capabilities-can-t-be-set-on-just-a-thread
#   Description: When changing capabilities on a thread, it actually changes the capabilities
#   Author: Eduard Benes <ebenes@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libcap-ng"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlAssertRpm $PACKAGE-utils
        rlAssertRpm $PACKAGE-devel
        rlLog "`sestatus`"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "gcc -g pthread-cap-test.c -o pthread-cap-test -lcap-ng -lpthread"
        rlAssertExists "./pthread-cap-test"
        rlRun "chmod a+x ./pthread-cap-test"
        rlRun "./pthread-cap-test"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
