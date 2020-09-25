#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/jose/Regression/bz1466278-file-descriptor-leaks-in-fmt
#   Description: runs jose fmt via valgrind, checking for leaks
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

PACKAGE="jose"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
    rlPhaseEnd

    rlPhaseStartTest
        # 2 separate known leaks, one in cmd_output (-o),
        # another one in cmd_foreach (-f)
        rlRun -s "valgrind --track-fds=yes jose fmt -j '{}' -o outputfile -f forinfile"
        rlAssertNotGrep "Open file descriptor [0-9]*: outputfile" "$rlRun_LOG"
        rlAssertNotGrep "Open file descriptor [0-9]*: forinfile" "$rlRun_LOG"
        rm -f "$rlRun_LOG"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
