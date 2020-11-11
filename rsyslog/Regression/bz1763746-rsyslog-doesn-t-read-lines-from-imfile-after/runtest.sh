#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1763746-rsyslog-doesn-t-read-lines-from-imfile-after
#   Description: Test for BZ#1763746 (rsyslog doesn't read lines from imfile after)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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

PACKAGE="rsyslog"
rsyslogSyntax=new

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "systemctl daemon-reload"'
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/log/rsyslog.test.file1 /var/log/rsyslog.test.log /etc/systemd/system/rsyslog.service.d/"
    rlRun "mkdir -p /etc/systemd/system/rsyslog.service.d"
    rlRun "echo -e '[Service]\nStartLimitBurst=100' > /etc/systemd/system/rsyslog.service.d/10-restarts.conf"
    rlRun "systemctl daemon-reload"
    rlRun "rsyslogServiceStop"
    cat >/etc/rsyslog.conf <<EOF
global(workDirectory="/var/lib/rsyslog")
module(load="imfile")	# load imfile module
# imfile setting
# file 1
input(type="imfile"
	File="/var/log/rsyslog.test.file1"
	Tag="imfile1:"
	Severity="info"
	PersistStateInterval="1"
	Facility="local6")

# Test rule
local6.info    action(type="omfile" file="/var/log/rsyslog.test.log")
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rm -f /var/lib/rsyslog/*"
    > /var/log/rsyslog.test.file1
    rlRun "rsyslogServiceStart"
    rlRun "rsyslogServiceStatus"

  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "append one line" && {
      rlRun -s "rsyslogServiceStatus"
      rlAssertNotGrep "error accessing file '/var'" $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "echo 'test12345' > /var/log/rsyslog.test.file1"
      rlRun "sleep 1s"
      rlRun "rsyslogServiceStop"
      inode=$(stat -c %i /var/log/rsyslog.test.file1)
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun "ls -1 /var/lib/rsyslog/*:$inode" 0 "state file should be inode only"
    rlPhaseEnd; }
    rlPhaseStartTest "append second line" && {
      rlRun "rsyslogServiceStart"
      rlRun "echo 'test12345' >> /var/log/rsyslog.test.file1"
      rlRun "sleep 1s"
      rlRun "rsyslogServiceStop"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun -s "ls -1 /var/lib/rsyslog/*:$inode" 0 "state file should be inode only"
      rlAssert0 "there's no hash state file for inode $inode" $(cat $rlRun_LOG | grep -Eq "$inode:\S" || echo 0 )
      rm -f $rlRun_LOG
    rlPhaseEnd; }
    rlPhaseStartTest "grow file over 512B" && {
      rlRun "rsyslogServiceStart"
      rlRun "for ((i=0;i<1000; i++)); do echo 'test12345' >> /var/log/rsyslog.test.file1; done"
      rlRun "sleep 1s"
      rlRun "rsyslogServiceStop"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun -s "ls -1 /var/lib/rsyslog/*:$inode:*" 0 "state file should be hashed"
      rlAssert0 "there's a hash state file for inode $inode" $(cat $rlRun_LOG | grep -Eq "$inode:\S" && echo 0 )
      hash1="$rlRun_LOG"
    rlPhaseEnd; }
    rlPhaseStartTest "grow file over 512B while rsyslog is dead" && {
      rlRun "rsyslogServiceStart"
      rlRun "echo 'test12345' > /var/log/rsyslog.test.file1"
      rlRun "rsyslogServiceStop"
      rlRun "ls -1 /var/lib/rsyslog/"
      rlRun "for ((i=0;i<1000; i++)); do echo 'test12345' >> /var/log/rsyslog.test.file1; done"
      rlRun "rsyslogServiceStart"
      rlRun "echo 'test12345' >> /var/log/rsyslog.test.file1"
      rlRun "rsyslogServiceStop"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun -s "ls -1 /var/lib/rsyslog/*:$inode:*" 0 "state file should be hashed"
      rlAssert0 "there's a hash state file for inode $inode" $(cat $rlRun_LOG | grep -Eq "$inode:\S" && echo 0 )
      hash1="$rlRun_LOG"
    rlPhaseEnd; }
    rlPhaseStartTest "truncate file and append one line" && {
      rlRun "rsyslogServiceStart"
      rlRun "echo '12345test' > /var/log/rsyslog.test.file1"
      rlRun "sleep 1s"
      rlRun "rsyslogServiceStop"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun "ls -1 /var/lib/rsyslog/*:$inode" 0 "state file should be inode only"
    rlPhaseEnd; }
    rlPhaseStartTest "append second line" && {
      rlRun "rsyslogServiceStart"
      rlRun "echo '12345test' >> /var/log/rsyslog.test.file1"
      rlRun "sleep 1s"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun "ls -1 /var/lib/rsyslog/*:$inode" 0 "state file should be inode only"
    rlPhaseEnd; }
    rlPhaseStartTest "grow file over 512B without restating the service" && {
     rlRun "for ((i=0;i<1000; i++)); do echo \"12345test \$i\" >> /var/log/rsyslog.test.file1; done"
      rlRun "sleep 1s"
      rlRun "ls -1 /var/lib/rsyslog/"
      rlRun "sleep 10s"
      rlRun "tail -n 5 /var/log/rsyslog.test.log"
      rlRun "echo 'test last' >> /var/log/rsyslog.test.file1"
      rlRun "sleep 11s"
      rlRun "tail -n 5 /var/log/rsyslog.test.log"
      rlRun -s "ls -1 /var/lib/rsyslog/"
      rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
      rm -f $rlRun_LOG
      rlRun -s "ls -1 /var/lib/rsyslog/*:$inode:*" 0 "state file should be hashed"
      hash2="$rlRun_LOG"
      prev_hash="$rlRun_LOG"
      rlRun "diff -u $hash1 $hash2" 1 "check that hashes are different"
      rm -f $hash1
    rlPhaseEnd; }
    rlPhaseStartTest "truncate file and write random 1024B text line" && {
      for ((i=0; i<4; i++)); do
        rlRun "rsyslogServiceStart"
        rlRun "( base64 /dev/urandom | head -c 1024; echo '') > /var/log/rsyslog.test.file1"
        rlRun "rsyslogServiceStop"
        rlRun -s "ls -1 /var/lib/rsyslog/"
        rlAssertEquals "there's just one state file for inode $inode" $(cat $rlRun_LOG | wc -l) 1
        rm -f $rlRun_LOG
        rlRun -s "ls -1 /var/lib/rsyslog/*:$inode:*" 0 "state file should be hashed"
        rlRun "diff -u $prev_hash $rlRun_LOG" 1 "check that hashes are different"
        rm -f $prev_hash
        prev_hash="$rlRun_LOG"
      done
      rm -f $prev_hash
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
