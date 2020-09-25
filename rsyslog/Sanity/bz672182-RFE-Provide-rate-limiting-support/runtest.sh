#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/bz672182-RFE-Provide-rate-limiting-support
#   Description: Test for bz672182 ([RFE] Provide rate limiting support)
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

rlJournalStart
    rlPhaseStartSetup
      rlRun "rlImport --all" || rlDie 'cannot continue'
      rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -rf $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rsyslogServiceRestore'
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "rsyslogPrepareConf"
        tcfTry "Configure rsyslog" && { #{{{
          if rsyslogConfigIsNewSyntax; then
              if rlIsRHEL '<7'; then
                  rsyslogConfigReplace "MODLOAD IMUXSOCK" /etc/rsyslog.conf << EOF
module(load="imuxsock" SysSock.Use="on" SysSock.Name="/run/systemd/journal/syslog" SysSock.RateLimit.Interval="5" SysSock.RateLimit.Burst="10")
EOF
              else
                  rsyslogConfigReplace "MODLOAD IMJOURNAL" /etc/rsyslog.conf <<EOF
module(load="imjournal" StateFile="imjournal.state" ratelimit.interval="5" ratelimit.burst="10")
EOF
              fi
#              rsyslogConfigAddTo "RULES" /etc/rsyslog.conf <<EOF
#local2.*   action(type="omfile" file="/var/log/local2")
#EOF
          else
              if rlIsRHEL '<7'; then
                logsource='SystemLog'
              else
                logsource='Imjournal'
              fi
              rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
\$${logsource}RateLimitInterval 5
# Burst should be actually 10 but the reate limit messages is counted in so we
# need to count with that
\$${logsource}RateLimitBurst 10
#local2.*   /var/log/local2
EOF
          fi
                    #}}}
        tcfFin; }
        rlRun "rsyslogServiceStart"
    rlPhaseEnd

    rlPhaseStartTest
      tcfTry "Test phase" && {
        rlRun "sleep 5s"
        rlRun "rsyslogResetLogFilePointer /var/log/messages"
        cc=1000
        tcfTry "Generate $cc messages in 100 seconds" &&{
          progressHeader 1000 1
          (for i in `seq 1 $cc`; do
            echo "testnumber$i"
            progressDraw $i
            sleep 0.1s
          done) | logger
          progressFooter
        tcfFin; }
        rlRun "sleep 5s"
        rlRun "echo -e 'prvniradek\ndruhyradek' | logger"
        tcfChk "Check number of logged messages is around 180 (rale limit messages is counted in)" &&{
          rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
          c=$(cat $rlRun_LOG | wc -l)
          rlLog "actual count is $c"
          compare_with_tolerance $c 180 5
        tcfFin; }
        rsyslogVersion '>8.1911' && rlAssertGrep '[0-9]+ messages lost due to rate-limiting \(10 allowed within 5 seconds\)' $rlRun_LOG -Eq
        rm -f $rlRun_LOG
      tcfFin; }
    rlPhaseEnd

    rlPhaseStartCleanup
      CleanupDo
      tcfCheckFinal
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
