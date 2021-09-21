#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /usbguard/Sanity/notifier-ipc
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard"
    rlRun "rm -rf /etc/usbguard/IPCAccessControl.d/*"
  rlPhaseEnd; }

#  ACs:
#  * usbguard add-user validates inputs and throws an error when irrelevant
#    privilege is given to a section, for example, Policy=listen
#  * 'ALL' is documented as a valid privilege string for usbguard add-user
#    command
#  * privilege listen is documented as a valid privilege for section Parameters
#  * invalid IPC configurations are removed from the documentation - this is on
#    RH portal

rlPhaseStartTest "priviledge setting" && {
  #  * usbguard add-user validates inputs and throws an error when irrelevant privilege is given to a section, for example, Policy=listen
  rlLog "check allowed permissions"
  for section in Devices Policy Parameters Exceptions; do
    for perm in list modify listen; do
      [[ "$section" == "Policy" && "$perm" == "listen" ]] && continue
      [[ "$section" == "Exceptions" ]] && [[ "$perm" == "list" || "$perm" == "modify" ]] && continue
      rlRun "usbguard add-user joe --${section,,}=$perm"
      rlRun -s "cat /etc/usbguard/IPCAccessControl.d/*"
      rlAssertGrep "$section=$perm\$" $rlRun_LOG
      rm -f $rlRun_LOG
    done
  done
  rlRun "rm -rf /etc/usbguard/IPCAccessControl.d/*"
  rlLog "check not allowed permissions"
  for section in Devices Policy Parameters Exceptions; do
    rlRun "usbguard add-user joe --${section,,}=pokus" 1-255
    rlRun -s "cat /etc/usbguard/IPCAccessControl.d/*" 1
    rlAssertNotGrep "$section=pokus\$" $rlRun_LOG
    rm -f $rlRun_LOG
  done
  rlRun "usbguard add-user joe --policy=ALL --devices=ALL --parameters=ALL"
  rlRun -s "cat /etc/usbguard/IPCAccessControl.d/*"
  rlAssertGrep 'Devices=list,modify,listen$' $rlRun_LOG
  rlAssertGrep 'Policy=list,modify$' $rlRun_LOG
  rlAssertGrep 'Parameters=list,modify,listen$' $rlRun_LOG
  rm -f $rlRun_LOG
rlPhaseEnd; }

rlPhaseStartTest "priviledge ALL documented" && {
  #  * 'ALL' is documented as a valid privilege string for usbguard add-user command
  rlRun -s "LC_ALL=c MANWIDTH=9999999 man usbguard 2>/dev/null | col -bp"
  rlAssertGrep "can also use ALL instead of privileges" $rlRun_LOG
  rm -f $rlRun_LOG
rlPhaseEnd; }

rlPhaseStartTest "priviledges documented" && {
  #  * privilege listen is documented as a valid privilege for section Parameters
  rlRun -s "LC_ALL=c MANWIDTH=9999999 man usbguard-daemon.conf 2>/dev/null | col -bp"
  for section in Devices Policy Parameters Exceptions; do
    out=""
    _in=''
    while read -r line; do
      if [[ -z "$_in" ]]; then
        [[ "$line" =~ $(echo "o\s+$section\$") ]] && {
          let _in++
          echo "$line"
        }
      else
        [[ "$line" =~ ^\s*$ ]] && continue
        if [[ "$line" =~ $(echo "o\s+(\S+):") ]]; then
          out+=" ${BASH_REMATCH[1]}"
          echo "$line"
        else
          break
        fi
      fi
    done < $rlRun_LOG
    out="${out:1}"
    case $section in
      Devices|Parameters)
        exp_perm="modify list listen"
      ;;
      Policy)
        exp_perm="modify list"
      ;;
      Exceptions)
        exp_perm="listen"
      ;;
    esac
    rlAssertEquals "check expected set of permissions for $section" "$out" "$exp_perm"
  done
  rm -f $rlRun_LOG
rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
