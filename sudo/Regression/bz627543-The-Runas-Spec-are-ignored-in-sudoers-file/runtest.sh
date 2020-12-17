#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz627543-The-Runas-Spec-are-ignored-in-sudoers-file
#   Description: Test for bz627543 (The Runas_Spec are ignored in sudoers file)
#   Author: Ales Marecek <amarecek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="sudo"
_CONFIG_F="/etc/sudoers"
_U1="a"
_U2="b"
_U3="c"
_PASSWORD="redhat"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
	rlFileBackup ${_CONFIG_F}
	for _U in ${_U1} ${_U2} ${_U3}; do
		id ${_U} >/dev/null 2>&1 || rlRun "useradd ${_U} && echo \"${_PASSWORD}\" | passwd --stdin ${_U}" 0 "Creating testing user: '${_U}'"
	done
	rlLogInfo "Now setting the config file: '${_CONFIG_F}'"
	echo "User_Alias GROUP_A = ${_U1}" >>${_CONFIG_F}
	echo "Runas_Alias GROUP_B_C = ${_U2}, ${_U3}" >>${_CONFIG_F}
	echo "GROUP_A ALL = (: GROUP_B_C) NOPASSWD:ALL" >>${_CONFIG_F}
	sed -i 's/Defaults.*requiretty/Defaults  !requiretty/g' ${_CONFIG_F}
	sed -i 's/Defaults.*visiblepw/Defaults  !visiblepw/g' ${_CONFIG_F}
    rlPhaseEnd

    rlPhaseStartTest
	rlRun "su - ${_U1} -c \"sudo -g ${_U2} ls /etc/\"" 0 "Testing 'Runas_Spec'"
    rlPhaseEnd

    rlPhaseStartCleanup
	rlFileRestore
	for _U in ${_U1} ${_U2} ${_U3}; do
		id ${_U} >/dev/null 2>&1 && rlRun "userdel -fr ${_U}" 0 "Deleting testing user: '${_U}'"
	done
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

