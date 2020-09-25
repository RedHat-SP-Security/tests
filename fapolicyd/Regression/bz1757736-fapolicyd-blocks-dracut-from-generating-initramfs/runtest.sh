#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1757736-fapolicyd-blocks-dracut-from-generating-initramfs
#   Description: Test for BZ#1757736 (fapolicyd blocks dracut from generating initramfs )
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
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="fapolicyd"
SERVICE="$PACKAGE.service"
_CONFIG_F1="/etc/fapolicyd/fapolicyd.rules"
_CONFIG_F2="/etc/fapolicyd/fapolicyd.conf"

DYNAMIC_INTERPRETER=`find /usr/lib64/ -type f -name 'ld-2\.*.so'`
LS=`which ls`

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "fapSetup"
        rlRun "rm -rf /var/lib/$PACKAGE/*"
        rlRun "rm -rf /var/run/$PACKAGE/*"
        rlRun "rm -rf /var/db/$PACKAGE/*"
        pidof fapolicyd && rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartTest "running dynamic interpreter as a root without fapolicyd"
        rlRun "$DYNAMIC_INTERPRETER $LS"
    rlPhaseEnd

    rlPhaseStartTest "running dynamic interpreter as a root with fapolicyd"
        rlRun "fapStart" >/dev/null
        rlRun "$DYNAMIC_INTERPRETER $LS"
        rlRun "fapStop -k"
        rlFileSubmit $fapolicyd_out fapolicyd.out1
    rlPhaseEnd

    rlPhaseStartTest "running dracut without fapolicyd"
        rlRun "dracut -f --regenerate-all"
    rlPhaseEnd

    rlPhaseStartTest "running dracut with fapolicyd"
        rlRun "fapStart" >/dev/null
        rlRun "dracut -f --regenerate-all"
        rlRun "fapStop -k"
        rlFileSubmit $fapolicyd_out fapolicyd.out2
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
