#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/test-various-configuration-directives
#   Description: Tests various configuration directives
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

rlJournalStart
    rlPhaseStartSetup
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
    rlPhaseEnd

    rlPhaseStartTest "\$ActionExecOnlyOnceEveryInterval test" && {
        rsyslogConfigIsNewSyntax || rsyslogConfigReplace "TEST1" <<EOF
\$ActionExecOnlyOnceEveryInterval 3
local0.info /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log
\$ActionExecOnlyOnceEveryInterval 0
local1.info /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace "TEST1" <<EOF
local0.info    action(type="omfile" action.ExecOnlyonceEveryInterval="3" file="/var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log")
local1.info    action(type="omfile" action.ExecOnlyonceEveryInterval="0" file="/var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log")
EOF
        CleanupRegister --mark 'rlRun "rm -f /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log"'
        rsyslogServiceStart
	sleep 3  # give some time to start rsyslog
	rlRun "logger -p local0.info 'local0 test message1'" 0 "Logging local0 test message1"
	rlRun "logger -p local0.info 'local0 test message2'" 0 "Logging local0 test message2"
	rlRun "logger -p local1.info 'local1 test message1'" 0 "Logging local1 test message1"
	rlRun "logger -p local1.info 'local1 test message2'" 0 "Logging local1 test message2"
	sleep 4
	rlRun "logger -p local0.info 'local0 test message3'" 0 "Logging local0 test message3"
	rlRun "logger -p local0.info 'local0 test message4'" 0 "Logging local0 test message4"
	rlRun "logger -p local1.info 'local1 test message3'" 0 "Logging local1 test message3"
	rlRun "logger -p local1.info 'local1 test message4'" 0 "Logging local1 test message4"
	sleep 1
        rlRun "grep -q 'local0 test message1' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local0 test message1 was delivered"
        rlRun "grep -q 'local0 test message2' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 1 "Checking that local0 test message2 was not delivered"
        rlRun "grep -q 'local0 test message3' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local0 test message3 was delivered"
        rlRun "grep -q 'local0 test message4' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 1 "Checking that local0 test message4 was not delivered"
        rlRun "grep -q 'local1 test message1' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local1 test message1 was delivered"
        rlRun "grep -q 'local1 test message2' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local1 test message2 was delivered"
        rlRun "grep -q 'local1 test message3' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local1 test message3 was delivered"
        rlRun "grep -q 'local1 test message4' /var/log/rsyslog-ActionExecOnlyOnceEveryInterval-test.log" 0 "Checking that local1 test message4 was delivered"

        CleanupDo --mark
    rlPhaseEnd; }

  if rsyslogVersion '>=4.5.1'; then   # feature available since 4.5.1
    rlPhaseStartTest "\$ActionSendTCPRebindInterval test, bz1645245" && {
        rsyslogConfigIsNewSyntax || rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
\$ModLoad imtcp.so
\$ActionSendTCPRebindInterval 3
local0.info @@127.0.0.1:514
\$RuleSet TestRuleSet

local0.info     /var/log/rsyslog-TCPServerRebind-test.log
\$InputTCPServerBindRuleset TestRuleSet
\$InputTCPServerRun 514
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
module(load="imtcp")
local0.info    action(type="omfwd" Protocol="tcp" port="514" RebindInterval="3" Target="127.0.0.1")
ruleset(name="TestRuleSet"){
local0.info    action(type="omfile" file="/var/log/rsyslog-TCPServerRebind-test.log")
}
input(type="imtcp" port="514" ruleset="TestRuleSet")
EOF
	CleanupRegister --mark 'rlRun "rm -f /var/log/rsyslog-TCPServerRebind-test.log"'
        rsyslogServiceStart
	sleep 3  # wait for rsyslogd to start
	PID=`pidof rsyslogd`
	for I in `seq 10`; do
	    rlRun "logger -p local0.info 'test message $I'" 0 "Logging test message $I"
	    rlRun "lsof -i 4 -a -p $PID -F n | tail -n 1 >> conn_details" 0 "Read connection details"
	    sleep 3
	done
	rlRun "sleep 2" #wait until all messages arrive
	for I in `seq 10`; do
            rlRun "grep -q 'test message $I' /var/log/rsyslog-TCPServerRebind-test.log" 0 "Checking that test message $I was delivered"
	done
	uniq -c conn_details
	rlRun "uniq -c conn_details | egrep -v '^[[:space:]]*[1234] '" 1 "Each port can be listed at most 4 times"
	CleanupDo --mark
    rlPhaseEnd; }
  fi

  if rsyslogVersion '>=5.8.10'; then   # feature available since 5.8.10
    rlPhaseStartTest "\$PreserveFQDN test, related bz#805424" && {
      fqdn=$(hostname -f)
      short=$(hostname -s)
      if [[ "$short" == "$fqdn" ]]; then
        rlFail "there's no difference between fqdn and shot name on this machine!"
      else
        rsyslogConfigIsNewSyntax || {
          rsyslogConfigPrepend --begin "MODULES" /etc/rsyslog.conf < <(rsyslogConfigCreateSection FQDN <<EOF
\$PreserveFQDN on
EOF
)
          rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
*.* /var/log/rsyslog-PreserveFQDN-test.log
EOF
        }
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
global(preserveFQDN="on")
*.* action(type="omfile" file="/var/log/rsyslog-PreserveFQDN-test.log")
EOF
        CleanupRegister --mark 'rlRun "rm -f /var/log/rsyslog-PreserveFQDN-test.log"'
        rsyslogServiceStart
        sleep 3  # wait for rsyslogd to start
        PID=`pidof rsyslogd`
        rlRun "logger -p local0.info 'test message from logger command'" 0 "Logging test using logger command"
        rsyslogServiceStart
        sleep 1
        cat /var/log/rsyslog-PreserveFQDN-test.log
        [[ "$HOSTNAME" == "$fqdn" ]]
        rlAssert0 "Checking that my hostname $HOSTNAME is FQDN" $?
        rlRun "grep -q '$HOSTNAME' /var/log/rsyslog-PreserveFQDN-test.log" 0 "Checking that FQDN is used in log messages"
        rlIsRHEL 5 || rlRun "grep -v '$HOSTNAME' /var/log/rsyslog-PreserveFQDN-test.log" 1 "Checking that all messages are using the FQDN"  # bz847967 wontfix on RHEL5
        CleanupDo --mark
      fi
    rlPhaseEnd; }
  fi

  if rsyslogVersion '>=5.8.10'; then   # feature available probably since 5.8.10
    rlPhaseStartTest "\$LocalHostName test" && {
	NICKNAME=nickname.`hostname -d`

        rsyslogConfigIsNewSyntax || {
          rsyslogConfigReplace "FQDN" /etc/rsyslog.conf <<EOF
\$LocalHostName $NICKNAME
EOF
          rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
*.* /var/log/rsyslog-LocalHostName-test.log
EOF
        }
        rsyslogConfigIsNewSyntax && rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
global(localHostname="$NICKNAME")
*.* action(type="omfile" file="/var/log/rsyslog-LocalHostName-test.log")
EOF
        CleanupRegister --mark 'rlRun "rm -f /var/log/rsyslog-LocalHostName-test.log"'
        rsyslogServiceStart
	sleep 3  # wait for rsyslogd to start
	PID=`pidof rsyslogd`
	rlRun "logger -p local0.info 'test message from logger command'" 0 "Logging test using logger command"
        rsyslogServiceStart
	sleep 1
	cat /var/log/rsyslog-LocalHostName-test.log
        rlRun "grep -q '$NICKNAME' /var/log/rsyslog-LocalHostName-test.log" 0 "Checking that $NICKNAME was used in log messages"
        rlIsRHEL 5 || rlRun "grep -v '$NICKNAME' /var/log/rsyslog-LocalHostName-test.log" 1 "Checking that all messages are using $NICKNAME"  # won'tfix on rhel5
        CleanupDo --mark
    rlPhaseEnd; }
  fi


  if rsyslogVersion '>=8.33' && rsyslogConfigIsNewSyntax; then
    #rhel8, new syntax only
    rlPhaseStartTest 'variables.casesensitive' && {
      CleanupRegister --mark 'rlRun "rm -f /var/log/mytest.log"'
      CleanupRegister 'rsyslogConfigReplace TESTBEGIN'
      rsyslogConfigReplace "TESTBEGIN" /etc/rsyslog.conf <<'EOF'
global(variables.casesensitive="on")
EOF
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="mmjsonparse")
local0.info :mmjsonparse:
template(name="json" type="string" string="%TIMESTAMP% %HOSTNAME% %syslogtag%: %$!all-json%\n")
if ($!foo contains "bar") then {
   action(type="omfile" file="/var/log/mytest.log" template="json")
}
EOF
      rlRun "rm -f /var/log/mytest.log"
      rsyslogServiceStart
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStatus"
      rlRun "sleep 3s"
      rlRun "logger -p local0.info '@cee: {\"Foo\":\"bar\"}'"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlRun -s "cat /var/log/mytest.log" 0-255
      rlAssertNotGrep bar $rlRun_LOG
      rm -f $rlRun_LOG
      rsyslogConfigReplace "TESTBEGIN" /etc/rsyslog.conf <<'EOF'
