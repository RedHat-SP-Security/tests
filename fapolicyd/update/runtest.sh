#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/upgrade
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlImport vm/RHEL" 0-255
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rlFileRestore"'
        rlRun "rlFileBackup /etc/rsyslog.conf"
        CleanupRegister "sessionCleanup"
        CleanupRegister 'rlRun "vmCleanup"'
        rlRun "vmSetup"
    rlPhaseEnd

    sessionRunTIMEOUT=3600
    sessionExpectTIMEOUT=600
    CR=$'\r'
      if [[ "${SRC_DISTRO,,}" =~ ^rhel-[0-9]+(\.[0-9]+)?\.[0-9n]+$ ]]; then
        vmName="${SRC_DISTRO,,}"
        vmRepos=$(vmGetRepos "$vmName")
      else
        rlDie "bad format of SRC_DISTRO='$SRC_DISTRO'"
      fi
      rlPhaseStartTest "test $vmName" && {
        while :; do
          CleanupRegister --mark "vmDestroy '$vmName'; vmRemove '$vmName'"
          rlRun "vmPrepareKs $vmName"

          rlRun "vmInstall $vmName $vmName.ks" || break
          rlRun "vmStart $vmName" || break
          rlRun "sessionOpen"
          rlRun "sessionSend '$CR'; sessionWaitAPrompt; sessionSend 'virsh console $vmName --force$CR'"
          res=$?; [[ $res -eq 0 || $res -eq 254 ]] || break
          sleep 2
          rlRun 'sessionExpect -nocase "login:"' || break
          rlRun 'sessionSend "root$CR"'
          rlRun 'sessionExpect -nocase "password"'
          rlRun 'sessionSend "redhat$CR"'
          rlRun "sessionRun 'id'"
          rlRun "sessionRun 'hostname'"

          [[ -n "$PERMISSIVE" ]] && {
            rlRun 'sessionSend "setenforce 0"'
          }

          [[ -n "$NO_SELINUX" ]] && {
            rlRun "sessionRun \"grubby --args 'selinux=0' --update-kernel=ALL\""
            rlRun "sessionSend '$CR'; sessionWaitAPrompt; sessionSend 'shutdown -r now$CR'"
            rlRun 'sessionExpect -nocase "login:"' || break
            rlRun 'sessionSend "root$CR"'
            rlRun 'sessionExpect -nocase "password"'
            rlRun 'sessionSend "redhat$CR"'
          }

          [[ -z "$NO_FAPOLICYD" ]] && {
            for repo in $ADD_OLD_REPO_URL; do
              rlRun "sessionRun '(cd /etc/yum.repos.d; wget $repo)'"
            done
            rlRun "sessionRun '( yum install -y fapolicyd fapolicyd-selinux; res=\$?; sleep 5; ( exit \$res; ); )> >(cat -) 2>&1'"
            rlRun "sessionRun 'mkdir -p /etc/systemd/system/fapolicyd.service.d'"
            if [[ -n "$FAPOLICYD_DEBUG" ]]; then
              rlRun "sessionRun 'echo -e \"[Service]\\nType=simple\\nExecStart=\\nExecStart=/usr/sbin/fapolicyd --debug\" > /etc/systemd/system/fapolicyd.service.d/10-debug.conf'"
            else
              rlRun "sessionRun 'echo -e \"[Service]\\nType=simple\\nExecStart=\\nExecStart=/usr/sbin/fapolicyd --debug-deny\" > /etc/systemd/system/fapolicyd.service.d/10-debug.conf'"
            fi
            rlRun "sessionRun 'cat /etc/systemd/system/fapolicyd.service.d/10-debug.conf'"
            rlRun "sessionRun 'systemctl daemon-reload'"
            rlRun "sessionRun 'systemctl --no-pager enable --now fapolicyd'"
            rlRun "sessionRun 'systemctl --no-pager -l status fapolicyd'"
            if [[ -z "$NO_FAPOLICYD_OUT_SILENCING" ]]; then
              # process the journalctl output so we do not overwhelm the console with the update_thread messages
              rlRun 'sessionRun '\''journalctl -f -u fapolicyd | \
                while read -r line; do
                  [[ "$line" =~ $(echo "Complete:|update_thread|/\S+\s+[0-9]+\s+[0-9a-fA-F]+|miscompare|type=SOFTWARE_UPDATE") ]] && {
                    let count++
                    [[ $count -le 10 ]] && echo "$line" || silenced+="$line
";
                    [[ $count -le 5000 ]];
                  } || {
                    [[ $count -gt 10 ]] && {
                      [[ $count -gt 20 ]] && echo -e "\n\n    silenced $((count-20)) messages of the same cathegory\n"
                      echo -n "$silenced" | tail -n 10
                    }
                    unset count silenced;
                    echo "$line";
                  };
                done &'\'
            else
              let sessionRunTIMEOUT*=2
              rlRun "sessionRun 'journalctl -f -u fapolicyd &'"
            fi
            [[ -n "$FAPOLICYD_DEBUG" ]] && let sessionRunTIMEOUT*=6
          }

          rlRun "sessionRun 'tail -f /var/log/audit/audit.log &'"

          rlRun "sessionRun \"cat > /etc/yum.repos.d/upgrade.repo <<< '\$(vmGetCurrentRepos | vmGenerateRepoFileSection)'\""
          rlRun "sessionRun 'cat /etc/yum.repos.d/upgrade.repo'"
          rlRun "sessionRun 'yum clean all'"

          for repo in $ADD_NEW_REPO_URL; do
            rlRun "sessionRun '(cd /etc/yum.repos.d; wget $repo)'"
          done

          if [[ -n "$FAPOLICYD_UPDATE_FIRST" ]]; then
            rlRun -s "sessionRun 'systemctl stop fapolicyd'"
            rlRun -s "sessionRun '( yum update \*fapolicyd\* -y --allowerasing; res=\$?; sleep 5; ( exit \$res; ); )> >(cat -) 2>&1'"
            rlRun -s "sessionRun 'systemctl start fapolicyd'"
          fi
          if [[ -n "$FAPOLICYD_NO_UPDATE" ]]; then
            rlRun -s "sessionRun '( yum update -y --allowerasing --exclude fapolicyd\*; res=\$?; sleep 5; ( exit \$res; ); )> >(cat -) 2>&1'"
          else
            rlRun -s "sessionRun '( yum update -y --allowerasing; res=\$?; sleep 5; ( exit \$res; ); )> >(cat -) 2>&1'"
          fi
          rlAssertNotGrep 'Operation not permitted' $rlRun_LOG
          rlAssertNotGrep 'Kernel panic' $rlRun_LOG || break
          rlAssertGrep 'Complete!' $rlRun_LOG -iq
          rm -f $rlRun_LOG
          [[ -z "$NO_FAPOLICYD" ]] && rlRun "sessionRun 'systemctl --no-pager -l status fapolicyd'"
          rlRun "sessionSend '$CR'; sessionWaitAPrompt; sessionSend 'shutdown -r now$CR'"
          rlRun 'sessionExpect -nocase "login:"' || break
          rlRun 'sessionSend "root$CR"'
          rlRun 'sessionExpect -nocase "password"'
          rlRun 'sessionSend "redhat$CR"'
          rlRun "sessionRun 'id'"
          rlRun "sessionRun 'hostname'"
          [[ -z "$NO_FAPOLICYD" ]] && rlRun "sessionRun 'systemctl --no-pager -l status fapolicyd'"
          rlRun "sessionSend '$CR'; sessionWaitAPrompt; sessionSend 'shutdown now$CR'"
          rlRun "sessionWaitAPrompt"
          rlRun "DEBUG=1 sessionClose"
          break
        done
        CleanupDo --mark
      rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
