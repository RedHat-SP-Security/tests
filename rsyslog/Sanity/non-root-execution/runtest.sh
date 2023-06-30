#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "rsyslogServiceStop"
    rsroot="${testUserHomeDir}/local"
    rlRun "mkdir -p ${rsroot}{/etc,/var{/lib/rsyslog,/log,/run}}"
    cat > ${rsroot}/etc/rsyslog.conf <<EOF
global(workDirectory="${rsroot}/var/lib/rsyslog")
module(load="builtin:omfile" Template="RSYSLOG_TraditionalFileFormat")
module(load="imuxsock" SysSock.Use="on" SysSock.Name="${rsroot}/syslog")
*.* ${rsroot}/var/log/messages
EOF
    rlRun "chown -R $testUser:$testUserGroup $rsroot"
    rlRun "chmod -R a+rw $rsroot"
    rlRun "cat ${rsroot}/etc/rsyslog.conf"
    rlRun "rsyslogd -N 1 -f ${rsroot}/etc/rsyslog.conf"
    rlRun "su -c \"rsyslogd -n -d -f ${rsroot}/etc/rsyslog.conf -i ${rsroot}/var/run/rsyslog.pid &\" - $testUser"
    CleanupRegister "rlRun 'kill \$(cat ${rsroot}/var/run/rsyslog.pid)'"
    rlRun "sleep 2"
    rlRun "ps auxf | grep -v grep | grep rsyslog"
  rlPhaseEnd; }

  rlPhaseStartTest && {
    rlRun "logger -u ${rsroot}/syslog 'test message'"
    rlRun "sleep 2"
    rlRun -s "cat ${rsroot}/var/log/messages"
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
