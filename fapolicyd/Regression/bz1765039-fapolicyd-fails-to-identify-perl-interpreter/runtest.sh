#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1765039-fapolicyd-fails-to-identify-perl-interpreter
#   Description: Test for BZ#1765039 (fapolicyd fails to identify perl interpreter )
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

USER=test_user
TEST_SCRIPT=test.pl
SCRIPT_PATH="/home/$USER/$TEST_SCRIPT"

INTERPRETER=`which perl`

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
	rlRun "useradd $USER"
	rlRun "usermod -aG wheel $USER"
	rlRun "cp $TEST_SCRIPT $SCRIPT_PATH"
	rlRun "chown $USER:$USER $SCRIPT_PATH"
	rlRun "chmod +x $SCRIPT_PATH"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "fapSetup"
        rlRun "rm -rf /var/lib/$PACKAGE/*"
        rlRun "rm -rf /var/run/$PACKAGE/*"
        rlRun "rm -rf /var/db/$PACKAGE/*"
    rlPhaseEnd

    rlPhaseStartTest "running perl without fapolicyd"
        pidof fapolicyd && rlRun "fapStop"
	rlRun "sudo -n -u $USER $INTERPRETER $SCRIPT_PATH"
    rlPhaseEnd

    rlPhaseStartTest "running perl with fapolicyd"
    	rlRun "fapStart"
	rlRun "sudo -n -u $USER $INTERPRETER $SCRIPT_PATH" 1-255
	rlRun "sleep 3"
	rlRun "fapStop -k"
	rlRun "cat $fapolicyd_out"
	rlAssertGrep ".*dec=deny_audit.*exe=$INTERPRETER.*:.*(file|path)=$SCRIPT_PATH.*ftype=text/x-perl.*" $fapolicyd_out -Eq
	rm -f $fapolicyd_out
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
	rlRun "userdel $USER"
	rlRun "rm -rf /home/$USER"
	rlRun "rm -rf $FAPOLICYD_LOG"
        rlRun "rm -rf $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
