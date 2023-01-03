#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospíšil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlCheckRecommended; rlCheckRequired"  || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    rlRun "pushd $TmpDir"
    rlRun "rlFileBackup --clean /etc/sudoers /root/{common,dir1,dir2}"

    rlRun "mkdir dir1 dir2 common"
    rlRun "echo '#! /bin/bash\necho \$0' > common/script"
    rlRun "chmod 700 common/script"
    rlRun "ln -s ../common/script dir1/script"
    rlRun "ln -s ../common/script dir2/script"
    rlRun "echo 'ALL ALL = (root) NOPASSWD: /root/dir1/script,/root/dir2/script' >> /etc/sudoers"
  rlPhaseEnd

  rlPhaseStartTest
    rlRun -s "/root/dir1/script"
    rlAssertGrep '/root/dir1/script' $rlRun_LOG
    rlRun -s "/root/dir2/script"
    rlAssertGrep '/root/dir2/script' $rlRun_LOG
    rlRun -s "sudo /root/dir1/script"
    rlAssertGrep '/root/dir1/script' $rlRun_LOG
    rlRun -s "sudo /root/dir2/script"
    rlAssertGrep '/root/dir2/script' $rlRun_LOG
  rlPhaseEnd


  rlPhaseStartCleanup
    rlRun "rlFileRestore"
    rlRun "popd"
    rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'
  rlPhaseEnd

  rlJournalPrintText
rlJournalEnd
