#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/bz672182-RFE-Provide-multi-line-message-capability
#   Description: Test for bz672182 ([RFE] Provide multi-line message capability)?
#   Author: Dalibor Pospisil <dapospis@dapospis.redhat>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="rsyslog"
PACKAGE="${BASEOS_CI_COMPONENT:-$PACKAGE}"

rlJournalStart
    rlPhaseStartSetup
      rlRun "rlImport --all" || rlDie 'cannot continue'
      rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
      tcfTry "Setup phase" && {
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -rf $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rm -f /var/log/messages_localhost"'
        CleanupRegister 'rsyslogServiceRestore'
        CleanupRegister 'rlRun "rlFileRestore"'
        rlRun "rlFileBackup --clean '/etc/rsyslog.conf'"
        rsyslogPrepareConf
        tcfTry "Configure rsyslog" && { #{{{
          rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
module(load="imtcp" DisableLFDelimiter="on" AddtlFrameDelimiter="76")

template(name="RemoteHost" type="string" string="/var/log/messages_%HOSTNAME%")

ruleset(name="remote"){ ##############################
*.* ?RemoteHost
}

input(type="imtcp" port="50514" ruleset="remote")
EOF

          rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
\$ModLoad imtcp
\$InputTCPServerDisableLFDelimiter on
\$InputTCPServerAddtlFrameDelimiter 76
#\$template RemoteHost,"$TmpDir/syslog_%HOSTNAME%/messages"
\$template RemoteHost,"/var/log/messages_%HOSTNAME%"
# Remote Logging
\$RuleSet remote
*.* ?RemoteHost
\$InputTCPServerBindRuleset remote
\$InputTCPServerRun 50514
EOF
          #}}}
        tcfFin; }
        CleanupRegister 'rlRun "rlSEPortRestore"'
        rlRun "rlSEPortAdd tcp 50514 syslogd_port_t" 0-255
        rsyslogServiceStart
      tcfFin; }
    rlPhaseEnd

    rlPhaseStartTest
      tcfTry "Test phase" && {
        if rsyslogVersion '<5' && rpm -q rsyslog; then
          rlLog "This case is valid on RHEL-5 only for rsyslog5"
        else
          rlRun "echo -e \"localhost 1r\r2r\n3rL\" | nc 127.0.0.1 50514"
          sleep 1s
          rlAssertGrep "1r#0152r#0123r" /var/log/messages_localhost
        fi
      tcfFin; }
      #PS1='[test] ' bash
    rlPhaseEnd

    rlPhaseStartCleanup
      CleanupDo
      tcfCheckFinal
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
