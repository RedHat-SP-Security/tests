#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz1672876-Backporting-sudo-bug-with-expired-passwords
#   Description: sudo-with-expired-passwords
#   Author: Jiri Vymazal <jvymazal@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="sudo"
PACKAGE_2="httpd"
_USER="myuser"
_CONFIG_S="/etc/sudoers"
_CONFIG_P="/etc/shadow"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlCheckMakefileRequires"  || rlDie "cannot continue"
	rlRun "rlImport --all" || rlDie "cannot continue"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister 'rlRun "popd"'
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "testUserCleanup"'
        rlRun "testUserSetup 5"
        CleanupRegister 'rlRun "rlFileRestore"'
	rlRun "rlFileBackup /etc/shadow /etc/sudoers"
	rlRun "sed -i '/${testUser[1]}/d' ${_CONFIG_P}" 0 "Deleting original password record"
	rlRun "echo \"${testUser[1]}:!!:0:0:99999::::\" >> ${_CONFIG_P}" 0 "Adding expired password"
	rlRun "usermod -L ${testUser[2]}"
        rlRun "chage -d `date -d '5 days ago' +%F` ${testUser[3]}"
	rlRun "chage -M 4 ${testUser[3]}"
	rlRun "chage -E 0 ${testUser[4]}"
	rlFileBackup ${_CONFIG_S}
	rlRun "echo \"${testUser[1]},${testUser[2]},${testUser[3]},${testUser[4]}  ALL=(${testUser[0]})   NOPASSWD:ALL\" >> ${_CONFIG_S}" 0 "Adding expired apache rule to sudo config"
    rlPhaseEnd

    rlPhaseStartTest
      for i in 1 2 3; do
        rlRun -s "su -c 'sudo -u ${testUser[0]} id' - ${testUser[$i]}"
        rlAssertGrep "uid=[0-9]\+(${testUser[0]})" $rlRun_LOG
        rm -f $rlRun_LOG
      done
      rlRun -s "su -c 'sudo -u ${testUser[0]} id' - ${testUser[4]}" 1-255
      rlAssertNotGrep "uid=[0-9]\+(${testUser[0]})" $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
