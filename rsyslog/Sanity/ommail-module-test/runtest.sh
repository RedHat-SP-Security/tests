#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/ommail-module-test
#   Description: tests basic ommail module functionality
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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
rlIsRHEL 5 && PACKAGE="rsyslog5"

RSYSLOG_CONF=rsyslog.conf
rlIsRHEL 4 5 6 && RSYSLOG_CONF=rsyslog.conf.el6

rlJournalStart
    rlPhaseStartSetup
        if rlIsRHEL 5 && rpm -q rsyslog; then
          rlLog "This test requires rsyslog5 package on RHEL5 and some policy changes"
          rlLog "doesn't work with RHEL5 rsyslog since BZ#702316 was closed as WONTFIX"
        else
          rlAssertRpm $PACKAGE
	rlIsRHEL 5 && rlServiceStop syslog
	rlFileBackup /etc/rsyslog.conf
	rlRun "setsebool logging_syslogd_can_sendmail 1" 0 "Enabling logging_syslogd_can_sendmail selinux boolean"
	rlRun "cat $RSYSLOG_CONF > /etc/rsyslog.conf" 0 "Updating rsyslog.conf"
	rlRun "useradd -m operator1" 0 "Adding user operator1"
	rlRun "useradd -m operator2" 0 "Adding user operator2"
          rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
          rlRun "pushd $TmpDir"
	rlServiceStart rsyslog
        fi
    rlPhaseEnd

    rlPhaseStartTest
      if rlIsRHEL '>5' || rlIsFedora || ! rpm -q rsyslog; then
        rlRun "logger -p local2.debug 'ommail test message1'" 0 "Sending 1st test message"
	sleep 10
	rlAssertGrep "ommail test message1" /var/log/ommail-test.log
	# check that the message was delivered to operator1
	rlAssertGrep 'From: <?rsyslog@' /var/spool/mail/operator1 -E
	rlAssertGrep "Subject: rsyslog ommail test" /var/spool/mail/operator1
	rlAssertGrep "ommail test message1" /var/spool/mail/operator1
	# check that the message was delivered to operator2
	rlAssertGrep "From: <?rsyslog@" /var/spool/mail/operator2 -E
	rlAssertGrep "Subject: rsyslog ommail test" /var/spool/mail/operator2
	rlAssertGrep "ommail test message1" /var/spool/mail/operator2
	sleep 10
	# now send another message - that one should not be delivered because of 60 seconds limit 
        rlRun "logger -p local2.debug 'ommail test message2'" 0 "Sending 2nd test message"
	sleep 10
	rlAssertGrep "ommail test message2" /var/log/ommail-test.log
	# check that the message was not delivered to operator1
	rlAssertNotGrep "ommail test message2" /var/spool/mail/operator1
	# check that the message was not delivered to operator2
	rlAssertNotGrep "ommail test message2" /var/spool/mail/operator2
	# and now wait 60 seconds and send another message
	rlLog "waiting 60 seconds"
	sleep 60
        rlRun "logger -p local2.debug 'ommail test message3'" 0 "Sending 3rd test message"
	sleep 10
	rlAssertGrep "ommail test message3" /var/log/ommail-test.log
	# check that the message was delivered to operator1
	rlAssertGrep "ommail test message3" /var/spool/mail/operator1
	# check that the message was delivered to operator2
	rlAssertGrep "ommail test message3" /var/spool/mail/operator2
	cat /var/spool/mail/operator1
	cat /var/spool/mail/operator2
      fi
    rlPhaseEnd

    rlPhaseStartCleanup
      if rlIsRHEL '>5' || rlIsFedora || ! rpm -q rsyslog; then
	rlRun "userdel -r operator1"
	rlRun "userdel -r operator2"
        rlRun "popd"
        rlRun "rm -r $TmpDir /var/log/ommail-test.log" 0 "Removing tmp directory and logfile"
	rlRun "setsebool logging_syslogd_can_sendmail 0" 0 "Disabling logging_syslogd_can_sendmail selinux boolean"
	rlFileRestore
	rlServiceRestore rsyslog
	rlIsRHEL 5 && rlServiceRestore syslog
      fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
