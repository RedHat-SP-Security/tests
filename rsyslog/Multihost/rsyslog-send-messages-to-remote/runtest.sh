#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/rsyslog-send-messages-to-remote
#   Description: Check that rsyslog send messages to remote if in forked debug mode
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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
. /usr/lib/beakerlib/beakerlib.sh

# set client & server manually if debugging
#SERVERS="nec-em12.rhts.eng.bos.redhat.com"
#CLIENTS="nec-em16.rhts.eng.bos.redhat.com"

ii=1000
PIDFILE=/var/run/rsyslogd.pid
rlIsRHEL '<8' && PIDFILE=/var/run/syslogd.pid

# server part of the test


check_messages() {
  local res=0 dupl msgs missing duplicates
  msgs=( $(rsyslogCatLogFileFromPointer /var/log/messages | grep -oE "communication test $MODE '[0-9]+'" | grep -oE '[0-9]+' | sort -n) )
  missing=()
  duplicates=()
  progressHeader $ii 1
  j=0
  for ((i=1; i<=ii; i++)); do
    progressDraw $i
    dupl=0
    while [[ "$i" == "${msgs[j]}" ]]; do
      let j++
      let dupl++
    done
    [[ $dupl -eq 0 ]] && missing+=("$i")
    [[ $dupl -gt 1 ]] && duplicates+=("$i")
    [[ $dupl -ne 1 ]] && res=1
  done
  progressFooter
  [[ ${#missing[@]} -gt 0 ]] && rlFail "missing messages: $(echo "${missing[*]}" | sed 's/ /, /g')"
  [[ ${#duplicates[@]} -gt 0 ]] && rlFail "duplicit messages: $(echo "${duplicates[*]}" | sed 's/ /, /g')"
  [[ $res -ne 0 ]] && rlRun "rsyslogCatLogFileFromPointer /var/log/messages"
  return $res
}

start_syslog() {
  CleanupRegister --mark "
    # stop rsyslogd
    rlRun 'kill \$(pidof rsyslogd)'
    rlRun 'sleep 5s'
    pidof rsyslogd && { rlRun 'kill -9 \$(pidof rsyslogd)'; rlRun 'rm -f $PIDFILE'; }
    :
  "
  case $MODE in
    normal)
      rlRun "/sbin/rsyslogd &> rsyslogd.out &" 0 "Starting rsyslogd in debug mode"
    ;;
    debug)
      rlRun "/sbin/rsyslogd -d &> rsyslogd.out &" 0 "Starting rsyslogd in debug mode"
    ;;
    nonforked_normal)
      rlRun "/sbin/rsyslogd -n &> rsyslogd.out &" 0 "Starting rsyslogd in debug mode"
    ;;
    nonforked_debug)
      rlRun "/sbin/rsyslogd -dn &> rsyslogd.out &" 0 "Starting rsyslogd in debug mode"
    ;;
  esac
  rlRun "sleep 5s"
  # run restorecon /dev/log since it will have wrong context (because of manual start)
  # fixing context would avoid occasional AVC denials from other services trying to log
  [ -f /dev/log ] && rlRun "restorecon /dev/log"
  rlRun "restorecon $PIDFILE"
}

stop_syslog() {
  CleanupDo --mark
}

Server() {
  rlPhaseStartTest "Server, $MODE"
    # server setup goes here
    start_syslog
    rlRun "syncSet SERVER_READY"

    rlRun "syncExp CLIENT_DONE"
    rlRun "sleep 5s"
    # check that the test message has been delivered => communication works fine
    rlRun "check_messages"
    stop_syslog
  rlPhaseEnd
}

Client() {
  rlPhaseStartTest "Client, $MODE"
    # client action goes here
    start_syslog
    rlRun "syncExp SERVER_READY"

    tcfChk "Send $ii messages" && {
      local res=0
      progressHeader $ii 1
      for i in `seq $ii`; do
        progressDraw $i
        logger -p local2.error "communication test $MODE '$i'" || {
          let res++
          break
        }
      done
      progressFooter
      (exit $res)
    tcfFin; }
    rlRun "syncSet CLIENT_DONE"
    rlRun "sleep 5s"
    rlRun "check_messages"

    stop_syslog
  rlPhaseEnd
}

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    CleanupRegister 'rlRun "RpmSnapshotRevert"; rlRun "RpmSnapshotDiscard"'
    rlRun "RpmSnapshotCreate"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup" || rlDie "cannot continue"
    rlRun "rlServiceStop rsyslog"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/rsyslog.conf /etc/rsyslog.d/test.conf /var/log/test-rsyslog.log /root/.ssh/"
    rlRun "rm -f /var/log/test-rsyslog.log"
    CleanupRegister '
      [ -f /var/log/test-rsyslog.log ] && rlFileSubmit /var/log/test-rsyslog.log
      [ -f rsyslogd.out ] && rlFileSubmit rsyslogd.out
    '
    rlRun "rlFileBackup --clean /var/spool/rsyslog" 0-255
    rlRun "rm -rf /var/spool/rsyslog"
    rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    MODES="${MODES:-"normal debug nonforked_normal nonforked_debug"}"
    syncIsClient && syncSet CLIENT_MODE "$MODES"
    syncIsServer && MODES=$(syncExp CLIENT_MODE)
    CleanupRegister 'rlRun "rlSocketRestore systemd-journald"'
    rlRun "rlSocketStop systemd-journald" 0-255
    rlRun "rlSocketStart systemd-journald"
    rlRun "rsyslogResetLogFilePointer /var/log/messages"
  rlPhaseEnd

  if [[ -n "$ANSIBLE" ]]; then
    syncIsServer && rlPhaseStartSetup "setup both sides using ansible" && {
      ls /root/.ssh/id*.pub >/dev/null 2>&1 || {
        rlRun "ssh-keygen -N '' <<<'
y'"
      }
      rlRun "cat /root/.ssh/id*.pub >> /root/.ssh/authorized_keys"
      rlRun "cat /root/.ssh/id*.pub | syncSet SSH_KEY -"
      rlRun "epel yum install ansible -y"
      CleanupRegister 'rlRun "semanage port -d -t syslogd_port_t -p tcp 50514"'
      cat > inventory.ini <<EOF
[servers]
server ansible_host=$syncSERVER
[clients]
client ansible_host=$syncCLIENT
EOF
      cat > playbook.yaml <<EOF
- name: server tcp
  hosts: servers
  roles:
    - rhel-system-roles.selinux
    - linux-system-roles.logging
  vars:
    selinux_ports:
      - ports: "{{ _port }}"
        proto: tcp
        setype: syslogd_port_t
        state: present
    logging_inputs:
      - name: system_input
        type: basics
      - name: remote_input
        type: remote
        tcp_ports: [ "{{ _port }}" ]
    logging_outputs:
      - name: files_output
        type: files
    logging_flows:
      - name: flows
        inputs: [system_input, remote_input]
        outputs: [files_output]
- name: client tcp
  hosts: clients
  roles:
    - rhel-system-roles.selinux
    - linux-system-roles.logging
  vars:
    selinux_ports:
      - ports: "{{ _port }}"
        proto: tcp
        setype: syslogd_port_t
        state: present
    logging_inputs:
        - name: system_input
          type: basics
    logging_outputs:
        - name: files_output
          type: files
        - name: forward_output
          type: forwards
          facility: local2
          target: $syncSERVER_IP
          tcp_port: "{{ _port }}"
    logging_flows:
        - name: flows
          inputs: [system_input]
          outputs: [files_output, forward_output]
EOF
      rlRun "cat playbook.yaml"
      rlRun "syncExp CLIENT_SETUP_READY"
      rlRun "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yaml --extra-vars '_port=50514'"
      rlRun "syncSet SETUP_DONE"
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
    rlPhaseEnd; }
    syncIsClient && rlPhaseStartSetup "setup both sides using ansible" && {
      rlRun "syncExp SSH_KEY >> /root/.ssh/authorized_keys"
      rlRun "syncSet CLIENT_SETUP_READY"
      CleanupRegister 'rlRun "semanage port -d -t syslogd_port_t -p tcp 50514"'
      rlRun "syncExp SETUP_DONE"
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
    rlPhaseEnd; }
  else
    syncIsServer && rlPhaseStartSetup "Server setup" && {
      # rsyslog setup
      cat > /etc/rsyslog.d/test.conf <<EOF
\$ModLoad imtcp.so
\$InputTCPServerRun 514
EOF
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
    rlPhaseEnd; }

    syncIsClient && rlPhaseStartSetup "Client setup" && {
      # rsyslog setup
      rlRun "mkdir -p /var/spool/rsyslog && restorecon -v /var/spool/rsyslog"
      cat > /etc/rsyslog.d/test.conf <<EOF
local2.error    @@$syncOTHER_IP
EOF
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
    rlPhaseEnd; }
  fi

  for MODE in $MODES; do
    syncSynchronize
    syncIsServer && Server
    syncIsClient && Client
  done

  rlPhaseStartCleanup
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
