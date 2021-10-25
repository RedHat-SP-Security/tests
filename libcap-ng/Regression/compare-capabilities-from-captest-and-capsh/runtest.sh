#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libcap-ng/Regression/compare-capabilities-from-captest-and-capsh
#   Description: Test for BZ#1253220 (captest list sys_psacct instead of sys_pacct)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libcap-ng"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "uname -a"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun -s "captest --text"
        mv $rlRun_LOG captest.out
        rlRun -s "captest"
        mv $rlRun_LOG  hexadec.out
        HEXA=`awk '/^Effective:/ { print $2,$3; exit }' hexadec.out | sed 's/, //'`
        rlLogInfo "hexadecimal representation of Effective capabilities: $HEXA"
        rlRun -s "capsh --decode=$HEXA"
        mv $rlRun_LOG capsh.out
        # now convert output to a better form

        rlRun "cut -d '=' -f 2 capsh.out \
            | sed -e 's/cap_//g' \
                -e 's/,/\\n/g' \
                -e 's/35/wake_alarm/' \
                -e 's/36/block_suspend/' \
                -e 's/37/audit_read/' \
                -e 's/40/checkpoint_restore/' \
            | sed -e '/^[0-9]\+$/d' \
            | sort > capsh_sorted.out" 0 "substituting unknown/numeric capabilities in the capsh output"

        rlRun "grep '^Effective' captest.out \
            | sed -e 's/Effective: //' \
                -e 's/, /\\n/g' \
                -e 's/40/checkpoint_restore/' \
            | sort > captest_sorted.out" 0 "substituting unknown/numeric capabilities in the captest output"

    rlPhaseEnd

    rlPhaseStartTest "Effective permissions listed by 'capsh --decode=$HEXA' are available in 'captest --text'"
        rlRun "cat capsh_sorted.out"
        rlRun "cat captest_sorted.out"

        for cap in $(cat capsh_sorted.out); do
            rlAssertGrep "${cap}" captest_sorted.out
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
