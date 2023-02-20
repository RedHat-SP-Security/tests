#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
rlIsRHEL
rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlCheckMakefileRequires"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup 2"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "rsyslogServiceStop"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rsyslogServiceStop"; rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/log/rsyslog.test-cef.log"
    rsyslogConfigAddTo "GLOBALS" < <(rsyslogConfigCreateSection 'CAP')
  rlPhaseEnd; }

  exp_caps="block_suspend chown dac_override ipc_lock lease net_admin net_bind_service setgid setuid sys_admin sys_chroot syslog sys_resource"

  while read -r USER GROUP USER_ID GROUP_ID; do
    [[ "$USER" == '-' ]] && USER=''
    [[ "$GROUP" == '-' ]] && GROUP=''
    [[ "$USER_ID" == '-' ]] && USER_ID=''
    [[ "$GROUP_ID" == '-' ]] && GROUP_ID=''
    rlPhaseStartTest "check capabilities of the running process${USER:+" user $USER"}${GROUP:+" group $GROUP"}${USER_ID:+" userID $USER_ID"}${GROUP_ID:+" groupID $GROUP_ID"}" && {
      rsyslogConfigReplace CAP <<EOF
${USER:+"\$PrivDropToUser $USER"}
${GROUP:+"\$PrivDropToGroup $GROUP"}
${USER_ID:+"\$PrivDropToUserID $USER_ID"}
${GROUP_ID:+"\$PrivDropToGroupID $GROUP_ID"}
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun -s 'pscap -a | grep rsyslogd' 0,1
      rlAssertNotGrep 'rsyslogd.*full' $rlRun_LOG
      caps=$(grep 'rsyslogd' $rlRun_LOG | sed -r 's/^.*rsyslogd\s*(.*)$/\1/' | tr -d ',' | tr ' ' '\n' | grep -v + | sort | tr '\n' ' ' | sed -r 's/^\s*//;s/\s*$//')
      rlLog "gathered capabilities: $caps"
      [[ -z "$USER" && -z "$USER_ID" ]]   && { USER='root';  USER_ID='0';  }
      [[ -z "$GROUP" && -z "$GROUP_ID" ]] && { GROUP='root'; GROUP_ID='0'; }
      if [[ "$USER" == "root" ]]; then
        rlAssertEquals "check the actual list of capabilities" "$caps" "$exp_caps"
      else
        rlAssertEquals "check the actual list of capabilities" "$caps" ""
      fi
      rlRun -s "ps -C rsyslogd -o user=WIDE-USER-COLUMN,group=WIDE-GROUP-COLUMN,uid,gid --no-headers"
      [[ -n "$USER" ]]     && rlAssertGrep "^(\S+\s+){0}$USER\>" $rlRun_LOG -Eq
      [[ -n "$GROUP" ]]    && rlAssertGrep "^(\S+\s+){1}$GROUP\>" $rlRun_LOG -Eq
      [[ -n "$USER_ID" ]]  && rlAssertGrep "^(\S+\s+){2}$USER_ID\>" $rlRun_LOG -Eq
      [[ -n "$GROUP_ID" ]] && rlAssertGrep "^(\S+\s+){3}$GROUP_ID\>" $rlRun_LOG -Eq
    rlPhaseEnd; }
  done <<< "
${testUser[0]} -                   -                 -
-              ${testUserGroup[1]} -                 -
${testUser[0]} ${testUserGroup[0]} -                 -
${testUser[1]} ${testUserGroup[0]} -                 -
-              -                   ${testUserUID[0]} -
-              -                   -                 ${testUserGID[1]}
-              -                   ${testUserUID[0]} ${testUserGID[0]}
-              -                   ${testUserUID[1]} ${testUserGID[0]}
${testUser[0]} -                   -                 ${testUserGID[1]}
-              ${testUserGroup[0]} ${testUserUID[1]} -"

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
