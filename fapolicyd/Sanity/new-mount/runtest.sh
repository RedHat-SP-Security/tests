#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/trusted-execution
#   Description: The evaluator will configure fapolicyd to allow execution of executable based on path, hash and directory. The evaluator will then attempt to execute executables. The evaluator will ensure that the executables that are allowed to run has been executed and the executables that are not allowed to run will be denied.
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegisterCond 'rlRun "testUserCleanup"'
        rlRun "testUserSetup"
        CleanupRegisterCond 'rlRun "fapCleanup"'
        rlRun "fapSetup"
        CleanupRegisterCond 'rlRun "fapStop"'
        rlRun "fapStart"
        CleanupRegister 'rlRun "rm -f ./disk.img"'
        rlRun "dd if=/dev/zero of=./disk.img bs=1M count=1 skip=1024"
        rlRun "mkfs.ext4 ./disk.img"
        CleanupRegister 'rlRun "rm -rf /mnt/test_mount_point"'
        rlRun "mkdir /mnt/test_mount_point"
        CleanupRegister 'rlRun "umount -fl /mnt/test_mount_point"'
        rlRun "mount -o loop ./disk.img /mnt/test_mount_point"
        rlRun "restorecon -rvF /mnt/test_mount_point"
        rlRun "ls -ldZ /mnt/test_mount_point"
        rlRun "cp /usr/bin/id /usr/local/bin/"
        rlRun "cp /usr/bin/id /mnt/test_mount_point/"
    rlPhaseEnd

    rlPhaseStartTest && {
      rlRun "rlServiceStatus fapolicyd"
      rlRun "su -c '/usr/bin/id' - $testUser"
      rlRun "su -c '/usr/local/bin/id' - $testUser" 126
      rlRun "su -c '/mnt/test_mount_point/id' - $testUser" 126
      rlRun "fapServiceOut"
      CleanupDo --mark
    rlPhaseEnd; }


    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
