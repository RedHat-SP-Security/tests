#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/imfile-module-test
#   Description: basic testing of rsyslog imfile module
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

PACKAGE="rsyslog"
PACKAGE="${COMPONENT:-$PACKAGE}"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister "rlRun 'popd'"
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rm -f /var/log/rsyslog.test*"'
	rlRun "rm -rf /var/spool/rsyslog"
	rlRun "mkdir -p /var/spool/rsyslog"
	rlRun "restorecon /var/spool/rsyslog"
        rlRun "rsyslogPrepareConf"
        rsyslogConfigAddTo --begin "RULES" < <( rsyslogConfigCreateSection 'imfile' )
        grep -q workDirectory /etc/rsyslog.conf || {
          rsyslogConfigIsNewSyntax && rsyslogConfigAddTo --begin "GLOBALS" <<EOF
global(workDirectory="/var/lib/rsyslog")
EOF
          rsyslogConfigIsNewSyntax || rsyslogConfigAddTo --begin "GLOBALS" <<EOF
\$WorkDirectory /var/lib/rsyslog
EOF
        }
    rlPhaseEnd

    rlPhaseStartTest && {
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace 'imfile' <<EOF
module(load="imfile" PollingInterval="1")	# load imfile module
# imfile setting
# file 1
input(type="imfile"
	File="/var/log/rsyslog.test.file1"
	Tag="imfile1:"
	StateFile="stat-imfile1"
	Severity="info"
	Facility="local6")

# file 2
input(
	type="imfile"
	File="/var/log/rsyslog.test.file2"
	Tag="imfile2:"
	StateFile="stat-imfile2"
	Severity="warn"
	Facility="local6")

# Test rule
local6.info    action(type="omfile" file="/var/log/rsyslog.test.log")
local6.warn    action(type="omfile" file="/var/log/rsyslog.test.log")
EOF

        rsyslogConfigIsNewSyntax || rsyslogConfigReplace 'imfile' <<EOF
\$ModLoad imfile.so  # load imfile module
# imfile setting
# file 1

\$InputFileName /var/log/rsyslog.test.file1
\$InputFileTag imfile1:
\$InputFileStateFile stat-imfile1
\$InputFileSeverity info
\$InputFileFacility local6
\$InputRunFileMonitor
# file 2
\$InputFileName /var/log/rsyslog.test.file2
\$InputFileTag imfile2:
\$InputFileStateFile stat-imfile2
\$InputFileSeverity warn
\$InputFileFacility local6
\$InputRunFileMonitor

\$InputFilePollInterval 1 # decreasing polling interval to 1 sec

# Test rule
local6.info    /var/log/rsyslog.test.log
local6.warn    /var/log/rsyslog.test.log
EOF

        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "touch /var/log/rsyslog.test.log /var/log/rsyslog.test.file1 /var/log/rsyslog.test.file2"
        rlRun "restorecon -Rv /var/log"
	rlRun "rm -rf /var/spool/rsyslog/* /var/lib/rsyslog/*"
        #rlRun "chcon --reference=/var/log/messages /var/log/rsyslog.test.log" 0 "Changing SElinux context on /var/log/rsyslog.test.log"
        #rlRun "chcon --reference=/var/log/messages /var/log/rsyslog.test.file1" 0 "Changing SElinux context on /var/log/rsyslog.test.file1"
        #rlRun "chcon --reference=/var/log/messages /var/log/rsyslog.test.file2" 0 "Changing SElinux context on /var/log/rsyslog.test.file2"
        rlRun "rsyslogServiceStart"

        rlRun "echo 'file1 test message' >> /var/log/rsyslog.test.file1" 0 "Sending test message into file1"
        rlRun "echo 'file2 test message' >> /var/log/rsyslog.test.file2" 0 "Sending test message into file2"
        rlRun "sleep 4" # waiting till syslog reads the file
        rlRun "grep 'imfile1: file1 test message' /var/log/rsyslog.test.log" 0 "Checking that test message from file1 was logged"
        rlRun "grep 'imfile2: file2 test message' /var/log/rsyslog.test.log" 0 "Checking that test message from file2 was logged"
    rlPhaseEnd; }

  for files_count in 10 100 200 300; do
    rlPhaseStartTest "monitor $files_count files" && {
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace 'imfile' <<EOF
module(load="imfile" PollingInterval="1")	# load imfile module
# imfile setting
$(
  for ((i=0; i<$files_count; i++)); do
    echo "# file $i
input(type=\"imfile\"
	File=\"/var/log/rsyslog.test.file$i\"
	Tag=\"imfile$i:\"
	Severity=\"info\"
	Facility=\"local6\")"
  done
)

# Test rule
local6.info    action(type="omfile" file="/var/log/rsyslog.test.log")
EOF

        rsyslogConfigIsNewSyntax || rsyslogConfigReplace 'imfile' <<EOF
\$ModLoad imfile.so  # load imfile module
# imfile setting
$(
  for ((i=0; i<$files_count; i++)); do
    echo "# file $i
\$InputFileName /var/log/rsyslog.test.file$i
\$InputFileTag imfile$i:
\$InputFileSeverity info
\$InputFileFacility local6
\$InputRunFileMonitor"
  done
)
\$InputFilePollInterval 1 # decreasing polling interval to 1 sec

# Test rule
local6.info    /var/log/rsyslog.test.log
EOF

        rlRun "rsyslogPrintEffectiveConfig -n"
        for ((i=0; i<$files_count; i++)); do
          touch /var/log/rsyslog.test.file$i
        done
        rlRun "restorecon -Rv /var/log"
	rlRun "rm -rf /var/spool/rsyslog/* /var/lib/rsyslog/*"
        rlRun "rsyslogServiceStart"

        for ((i=0; i<$files_count; i++)); do
          rlRun "echo 'file$i test message' >> /var/log/rsyslog.test.file$i" 0 "Sending test message into file$i"
        done
	rlRun "sleep 3s" # waiting till syslog reads the file
        rlRun "rsyslogServiceStop"
        for ((i=0; i<$files_count; i++)); do
          rlAssertGrep "imfile$i: file$i test message" /var/log/rsyslog.test.log
        done
        rlRun "rm -f /var/log/rsyslog.test.file*"
    rlPhaseEnd; }
  done

   rsyslogConfigIsNewSyntax && {
    rlPhaseStartTest "startmsg.regex" && {
        rsyslogConfigReplace 'imfile' <<EOF
module(load="imfile" PollingInterval="1")	# load imfile module
# imfile setting
# file 1
input(type="imfile"
	File="/var/log/rsyslog.test"
	startmsg.regex="^.*A"
	Tag="imfile"
	Severity="info"
	Facility="local6")
# Test rule
local6.info    action(type="omfile" file="/var/log/rsyslog.test.log")
EOF

        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "> /var/log/rsyslog.test.log; > /var/log/rsyslog.test"
        rlRun "restorecon -Rv /var/log"
	rlRun "rm -rf /var/spool/rsyslog/* /var/lib/rsyslog/*"
        rlRun "rsyslogServiceStart"

        rlRun "echo 'A message1
    B secondline
    B thirdline
A message2
    B secondline
    B thirdline
' >> /var/log/rsyslog.test" 0 "Sending test message into file"
        rlRun "echo 'file test message2' >> /var/log/rsyslog.test" 0 "Sending test message into file"
        rlRun "sleep 4" # waiting till syslog reads the file
        rlRun "rsyslogServiceStop"
        rlRun "cat /var/log/rsyslog.test.log"
        rlAssertGrep 'imfile A message1\\n    B secondline\\n    B thirdline' /var/log/rsyslog.test.log
        rlAssertNotGrep 'imfile A message2\\n    B secondline\\n    B thirdline' /var/log/rsyslog.test.log
    rlPhaseEnd; }

    if ! rlIsRHEL '<8'; then
      rlPhaseStartTest "endmsg.regex" && {
        rsyslogConfigReplace 'imfile' <<EOF
module(load="imfile" PollingInterval="1")	# load imfile module
# imfile setting
# file 1
input(type="imfile"
	File="/var/log/rsyslog.test"
	endmsg.regex="^.*B"
	Tag="imfile"
	Severity="info"
	Facility="local6")
# Test rule
local6.info    action(type="omfile" file="/var/log/rsyslog.test.log")
EOF

        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "> /var/log/rsyslog.test.log; > /var/log/rsyslog.test"
        rlRun "restorecon -Rv /var/log"
	rlRun "rm -rf /var/spool/rsyslog/* /var/lib/rsyslog/*"
        rlRun "rsyslogServiceStart"

        rlRun "echo 'A message1
    A secondline
    B thirdline
A message2
    A secondline
    B thirdline
' >> /var/log/rsyslog.test" 0 "Sending test message into file"
        rlRun "echo 'file test message2' >> /var/log/rsyslog.test" 0 "Sending test message into file"
        rlRun "sleep 4" # waiting till syslog reads the file
        rlRun "rsyslogServiceStop"
        rlRun "cat /var/log/rsyslog.test.log"
        rlAssertGrep 'imfile A message1\\n    A secondline\\n    B thirdline' /var/log/rsyslog.test.log
        rlAssertGrep 'imfile A message2\\n    A secondline\\n    B thirdline' /var/log/rsyslog.test.log
      rlPhaseEnd; }
    fi
   }

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

