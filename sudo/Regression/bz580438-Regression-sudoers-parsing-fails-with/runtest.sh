#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz580438-Regression-sudoers-parsing-fails-with
#   Description: Test for bz580438 (Regression: sudoers parsing fails with)
#   Author: Alex Sersen <asersen@redhat.com>
#   Edit (rewritten): Ales "alich" Marecek <amarecek@redhat.com>
#   Edit2 (rewritten): Karel Srot <ksrot@redhat.com>
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

PACKAGE="sudo"
_SUDOERS_F="/etc/sudoers"
_USER="`whoami`"
_USER_TEST="sudotestuser"
_USER_TEST2="sudotestuser2"
_USER_TEST_PASSWORD="redhat"
_LOG_FILE="sudo.log"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlCheckMakefileRequires"
	rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
	_LOG_FILE="${TmpDir}/${_LOG_FILE}"
	rlRun "pushd $TmpDir"
	rlFileBackup "${_SUDOERS_F}"
	id ${_USER_TEST} && rlRun "userdel -fr ${_USER_TEST}" 0 "Cleaning testuser"
	rlRun "useradd ${_USER_TEST} && echo \"${_USER_TEST_PASSWORD}\" | passwd --stdin ${_USER_TEST}"
	rlRun "useradd ${_USER_TEST2} && echo \"${_USER_TEST_PASSWORD}\" | passwd --stdin ${_USER_TEST2}"
        rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Removing 'requiretty' settings from config file"
        sed -i 's/^.*Defaults.*visiblepw.*$//g' ${_SUDOERS_F}
	rlRun "echo \"Defaults !visiblepw\" >>${_SUDOERS_F}" 0 "Setting 'Defaults !visiblepw' option"
	rlRun "echo '${_USER_TEST} ALL = (ALL) NOPASSWD: ALL' >>${_SUDOERS_F}" 0 "Adding rule for ${_USER_TEST} in ${_SUDOERS_F}"
	rlRun "echo '${_USER_TEST2} ALL = (ALL) NOPASSWD: ALL' >>${_SUDOERS_F}" 0 "Adding rule for ${_USER_TEST2} in ${_SUDOERS_F}"
    rlPhaseEnd

    rlPhaseStartTest "Defaults requiretty AND Defaults:${_USER} \!requiretty test"
	rlRun "echo \"Defaults requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults requiretty' option"
	rlRun "echo \"Defaults:${_USER} !requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults:${_USER} !requiretty' option"
	grep requiretty ${_SUDOERS_F}

	rlRun "sudo ls /etc/passwd | grep '/etc/passwd'"  0 "Running command as ${_USER} should pass (!requiretty)"
	rm ${_LOG_FILE}

	rlRun "setsid su - ${_USER_TEST} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 1 "Running command as ${_USER_TEST} should fail (requiretty)"
	cat ${_LOG_FILE}
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 1 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 0 "Checking logfile for tty error message"

	rlRun "setsid su - ${_USER_TEST2} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 1 "Running command as ${_USER_TEST2} should fail (requiretty)"
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 1 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 0 "Checking logfile for tty error message"

	rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Cleaning requiretty options"
    rlPhaseEnd

    rlPhaseStartTest "Defaults \!requiretty && Defaults:${_USER_TEST} requiretty test"
	rlRun "echo \"Defaults !requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults !requiretty' option"
	rlRun "echo \"Defaults:${_USER_TEST} requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults:!${_USER_TEST} requiretty' option"
	grep requiretty ${_SUDOERS_F}

	rlRun "sudo ls /etc/passwd | grep '/etc/passwd'"  0 "Running command as ${_USER} should pass (!requiretty)"

	rlRun "setsid su - ${_USER_TEST} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 1 "Running command as ${_USER_TEST} should fail (requiretty)"
	cat ${_LOG_FILE}
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 1 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 0 "Checking logfile for tty error message"

	rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Cleaning requiretty options"
    rlPhaseEnd

    rlPhaseStartTest "Defaults requiretty && Defaults:${_USER_TEST} \!requiretty test"
	rlRun "echo \"Defaults requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults requiretty' option"
	rlRun "echo \"Defaults:${_USER_TEST} !requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults:${_USER_TEST} !requiretty' option"
	grep requiretty ${_SUDOERS_F}

	rlRun "setsid su - ${_USER_TEST} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 0 "Running command as ${_USER_TEST} should pass (!requiretty)"
	cat ${_LOG_FILE}
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 0 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 1 "Checking logfile for tty error message"

	rlRun "su - ${_USER_TEST2} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 1 "Running command as ${_USER_TEST2} should fail (requiretty)"
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 1 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 0 "Checking logfile for tty error message"

	rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Cleaning requiretty options"
    rlPhaseEnd


    # ALL,!user syntax is necessary, simple !user won't work, see BZ#856901 and http://www.sudo.ws/pipermail/sudo-workers/2012-September/000772.html
    rlPhaseStartTest "Defaults:ALL,\!<user> requiretty test, i.e require tty for non-${_USER} user"
	#rlRun "echo \"Defaults !requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults !requiretty' option"
	rlRun "echo \"Defaults:ALL,!${_USER} requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults:ALL,!${_USER} requiretty' option"
	grep requiretty ${_SUDOERS_F}

	rlRun "sudo ls /etc/passwd | grep '/etc/passwd'"  0 "Running command as ${_USER} should pass (!requiretty is default)"

	rlRun "setsid su - ${_USER_TEST} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 1 "Running command as ${_USER_TEST} should fail (requiretty)"
	cat ${_LOG_FILE}
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 1 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 0 "Checking logfile for tty error message"

	rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Cleaning requiretty options"
    rlPhaseEnd

    rlPhaseStartTest "Defaults requiretty  AND  Defaults:${_USER_TEST},${_USER_TEST2} !requiretty"
	rlRun "echo \"Defaults requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults requiretty' option"
	rlRun "echo \"Defaults:${_USER_TEST},${_USER_TEST2} !requiretty\" >>${_SUDOERS_F}" 0 "Setting 'Defaults:${_USER_TEST},${_USER_TEST2} !requiretty' option"
	grep requiretty ${_SUDOERS_F}

	rlRun "setsid su -c 'sudo ls /etc/passwd | grep /etc/passwd'" 1 "Running command as root should fail (requiretty)'"

	rlRun "setsid su - ${_USER_TEST} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 0 "Running command as ${_USER_TEST} should pass (!requiretty)"
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 0 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 1 "Checking logfile for tty error message"

	rlRun "setsid su - ${_USER_TEST2} -c 'sudo ls /etc/passwd 2>&1' >${_LOG_FILE}" 0 "Running command as ${_USER_TEST2} should pass (!requiretty)"
	rlRun "cat ${_LOG_FILE} | grep '/etc/passwd'" 0 "Checking logfile for command message"
	rlRun "cat ${_LOG_FILE} | grep 'sudo' | grep 'tty'" 1 "Checking logfile for tty error message"

	rlRun "sed -i '/requiretty/d' ${_SUDOERS_F}" 0 "Cleaning requiretty options"
    rlPhaseEnd

    rlPhaseStartCleanup
	id ${_USER_TEST} && rlRun "userdel -fr ${_USER_TEST}" 0 "Cleaning testuser"
	id ${_USER_TEST2} && rlRun "userdel -fr ${_USER_TEST2}" 0 "Cleaning testuser2"
	rlFileRestore
	rlRun "popd"
	rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