global(variables.casesensitive="off")
EOF
      rlRun "rm -f /var/log/mytest.log"
      rsyslogServiceStart
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStatus"
      rlRun "sleep 3s"
      rlRun "logger -p local0.info '@cee: {\"Foo\":\"bar\"}'"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlRun -s "cat /var/log/mytest.log" 0-255
      rlAssertGrep bar $rlRun_LOG
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }


    rlPhaseStartTest "tcp_frameDelimiter" && {
      CleanupRegister --mark 'rsyslogServiceRestore'
      CleanupRegister 'rsyslogConfigReplace "TEST1"'
      rlRun "nc -l 127.0.0.1 514 > >(tee nc.out) &"
      CleanupRegister 'kill $(pidof nc)'
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
local0.info   action(type="omfwd"
target="127.0.0.1"
port="514"
protocol="tcp"
tcp_framedelimiter="120"
)
EOF
      rsyslogServiceStart
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStatus"
      rlRun "sleep 3"
      rlRun "logger -p local0.info test"
      rlRun "sleep 5"
      rlRun "rsyslogServiceStop"
      rlRun "cat nc.out"
      rlAssertGrep 'testx' nc.out
      CleanupDo --mark
    rlPhaseEnd; }
  fi

  if rsyslogVersion '>=8.24.0-38' && rsyslogConfigIsNewSyntax; then
    rlPhaseStartTest "imjournal fsync, bz1696686" && {
      CleanupRegister --mark 'rsyslogServiceRestore'
      CleanupRegister 'rlRun "rlFileRestore --namespace fsync"'
      rlRun "rlFileBackup --clean --namespace fsync /etc/rsyslog.conf"
      rsyslogConfigReplace "MODLOAD IMJOURNAL" /etc/rsyslog.conf <<'EOF'
module(
  load="imjournal"
  StateFile="imjournal.state"
  FSync="on"
)
EOF
      rsyslogResetLogFilePointer /var/log/messages
      rsyslogServiceStart
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStatus"
      rlRun "logger -p local0.info test"
      rlRun "sleep 3s"
      rsyslogServiceStop
      rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages | grep -v restraintd"
      rlAssertNotGrep 'error during parsing' $rlRun_LOG -Eqi
      rlAssertNotGrep 'not known' $rlRun_LOG -Eqi
      rlAssertNotGrep 'fsync' $rlRun_LOG -Eqi
      rlAssertGrep 'test' $rlRun_LOG
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }
  fi

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
