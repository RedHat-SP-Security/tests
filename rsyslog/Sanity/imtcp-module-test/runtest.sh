#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/imtcp-module-test
#   Description: Basic imtcp module testing
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
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="rsyslog"
PACKAGE="${COMPONENT:-$PACKAGE}"

rlJournalStart
    rlPhaseStartSetup && {
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires"
        CleanupRegister 'tcfRun "rsyslogCleanup"'
        tcfRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister "rlRun 'popd'"
        rlRun "pushd $TmpDir"

        rsyslogVersion 3 && {
          rlLogInfo "This is rsyslog v3, all tests will be skipped"
          exit
        }

        CleanupRegister 'rlRun "rlSEPortRestore"'
        rlRun "rlSEPortAdd tcp 50514-50516 syslogd_port_t" 0 "Enabling ports 50514-50516 in SElinux"
	rlRun -s "semanage port -l | grep syslog"
	rlAssertGrep '50514' $rlRun_LOG
	rm -f $rlRun_LOG

        rsyslogPrepareConf
        rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'IMTCP-MODLOAD')
        rsyslogConfigAddTo "RULES"  < <(rsyslogConfigCreateSection 'IMTCP-RULES')
        rsyslogConfigAddTo --begin "RULES" < <(rsyslogConfigCreateSection 'IMTCP-RULES2')
        rsyslogConfigAddTo "GLOBALS"  < <(rsyslogConfigCreateSection 'IMTCP-GLOBALS')
    rlPhaseEnd; }

    rlPhaseStartSetup "setup test env" && {
        CleanupRegister --mark '
          rlRun "rsyslogConfigReplace IMTCP-MODLOAD"
          rlRun "rsyslogConfigReplace IMTCP-RULES"
          rlRun "rsyslogConfigReplace IMTCP-RULES2"
        '
        if rsyslogConfigIsNewSyntax; then
          rsyslogConfigReplace 'IMTCP-MODLOAD' <<'EOF'
module(load="imtcp.so")
EOF
          rsyslogConfigReplace 'IMTCP-RULES' <<'EOF'
template(name="TestDynFile" type="string" string="/var/log/%inputname%.log")

ruleset(name="TestRuleSet"){ ##############################
	*.*     ?TestDynFile
}

input(type="imtcp" name="remote50514" port="50514" ruleset="TestRuleSet")
input(type="imtcp" name="remote50515" port="50515" ruleset="TestRuleSet")
input(type="imtcp" name="remote50516" port="50516" ruleset="TestRuleSet")
EOF
        else
          rsyslogConfigReplace 'IMTCP-MODLOAD' <<'EOF'
$ModLoad imtcp.so
EOF
          rsyslogConfigReplace 'IMTCP-RULES' <<EOF
\$template TestDynFile,"/var/log/%inputname%.log"

\$RuleSet TestRuleSet
*.*     ?TestDynFile

\$InputTCPServerInputName remote50514
\$InputTCPServerBindRuleset TestRuleSet
\$InputTCPServerRun 50514

\$InputTCPServerInputName remote50515
\$InputTCPServerBindRuleset TestRuleSet
\$InputTCPServerRun 50515

\$InputTCPServerInputName remote50516
\$InputTCPServerBindRuleset TestRuleSet
\$InputTCPServerRun 50516

EOF
        fi

        rsyslogConfigReplace 'IMTCP-RULES2' <<EOF
#\$RuleSet RSYSLOG_DefaultRuleset
# forwarding of localX messages for the test
local4.info   @@localhost:50514
local5.info   @@localhost:50515
local6.info   @@localhost:50516
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        TMPFILE=`mktemp`
    rlPhaseEnd; }

    rlPhaseStartTest "Multiple TCP instances test" && {
	if rlIsRHEL 5; then
	    lsof -i | grep rsyslog | grep IPv4 &> $TMPFILE
	else
	    lsof -iTCP -sTCP:LISTEN | grep rsyslog | grep IPv4 &> $TMPFILE
	fi
	cat $TMPFILE
	IP4=`cat $TMPFILE | wc -l`
	rlAssertEquals "3 rsyslog instancies on IPv4 should be running" $IP4 3
	if rlIsRHEL 5; then
	    lsof -i | grep rsyslog | grep IPv6 &> $TMPFILE
	else
	    lsof -iTCP -sTCP:LISTEN | grep rsyslog | grep IPv6 &> $TMPFILE
	fi
	cat $TMPFILE
	IP6=`cat $TMPFILE | wc -l`
	rlAssertEquals "3 rsyslog instancies on IPv6 should be running" $IP6 3
    rlPhaseEnd; }

    rlPhaseStartTest "\$InputTCPServerBindRuleset and TCP forwarding test" && {
	rlRun "logger -p local4.info 'test message 50514'" 0 "Sending test message1 for port 50514"
	rlRun "logger -p local5.info 'test message 50515'" 0 "Sending test message2 for port 50515"
	rlRun "logger -p local6.info 'test message 50516'" 0 "Sending test message3 for port 50516"
	#tail /var/log/messages
	sleep 5
	rsyslogServiceStop
	sleep 3
	rlRun "grep 'test message 50514' /var/log/remote50514.log" 0 "Checking that message1 was properly delivered"
	rlRun "grep 'test message 50515' /var/log/remote50515.log" 0 "Checking that message2 was properly delivered"
	rlRun "grep 'test message 50516' /var/log/remote50516.log" 0 "Checking that message3 was properly delivered"
    rlPhaseEnd; }

    rlPhaseStartTest "\$InputTCPMaxListeners test" && {
	if rsyslogConfigIsNewSyntax; then
	  rsyslogConfigReplace "IMTCP-MODLOAD" /etc/rsyslog.conf <<EOF
module(load="imtcp.so" MaxListeners="4")
EOF
        else
	  rsyslogConfigReplace "IMTCP-MODLOAD" /etc/rsyslog.conf <<EOF
\$ModLoad imtcp.so
\$InputTCPMaxListeners 4
EOF
        fi
	rsyslogServiceStart   # rsyslog was stopped in previous testcase
	if rlIsRHEL 5; then
	    lsof -i | grep rsyslog | grep IPv4 &> $TMPFILE
	else
	    lsof -iTCP -sTCP:LISTEN | grep rsyslog | grep IPv4 &> $TMPFILE
	fi
	cat $TMPFILE
	IP4=`cat $TMPFILE | wc -l`
        rlAssertEquals "Only 2 rsyslog instancies on IPv4 should be running" $IP4 2
	if rlIsRHEL 5; then
	    lsof -i | grep rsyslog | grep IPv6 &> $TMPFILE
	else
	    lsof -iTCP -sTCP:LISTEN | grep rsyslog | grep IPv6 &> $TMPFILE
	fi
	cat $TMPFILE
	IP6=`cat $TMPFILE | wc -l`
        rlAssertEquals "Only 2 rsyslog instancies on IPv6 should be running" $IP6 2
    rlPhaseEnd; }

    rlPhaseStartCleanup 'cleanup test env' && {
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartCleanup
        CleanupDo
	rm $TMPFILE
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd

