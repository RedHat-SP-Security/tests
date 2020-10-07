#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Sanity/run-as
#   Description: Test feature 'run as'. This means -u, -g options.
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
#   Boston, MA 02110-1151, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="sudo"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'tcfRun "testUserCleanup"'
    tcfRun "testUserSetup 5"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/sudoers.d"
    cat > /etc/sudoers.d/testing << EOF
      Defaults !requiretty
      $testUser   ALL = (ALL:ALL) NOPASSWD: ALL
      ${testUser[1]}   ALL = ( ${testUser[0]} ) NOPASSWD: ALL
      ${testUser[2]}   ALL = ( ${testUser[0]}, ${testUser[1]} ) NOPASSWD: ALL
      ${testUser[3]}   ALL = ( : ${testUserGroup[1]}, ${testUser[0]} ) NOPASSWD: ALL
      ${testUser[4]}   ALL = ( ${testUser[0]} : ${testUserGroup[2]} ) NOPASSWD: ALL
EOF
    rlRun "cat /etc/sudoers.d/testing"
  rlPhaseEnd; }

  CMD='bash -c "ps -o user:15,group:15,ruser:15,rgroup:15,args --ppid $$"'
  
  tcfTry "Tests" --no-assert && {
    test() {
      local who="$1" as="$2" as_grp="$3" exp_res="$4"
      if [[ -z "$exp_res" || "$exp_res" == "0" ]]; then
        rlRun -s "su -l $who -c 'sudo ${as:+-u $as} ${as_grp:+-g $as_grp} $CMD'"
        [[ -n "$as_grp" && -z "$as" ]] && as="$who"
        as="${as:-root}"
        as_grp="${as_grp:-$as}"
        rlAssertGrep "$as\s+$as_grp\s+$as\s+$as_grp\s+" $rlRun_LOG -Eq
        rm -f $rlRun_LOG
      else
        rlRun -s "su -l $who -c 'sudo ${as:+-u $as} ${as_grp:+-g $as_grp} $CMD'" 1
        [[ -n "$as_grp" && -z "$as" ]] && as="$who"
        as="${as:-root}"
        as_grp="${as_grp:-$as}"
        rlAssertNotGrep "$as\s+$as_grp\s+$as\s+$as_grp\s+" $rlRun_LOG -Eq
        rm -f $rlRun_LOG
      fi
    }
    rlPhaseStartTest "run as a default user" && {
      tcfChk "Test phase" && {
        tcfChk "$testUser can run as all" && {
          test $testUser "" "" "" 0
        tcfFin; }
        tcfChk "${testUser[1]} cannot run as anyone" && {
          test ${testUser[1]} "" "" 1
        tcfFin; }
        tcfChk "${testUser[2]} cannot run as anyone" && {
          test ${testUser[2]} "" "" 1
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "run as a user (-u)" && {
      tcfChk "Test phase" && {
        tcfChk "$testUser can run as all" && {
          test $testUser "root" "" 0
          test $testUser "${testUser[1]}" "" 0
          test $testUser "${testUser[2]}" "" 0
        tcfFin; }
        tcfChk "${testUser[1]} can run as $testUser" && {
          test ${testUser[1]} "root" "" 1
          test ${testUser[1]} "${testUser[0]}" "" 0
          test ${testUser[1]} "${testUser[2]}" "" 1
        tcfFin; }
        tcfChk "${testUser[2]} can run as $testUser and ${testUser[1]}" && {
          test ${testUser[2]} "root" "" 1
          test ${testUser[2]} "${testUser[0]}" "" 0
          test ${testUser[2]} "${testUser[1]}" "" 0
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "run as a group (-g)" && {
      tcfChk "Test phase" && {
        tcfChk "$testUser can run as all" && {
          test $testUser "" "root" 0
          test $testUser "" "${testUserGroup[1]}" 0
          test $testUser "" "${testUserGroup[2]}" 0
        tcfFin; }
        tcfChk "${testUser[4]} can run as ${testUserGroup[2]}" && {
          test ${testUser[4]} "" "root" 1
          test ${testUser[4]} "" "${testUserGroup[0]}" 1
          test ${testUser[4]} "" "${testUserGroup[2]}" 0
        tcfFin; }
        #tcfChk "${testUser[2]} can run as ${testUserGroup[1]}" && {
        #  test ${testUser[2]} "" "root" 1
        #  test ${testUser[2]} "" "${testUserGroup[1]}" 1
        #  test ${testUser[2]} "" "${testUserGroup[2]}" 1
        #tcfFin; }
        #tcfChk "${testUser[3]}" && {
        #  test ${testUser[2]} "" "root" 1
        #  test ${testUser[2]} "" "${testUserGroup[1]}" 0
        #  test ${testUser[2]} "" "${testUserGroup[2]}" 0
        #tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

      rlPhaseStartTest "run as both user (-u) and group (-g)" && {
      tcfChk "Test phase" && {
        tcfChk "$testUser can run as all" && {
          test $testUser "${testUser[1]}" "root" 0
          test $testUser "${testUser[2]}" "${testUserGroup[1]}" 0
          test $testUser "${testUser[1]}" "${testUserGroup[2]}" 0
        tcfFin; }
        tcfChk "${testUser[4]} can run as ${testUser[0]} ${testUserGroup[2]}" && {
          test ${testUser[4]} "${testUser[0]}" "root" 1
          test ${testUser[4]} "${testUser[0]}" "${testUserGroup[0]}" 0
          #test ${testUser[4]} "${testUser[0]}" "${testUserGroup[4]}" 0
          test ${testUser[4]} "${testUser[4]}" "${testUserGroup[4]}" 0
          test ${testUser[4]} "${testUser[0]}" "${testUserGroup[3]}" 1
          test ${testUser[4]} "${testUser[0]}" "${testUserGroup[2]}" 0
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
