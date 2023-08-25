#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/bz966974-Update-librelp-to-a-version-compatible-with
#   Description: Test for BZ#966974 (Update librelp to a version compatible with)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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

# set client & server manually if debugging
# SERVERS="server.example.com"
# CLIENTS="client.example.com"

Server() {
  rlPhaseStartSetup Server-setup && {
    tcfChk "Server setup phase" && {
      cat >rsyslog.conf.add <<EOF
#module(load="imrelp")
#input(type="imrelp" port="2514")
\$ModLoad imrelp
\$InputRELPServerRun 2514
EOF
      rlRun "cat rsyslog.conf.add | tee -a /etc/rsyslog.conf"
      rlRun "rlServiceStop rsyslog"
      rlRun "cat /var/log/messages > messages"
      rlRun "rlServiceStart rsyslog"
      rlRun "syncSet SERVER_SETUP_READY"
    tcfFin; }
  rlPhaseEnd; }

  rlPhaseStartTest Server && {
    tcfChk "Server phase" && {
      rlRun "syncExp CLIENT_DONE"
      rlRun "rlServiceStop rsyslog"
      rlRun "diff messages /var/log/messages > messages.log" 0-255
      rlRun "cat messages.log"
      rlAssertGrep "relptest" messages.log
    tcfFin; }
  rlPhaseEnd; }
}

Client() {
  rlPhaseStartSetup Client-setup && {
    tcfChk "Client setup phase" && {
      cat >rsyslog.conf.add <<EOF
#module(load="omrelp")
#action(type="omrelp" target="$syncSERVER" port="2514")
\$ModLoad omrelp
*.* :omrelp:$syncSERVER:2514
EOF
      rlRun "cat rsyslog.conf.add | tee -a /etc/rsyslog.conf"
      rlRun "rlServiceStart rsyslog"
      rlRun "syncExp SERVER_SETUP_READY"
    tcfFin; }
  rlPhaseEnd; }

  rlPhaseStartTest Client && {
    tcfChk "Client phase" && {
      rlRun "logger 'relptest'"
      rlRun "syncSet CLIENT_DONE"
    tcfFin; }
  rlPhaseEnd; }
}

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfTry "Setup phase" && {
      CleanupRegister 'tcfRun "rlSEPortRestore"'
      tcfRun "rlSEPortAdd tcp 2514 syslogd_port_t"
      CleanupRegister 'tcfRun "rsyslogCleanup"'
      tcfRun "rsyslogSetup"
      rlLog "Server: $SERVERS"
      rlLog "Client: $CLIENTS"
      rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
      CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
      CleanupRegister 'rlRun "popd"'
      rlRun "pushd $TmpDir"
    tcfFin; }
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    syncIsServer && Server
    syncIsClient && Client
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd

  rlJournalPrintText
rlJournalEnd; }
