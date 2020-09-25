#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Sanity/default-sudo-config-files
#   Description: Test for BZ#1215400 (default /etc/sudoers file error)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfTry "Setup phase" && {
      tcfRun "rlCheckMakefileRequires"
      rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
      CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
      rlRun "cp -r ./configs $TmpDir/"
      CleanupRegister 'rlRun "popd"'
      rlRun "pushd $TmpDir"
      rlFetchRpmForInstalled sudo || ( rm -f *.rpm && yumdownloader -y sudo )
      rlRun "rpm2cpio *.rpm | cpio -idmv"
      find_path() {
        local distro ver p
        distro="$(. /etc/os-release; echo "$ID")"
        ver=($(. /etc/os-release; echo "$VERSION_ID" | grep -o '[0-9]\+'))
        rlLogDebug "$FUNCNAME(): distro=$distro, ver=( ${ver[*]} )"
        while :; do
          p="configs/$distro${ver[0]}${ver[1]:+.${ver[1]}}"
          rlLogDebug "$FUNCNAME(): trying path $p"
          [[ -d "$p" ]] && {
            echo "$p"
            return 0
          }
          [[ -z "${ver[0]}" ]] && {
            break
          }
          [[ -z "${ver[1]}" ]] && {
            ver[1]=12
            let ver[0]--
            [[ ${ver[0]} -eq -1 ]] && {
              ver[0]=''
              ver[1]=''
            }
            continue
          }
          [[ ${ver[1]} -eq 0 ]] && {
            ver[1]=''
            continue
          }
          let ver[1]--
        done
        return 1
      }
      if path=$(find_path); then
        ( cd $path; find . -type f | sed 's/^.//' | sort ) > flist
      else
        rlFail "no version to match against"
      fi
    tcfFin; }
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      tcfChk "Test phase" && {
        rlRun "rpm -qc sudo | sort | diff -u flist -"
        while read f ; do
          rlRun "diff -Bbwu <(sed -r '/^\s*#/d;/^\s*$/d' ${path}${f}) <(sed -r '/^\s*#/d;/^\s*$/d' .${f}) | sed -r '/^(\+\+\+|---)/d'; (exit \$PIPESTATUS)" 0 "check file ${f}"
        done < flist
      tcfFin; }
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    tcfChk "Cleanup phase" && {
      CleanupDo
    tcfFin; }
    tcfCheckFinal
  rlPhaseEnd; }

rlJournalPrintText
rlJournalEnd; }
