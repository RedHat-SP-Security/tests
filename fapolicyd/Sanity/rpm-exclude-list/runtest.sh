#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckRecommended; rlCheckRequired" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    rlRun "echo 'allow perm=any all : all' > /etc/fapolicyd/rules.d/00-allow-all.rules"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {

    set_filter() {
      cat - > /etc/fapolicyd/rpm-filter.conf
      rlRun "cat /etc/fapolicyd/rpm-filter.conf"
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D > trustdb"
      echo 'TrustDB:'
      head trustdb
      echo '...'
      tail trustdb
    }

    rlPhaseStartTest "a particular directory can be included" && {
      set_filter <<EOF
+ /usr/libexec/os-prober/
EOF
      rlAssertGrep '/usr/libexec/os-prober/' trustdb
      tmp=$(cat trustdb | grep -v /usr/libexec/os-prober/)
      rlAssert0 'check no other than /usr/libexec/os-prober/ files are imported' ${#tmp}
    rlPhaseEnd; }

    rlPhaseStartTest "a particular directory can be excluded" && {
      set_filter <<EOF
- /usr/libexec/os-prober/
+ /usr/libexec/
EOF
      rlAssertNotGrep '/usr/libexec/os-prober/' trustdb
    rlPhaseEnd; }

    rlPhaseStartTest "a directory pattern can be included" && {
      set_filter <<EOF
+ /usr/libexec/os-*/
EOF
      rlAssertGrep '/usr/libexec/os-prober/' trustdb
      rlAssertGrep '/usr/libexec/os-probes/' trustdb
      tmp=$(cat trustdb | grep -v -e /usr/libexec/os-prober/ -e /usr/libexec/os-probes/)
      rlAssert0 'check no other than /usr/libexec/os-probe{r,s}/ files are imported' ${#tmp}
    rlPhaseEnd; }

    rlPhaseStartTest "a directory pattern can be excluded" && {
      set_filter <<EOF
- /usr/libexec/os-*/
+ /usr/libexec/
EOF
      rlAssertNotGrep '/usr/libexec/os-prober/' trustdb
      rlAssertNotGrep '/usr/libexec/os-probes/' trustdb
    rlPhaseEnd; }

    rlPhaseStartTest "a particular file can be excluded from the explicitly included directory" && {
      set_filter <<EOF
+ /usr/libexec/os-probes/
 - 50mounted-tests
EOF
      rlAssertGrep '/usr/libexec/os-probes/' trustdb
      rlAssertNotGrep '/usr/libexec/os-probes/50mounted-tests' trustdb
    rlPhaseEnd; }

    rlPhaseStartTest "a particular file can be included in the explicitly excluded directory" && {
      set_filter <<EOF
- /usr/libexec/os-probes/
 + 50mounted-tests
EOF
      rlAssertGrep '/usr/libexec/os-probes/50mounted-tests' trustdb
      tmp=$(cat trustdb | grep -v -e /usr/libexec/os-probes/50mounted-tests)
      rlAssert0 'check no other than /usr/libexec/os-probes/50mounted-tests files are imported' ${#tmp}
    rlPhaseEnd; }

    rlPhaseStartTest "a file pattern can be excluded from the explicitly included directory" && {
      set_filter <<EOF
+ /usr/libexec/os-probes/
 - 50*
EOF
      rlAssertGrep '/usr/libexec/os-probes/' trustdb
      rlAssertNotGrep '/usr/libexec/os-probes/50mounted-tests' trustdb
    rlPhaseEnd; }

    rlPhaseStartTest "a file pattern can be excluded from the explicitly included directory anywhere in the sub-tree" && {
      set_filter <<EOF
+ /usr/libexec/
 - */05*
EOF
      rlAssertGrep '/usr/libexec/os-probes/' trustdb
      rlAssertNotGrep '/usr/libexec/os-probes/mounted/05efi' trustdb
    rlPhaseEnd; }

    rlPhaseStartTest "a file pattern can be included in the explicitly excluded directory anywhere in the sub-tree" && {
      set_filter <<EOF
- /usr/libexec/
 + */05*
EOF
      rlAssertGrep '/usr/libexec/os-probes/mounted/05efi' trustdb
       tmp=$(cat trustdb | grep -v -e '.*/05.*')
       rlAssert0 'check no other than /usr/libexec/.../05* files are imported' ${#tmp}
    rlPhaseEnd; }

  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
