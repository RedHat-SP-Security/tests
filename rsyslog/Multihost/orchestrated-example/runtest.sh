#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/ipv6-sanity-test
#   Description: basic ipv6 sanity testing
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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
env
# run on controller only, a workaround for getting all TMT_ROLE_* variables set
[[ "$TMT_GUEST_ROLE" != "controller" ]] && { rlJournalStart; rlJournalEnd; exit; }

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie "cannot continue"
    rlRun "rlCheckRecommended; rlCheckRequired" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
	rlRun "env | grep ^TMT"
	CleanupRegister 'sessionCleanup'
	sessionRunTIMEOUT=5
	sessionExpectTIMEOUT=5
	rlRun "sessionOpen --id server"
	rlRun "sessionSend 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=yes -o PubkeyAuthentication=no $TMT_ROLE_server'"$'\n'
	rlRun "sessionExpect assword"
	rlRun "sessionSend redhat"$'\r'
	rlRun "sessionOpen --id client"
	rlRun "sessionSend 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=yes -o PubkeyAuthentication=no $TMT_ROLE_client'"$'\n'
	rlRun "sessionExpect assword"
	rlRun "sessionSend redhat"$'\r'
	rlRun "sessionRun --id server 'id; hostname'"
	rlRun "sessionRun --id client 'id; hostname'"
	server_config='\$ModLoad imtcp.so'$'\n''\$InputTCPServerRun 514'
	rlRun 'sessionRun --id server "echo \"$server_config\">/etc/rsyslog.d/tcp_server.conf"'
	rlRun 'sessionRun --id server "systemctl restart rsyslog"'
	rlRun 'sessionRun --id server "netstat -putna | grep 514"'
	rlRun 'sessionRun --id server "msg_size=\$(cat /var/log/messages | wc -l)"'
	client_config="local2.error    @@$TMT_ROLE_server"
	rlRun 'sessionRun --id client "echo \"$client_config\">/etc/rsyslog.d/tcp_client.conf"'
	rlRun 'sessionRun --id client "systemctl restart rsyslog"'
	rlRun 'sessionRun --id client "msg_size=\$(cat /var/log/messages | wc -l)"'
  rlPhaseEnd; }

  rlPhaseStartTest && {
	rlRun 'sessionRun --id client "logger -p local2.error testmessage"'
	sleep 1
	rlRun 'sessionRun --id client "tail -n +\$msg_size /var/log/messages"'
	rlRun 'sessionRun --id server "tail -n +\$msg_size /var/log/messages"'
	rlRun 'sessionRun --id server "tail -n +\$msg_size /var/log/messages | grep testmessage"'
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
	CleanupDo
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }

