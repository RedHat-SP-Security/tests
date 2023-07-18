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

check_config_startservice_and_check_log() {
  # $1 - must be in the service status
  # $2 - must not be in the service status
  tcfChk "check config and service status" && {
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun -s "rsyslogConfigCheck" 0-255
      rlAssertNotGrep "error processing global" $rlRun_LOG
      [[ -n "$1" ]] && rlAssertGrep "$1" $rlRun_LOG
      [[ -n "$2" ]] && rlAssertNotGrep "$2" $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "systemctl reset-failed rsyslog"
      rlRun "rsyslogServiceStart"
      rlRun -s "rsyslogServiceStatus"
      rlAssertNotGrep "parameter 'config.enabled' not known" $rlRun_LOG
      [[ -n "$1" ]] && rlAssertGrep "$1" $rlRun_LOG
      [[ -n "$2" ]] && rlAssertNotGrep "$2" $rlRun_LOG
      rm -f $rlRun_LOG
  tcfFin; }
}

    rlPhaseStartTest 'config.enabled - action, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
if $syslogfacility-text == 'local0' then {
  action(type="omfile" file="/var/log/mytest.log" config.enabled="off")
}
EOF
      rlRun "rm -f /var/log/mytest.log"
      CleanupRegister --mark 'rlRun "rm -f /var/log/mytest.log"'
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlAssertNotExists /var/log/mytest.log || \
      rlAssertNotGrep test /var/log/mytest.log
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
if $syslogfacility-text == 'local0' then {
  action(type="omfile" file="/var/log/mytest.log" config.enabled="on")
}
EOF
      rlRun "rm -f /var/log/mytest.log"
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlAssertGrep test /var/log/mytest.log
      CleanupDo --mark
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - global, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
global(localHostname="hostname1" config.enabled="on")
global(localHostname="hostname2" config.enabled="off")
local0.info action(type="omfile" file="/var/log/rsyslog-LocalHostName-test.log")
EOF
      rlRun "rm -f /var/log/rsyslog-LocalHostName-test.log"
      CleanupRegister --mark 'rlRun "rm -f /var/log/rsyslog-LocalHostName-test.log"'
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlRun "cat /var/log/rsyslog-LocalHostName-test.log"
      rlAssertGrep hostname1 /var/log/rsyslog-LocalHostName-test.log
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
global(localHostname="hostname1" config.enabled="off")
global(localHostname="hostname2" config.enabled="on")
local0.info action(type="omfile" file="/var/log/rsyslog-LocalHostName-test.log")
EOF
      rlRun "rm -f /var/log/rsyslog-LocalHostName-test.log"
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlRun "cat /var/log/rsyslog-LocalHostName-test.log"
      rlAssertGrep hostname2 /var/log/rsyslog-LocalHostName-test.log
      CleanupDo --mark
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - input, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp")
input(type="imtcp" port="514")
EOF
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd"
      rlAssertGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG

      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp")
input(type="imtcp" port="514" config.enabled="off")
EOF
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd" 0-255
      rlAssertNotGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG

      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp")
input(type="imtcp" port="514" config.enabled="on")
EOF
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd"
      rlAssertGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - module, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp")
input(type="imtcp" port="514")
EOF
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd"
      rlAssertGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG

      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp" config.enabled="off")
input(type="imtcp" port="514")
EOF
      check_config_startservice_and_check_log "module name 'imtcp' is unknown"
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd" 0-255
      rlAssertNotGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG

      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
module(load="imtcp" config.enabled="on")
input(type="imtcp" port="514")
EOF
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun -s "netstat -putna | grep rsyslogd"
      rlAssertGrep ':514\s' $rlRun_LOG -Eq
      rm -f $rlRun_LOG
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - ruleset, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
ruleset(name="myRuleset" config.enabled="off") {}
EOF
      check_config_startservice_and_check_log
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
ruleset(name="myRuleset" config.enabled="on") {}
EOF
      check_config_startservice_and_check_log
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - parser, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
parser(name="parser.rfc3164" type="pmrfc3164")
ruleset(name="myRuleset" parser="parser.rfc3164") {}
EOF
      check_config_startservice_and_check_log "" "parser 'parser.rfc3164' unknown"
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
parser(name="parser.rfc3164" type="pmrfc3164" config.enabled="off")
ruleset(name="myRuleset" parser="parser.rfc3164" config.enabled="off") {}
EOF
      check_config_startservice_and_check_log "" "parser 'parser.rfc3164' unknown"
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
parser(name="parser.rfc3164" type="pmrfc3164" config.enabled="on")
ruleset(name="myRuleset" parser="parser.rfc3164") {}
EOF
      check_config_startservice_and_check_log "" "parser 'parser.rfc3164' unknown"
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - timezone, bz1659383' && {
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
timezone(id="CET" offset="+01:00" config.enabled="on")
timezone(id="CEST" offset="+02:00" config.enabled="off")
EOF
      check_config_startservice_and_check_log "" "error processing timezone"
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<'EOF'
timezone(id="CET" offset="+01:00" config.enabled="off")
timezone(id="CEST" offset="+02:00" config.enabled="on")
EOF
      check_config_startservice_and_check_log "" "error processing timezone"
    rlPhaseEnd; }


    rlPhaseStartTest 'config.enabled - include' && {
      cat > /etc/rsyslog.d/configEnabled.cfg <<'EOF'
local0.info action(type="omfile" file="/var/log/mytest.log")
EOF
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
include(file="/etc/rsyslog.d/configEnabled.cfg" config.enabled="off")
EOF
      rlRun "rm -f /var/log/mytest.log"
      CleanupRegister --mark 'rlRun "rm -f /var/log/mytest.log"'
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlAssertNotExists /var/log/mytest.log || \
      rlAssertNotGrep test /var/log/mytest.log
      rsyslogConfigReplace "TEST1" /etc/rsyslog.conf <<EOF
include(file="/etc/rsyslog.d/configEnabled.cfg" config.enabled="on")
EOF
      rlRun "rm -f /var/log/mytest.log"
      check_config_startservice_and_check_log
      rlRun "sleep 3s"
      rlRun "logger -p local0.info test"
      rlRun "sleep 1s"
      rlAssertGrep test /var/log/mytest.log
      CleanupDo --mark
    rlPhaseEnd; }


    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
