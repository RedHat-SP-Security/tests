#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/config-enabled
#   Description: Test config.enable option
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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

PACKAGE="rsyslog"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup /etc/rsyslog.conf"
    rsyslogPrepareConf
    rsyslogServiceStart
    rsyslogConfigAddTo "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection TEST1)
    rsyslogConfigAddTo --begin "RULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection TESTBEGIN)
  rlPhaseEnd; }

  rlPhaseStartTest && {
    rlRun "systemd-analyze security rsyslog"
    rlRun -s "systemd-analyze security --json=short rsyslog | tr '\n' ' '"
    options=(
      AmbientCapabilities
      KeyringMode
      Delegate
      NotifyAccess
      UMask
      RestrictAddressFamilies_AF_UNIX=no
      RestrictAddressFamilies_AF_INET_INET6=no
      RestrictNamespaces_net=no
      NoNewPrivileges
      ProtectControlGroups
      ProtectHome=no
      ProtectKernelModules
      ProtectKernelTunables
      RestrictSUIDSGID
      SystemCallArchitectures
      SystemCallFilter_clock
      SystemCallFilter_debug
      SystemCallFilter_module
      SystemCallFilter_raw_io
      SystemCallFilter_reboot
      SystemCallFilter_swap
      SystemCallFilter_cpu_emulation
      SystemCallFilter_obsolete
      LockPersonality
      MemoryDenyWriteExecute
    )
    for option in "${options[@]}"; do
      echo "option $option"
      [[ "$option" =~ \ *([^=]+)(=(.*))? ]] && {
        option=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[3]}
        [[ -z "$value" ]] && value=true
        [[ "$value" == "no" ]] && value=false
        # "set":true,"name":"UMask=","json_field":"UMask"
        tmp="$(cat $rlRun_LOG | grep -Eo "\{[^{]+$option[^}]+\}")"
        rlLog "$tmp"
        if [[ "$value" == "true" ]]; then
          echo "$tmp" | grep -q '"set":true'
        else
          echo "$tmp" | grep -q '"set":false'
        fi
        rlAssert0 "check $option" $?
      }
    done    
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
