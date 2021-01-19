#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/gid-selector
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup 2"
    test_dir=$(mktemp -d)
    CleanupRegister "rlRun 'rm -rf $test_dir'"
    rlRun "cp $(readlink -m /bin/ls) $test_dir/"
    rlRun "chmod -R a+rx $test_dir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    rlRun "sed -r -i '/^syslog_format = /d' /etc/fapolicyd/fapolicyd.conf"
    rlRun "echo 'syslog_format = rule,dec,perm,auid,pid,gid,exe,:,path,ftype' >> /etc/fapolicyd/fapolicyd.conf"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "deny GID=0" && {
      rules="$(cat /etc/fapolicyd/fapolicyd.rules)"
      CleanupRegister --mark "echo '$rules' > /etc/fapolicyd/fapolicyd.rules" 2> /dev/null
      echo "deny_audit perm=any gid=0 : dir=$test_dir" > /etc/fapolicyd/fapolicyd.rules
      echo "allow perm=any all : dir=$test_dir" >> /etc/fapolicyd/fapolicyd.rules
      echo "$rules" >> /etc/fapolicyd/fapolicyd.rules
      rlRun "cat /etc/fapolicyd/fapolicyd.rules"
      CleanupRegister 'rlRun "fapStop"'
      rlRun "fapStart"
      rlRun "$test_dir/ls" 126
      rlRun "su - $testUser -c 'id'"
      rlRun "su - $testUser -c '$test_dir/ls'"
      CleanupDo --mark
      rlRun "cat $fapolicyd_out"
    rlPhaseEnd; }


    rlPhaseStartTest "deny primary GID=$testUserGID" && {
      rules="$(cat /etc/fapolicyd/fapolicyd.rules)"
      CleanupRegister --mark "echo '$rules' > /etc/fapolicyd/fapolicyd.rules" 2> /dev/null
      echo "deny_audit perm=any gid=$testUserGID : dir=$test_dir" > /etc/fapolicyd/fapolicyd.rules
      echo "allow perm=any all : dir=$test_dir" >> /etc/fapolicyd/fapolicyd.rules
      echo "$rules" >> /etc/fapolicyd/fapolicyd.rules
      rlRun "cat /etc/fapolicyd/fapolicyd.rules"
      CleanupRegister 'rlRun "fapStop"'
      rlRun "fapStart"
      rlRun "$test_dir/ls" 0
      rlRun "su - $testUser -c 'id'"
      rlRun "su - $testUser -c '$test_dir/ls'" 126
      CleanupDo --mark
      rlRun "cat $fapolicyd_out"
    rlPhaseEnd; }


    rlPhaseStartTest "deny supplementary GID=${testUserGID[1]}" && {
      rlRun "usermod -a -G ${testUserGroup[1]} $testUser"
      rules="$(cat /etc/fapolicyd/fapolicyd.rules)"
      CleanupRegister --mark "echo '$rules' > /etc/fapolicyd/fapolicyd.rules" 2> /dev/null
      echo "deny_audit perm=any gid=${testUserGID[1]} : dir=$test_dir" > /etc/fapolicyd/fapolicyd.rules
      echo "allow perm=any all : dir=$test_dir" >> /etc/fapolicyd/fapolicyd.rules
      echo "$rules" >> /etc/fapolicyd/fapolicyd.rules
      rlRun "cat /etc/fapolicyd/fapolicyd.rules"
      CleanupRegister 'rlRun "fapStop"'
      rlRun "fapStart"
      rlRun "$test_dir/ls" 0
      rlRun "su - $testUser -c 'id'"
      rlRun "su - $testUser -c '$test_dir/ls'" 126
      CleanupDo --mark
      rlRun "cat $fapolicyd_out"
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
