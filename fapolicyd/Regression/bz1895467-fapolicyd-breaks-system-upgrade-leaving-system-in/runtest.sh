#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Regression/bz1895467-fapolicyd-breaks-system-upgrade-leaving-system-in
#   Description: Test for BZ#1895467 (fapolicyd breaks system upgrade, leaving system in)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

PYTHON=`which python`
PYTHON_SUFFIX=''
[[ -x $PYTHON ]] || {
  PYTHON='/usr/libexec/platform-python'
  [[ -x $PYTHON ]] || PYTHON=`which python3`
  PYTHON_SUFFIX='3'
}
rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlImport fapolicyd/common" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckRequirements $(rlGetMakefileRequires | sed -r 's|\S+/python|$PYTHON|g;s|(systemd-python)\S*|\1${PYTHON_SUFFIX}|g')" || rlDie 'cannot continue'
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun ""fapCleanup'
    rlRun "fapSetup"
  rlPhaseEnd; }

  rlPhaseStartTest && {
    PYTHON=$(readlink -e $PYTHON)
    s=`which sleep`
    cat > test.py <<EOF
#!${PYTHON}
import time
import sys
import os
for i in range(1,1000):
  print(i)
  time.sleep(1)
  f=open("./test.py","r")
EOF
    chmod a+x ./test.py
    rlRun "./test.py &"
    rlRun "cp $PYTHON $PYTHON.mojekopie"
    rlRun "rm -f $PYTHON"
    rlRun "cp $PYTHON.mojekopie $PYTHON"
    rlRun "rm -f $PYTHON.mojekopie"
    rlRun "lsof | grep test\.py | grep deleted"
    rlRun "fapStart"
    tail -f $fapolicyd_out &
    rlRun "sleep 5"
    kill %+
    kill %1
    rlRun "fapStop"
    rlAssertGrep 'allow.*python.*:.*test\.py' $fapolicyd_out
    rlAssertNotGrep 'deny.*python.*:.*test\.py' $fapolicyd_out
  rlPhaseEnd; }

  rlPhaseStartTest "system instalability" && {
    YUM=`which yum` || YUM=`which dnf`
    rlRun "mkdir installroot"
    rlRun "$YUM -y --nogpgcheck --setopt=skip_if_unavailable=1 --installroot=$PWD/installroot install fapolicyd"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
