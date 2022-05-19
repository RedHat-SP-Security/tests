#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1746464-default-fapolicyd-policy-prevents-ansible-from-running
#   Description: Test for BZ#1746464 (default fapolicyd policy prevents ansible from running )
#   Author: Radovan Sroka <rsroka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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

PACKAGE="fapolicyd"
SERVICE="$PACKAGE.service"
_CONFIG_F1="/etc/fapolicyd/fapolicyd.rules"
_CONFIG_F2="/etc/fapolicyd/fapolicyd.conf"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "rolesInstallAnsible"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "fapSetup"
        rlRun "rm -rf /var/lib/$PACKAGE/*"
        rlRun "rm -rf /var/run/$PACKAGE/*"
        rlRun "rm -rf /var/db/$PACKAGE/*"
    rlPhaseEnd

    rlPhaseStartTest "running ansible without fapolicyd"
        pidof fapolicyd && rlRun "fapStop"
        rlRun "ansible localhost -m ping"
    rlPhaseEnd

    rlPhaseStartTest "running ansible with fapolicyd"
        rlRun "fapStart"
        rlRun "sleep 3"
        rlRun "ansible localhost -m ping"
        rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
