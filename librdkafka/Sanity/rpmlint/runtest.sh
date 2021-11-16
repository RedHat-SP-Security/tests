#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Test for BZ#1932783 (Rebase librelp to latest upstream version)
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="librdkafka"

rlJournalStart && {
    rlPhaseStartSetup
        rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
        rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
    rlPhaseEnd


    rlPhaseStartTest "Ensure system crypto policies are used by default"
        rlRun -s "rpmlint --info $PACKAGE" 0-64 "Check for common rpm problems"
        rlAssertNotGrep "crypto-policy-non-compliance-gnutls" $rlRun_LOG
        rlAssertNotGrep "crypto-policy-non-compliance-openssl" $rlRun_LOG
        rm -f $rlRun_LOG
    rlPhaseEnd;

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd

    rlJournalPrintText
rlJournalEnd; }
