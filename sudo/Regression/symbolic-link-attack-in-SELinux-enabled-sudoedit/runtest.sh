#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/symbolic-link-attack-in-SELinux-enabled-sudoedit
#   Description: Race condition vulnerability in file handling of sudoedit SELinux RBAC support
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
TESTUSER="user_bz1917038"
PROTECTED_SYMLINKS="/proc/sys/fs/protected_symlinks"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "useradd ${TESTUSER}"
        rlRun "pushd ~${TESTUSER}"

        rlRun "PROTECTED_SYMLINKS_BACKUP_VAL=$(cat ${PROTECTED_SYMLINKS})"
        rlRun "echo 0 > ${PROTECTED_SYMLINKS}" 0 "Disable symlink protection"

        rlRun "rlFileBackup --clean /etc/sudoers.d/"
        rlRun "echo '${TESTUSER} ALL=(root) NOPASSWD: sudoedit /etc/passwd' > /etc/sudoers.d/${TESTUSER}" 0 "Grant testuser sudoedit permissions"

        rlRun "su ${TESTUSER} -c 'touch testfile'"
        rlRun "ls -l"

        su ${TESTUSER} -c 'cat > myeditor <<EOF
#!/bin/sh
echo replacing \$1
rm \$1
ln -s /home/user_bz1917038/testfile \$1
exit 0
EOF'
        rlRun "cat myeditor" 0 "Exploit editor"
        rlRun "chmod 755 myeditor"
    rlPhaseEnd


    rlPhaseStartTest "sudoedit with exploited EDITOR variable should not segfault"
        rlRun -ts "su ${TESTUSER} -c 'EDITOR=$(pwd)/myeditor sudoedit -r unconfined_r -t unconfined_t /etc/passwd'" 1 "Main command in test"
        rlAssertNotGrep "Segmentation fault" $rlRun_LOG
        rm $rlRun_LOG

        rlRun -s "ls -l" 0 "The testfile must not be owned by root"
        rlAssertNotGrep "root" $rlRun_LOG
        rm $rlRun_LOG
    rlPhaseEnd


    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "userdel -r ${TESTUSER}"
        rlRun "rlFileRestore"
        rlRun "echo ${PROTECTED_SYMLINKS_BACKUP_VAL} > ${PROTECTED_SYMLINKS}" 0 "Disable symlink protection"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
