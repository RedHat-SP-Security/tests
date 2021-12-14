#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /fapolicyd/Regression/abnormal-exit
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="fapolicyd"

rlJournalStart
  rlPhaseStartSetup
    testfile="$HOME/testfile"
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    rlSESetTimestamp
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean $testfile"
  rlPhaseEnd

  rlPhaseStartTest "bz1940289"
    rlRun "touch $testfile"
    rlRun "chmod 200 $testfile"
    rlRun "chcon -t sysctl_vm_t $testfile"
    rlRun "fapStart"
    rlRun "cat $testfile"
    rlRun "fapStop"
    rlRun "rm -f $testfile"
    rlRun -s "fapServiceOut -t"
    rlAssertGrep 'shutting down' $rlRun_LOG
    rlAssertGrep 'fapolicyd.service: (succeeded|Deactivated successfully)' $rlRun_LOG -Eiq
    rlAssertGrep 'Stopped File Access Policy Daemon' $rlRun_LOG -Eiq
    rlAssertGrep 'Starting to listen for events' $rlRun_LOG
    rlAssertNotGrep 'Error receiving fanotify_event (Permission denied)' $rlRun_LOG
    rlAssertNotGrep 'Error reading (Permission denied)' $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd

  rlPhaseStartTest "blocked by permissions"
    rlRun "touch $testfile"
    rlRun "chmod 200 $testfile"
    rlRun "fapStart"
    rlRun "cat $testfile"
    rlRun "fapStop"
    rlRun "rm -f $testfile"
    rlRun -s "fapServiceOut -t"
    rlAssertGrep 'shutting down' $rlRun_LOG
    rlAssertGrep 'fapolicyd.service: (succeeded|Deactivated successfully)' $rlRun_LOG -Eiq
    rlAssertGrep 'Stopped File Access Policy Daemon' $rlRun_LOG -Eiq
    rlAssertGrep 'Starting to listen for events' $rlRun_LOG
    rlAssertNotGrep 'Error receiving fanotify_event (Permission denied)' $rlRun_LOG
    rlAssertNotGrep 'Error reading (Permission denied)' $rlRun_LOG
    rm -f $rlRun_LOG
  rlPhaseEnd

  rlPhaseStartTest "blocked by selinux - modify fapolicyd module"
    rlSESetTimestamp selinux
    CleanupRegister --mark 'rlRun "semodule -X 500 -r fapolicyd"'
    rlRun "semodule -c -E fapolicyd"
    rlRun "sed -i '/sysctl_type/d' fapolicyd.cil"
    rlRun "semodule -X 500 -i fapolicyd.cil"
    rlRun "touch $testfile"
    rlRun "chmod 200 $testfile"
    rlRun "chcon -t sysctl_vm_t $testfile"
    rlRun "fapStart"
    rlRun "cat $testfile" 1-255
    rlRun "fapStop"
    rlRun "rm -f $testfile"
    rlRun -s "fapServiceOut -t"
    rlAssertGrep 'shutting down' $rlRun_LOG
    rlAssertGrep 'fapolicyd.service: (succeeded|Deactivated successfully)' $rlRun_LOG -Eiq
    rlAssertGrep 'Stopped File Access Policy Daemon' $rlRun_LOG -Eiq
    rlAssertGrep 'Starting to listen for events' $rlRun_LOG
    rlAssertGrep 'Error receiving fanotify_event (Permission denied)' $rlRun_LOG
    rlAssertNotGrep 'Error reading (Permission denied)' $rlRun_LOG
    rm -f $rlRun_LOG
    rlRun "rlSEAVCCheck --expect sysctl_vm_t selinux"
    CleanupDo --mark
  rlPhaseEnd

  rlPhaseStartTest "blocked by selinux - use a new type"
    rlSESetTimestamp selinux
    CleanupRegister --mark 'rlRun "semodule -r newtype"'
    cat > newtype.te <<EOF
module newtype 1.0;

type mujtyp_file_t;

require {
  type unconfined_t;
  type fs_t;
  class file { open read unlink relabelto relabelfrom getattr };
  class filesystem { associate };
}

allow unconfined_t mujtyp_file_t : file { open read getattr unlink relabelto relabelfrom } ;
allow mujtyp_file_t fs_t : filesystem { associate };

EOF
    rlRun "make -f /usr/share/selinux/devel/Makefile"
    rlRun "semodule -i newtype.pp"
    rlRun "touch $testfile"
    rlRun "chmod 200 $testfile"
    rlRun "chcon -t mujtyp_file_t $testfile"
    rlRun "fapStart"
    rlRun "cat $testfile" 1-255
    rlRun "fapStop"
    rlRun "rm -f $testfile"
    rlRun -s "fapServiceOut -t"
    rlAssertGrep 'shutting down' $rlRun_LOG
    rlAssertGrep 'fapolicyd.service: (succeeded|Deactivated successfully)' $rlRun_LOG -Eiq
    rlAssertGrep 'Stopped File Access Policy Daemon' $rlRun_LOG -Eiq
    rlAssertGrep 'Starting to listen for events' $rlRun_LOG
    rlAssertGrep 'Error receiving fanotify_event (Permission denied)' $rlRun_LOG
    rlAssertNotGrep 'Error reading (Permission denied)' $rlRun_LOG
    rm -f $rlRun_LOG
    rlRun "rlSEAVCCheck --expect mujtyp_file_t selinux"
    CleanupDo --mark
  rlPhaseEnd

  rlPhaseStartCleanup "AVC check"
    rlRun "rlSEAVCCheck --ignore sysctl_vm_t --ignore mujtyp_file_t"
  rlPhaseEnd

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd

    rlJournalPrintText
rlJournalEnd
