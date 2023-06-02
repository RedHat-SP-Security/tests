#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/ipv6-sanity-test
#   Description: basic ipv6 sanity testing
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

. ./ipv6functions.sh

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"

# set client & server manually if debugging
# SERVERS="server.example.com"
# CLIENTS="client.example.com"


function performServer() {

    rlPhaseStartSetup "rsyslog test server"
	rlIsRHEL 5 && rlServiceStop syslog
        rlFileBackup /etc/rsyslog.conf
	rlFileBackup /etc/sysconfig/rsyslog
	rlRun "touch /var/log/rsyslogtest"
	rlRun "cat rsyslog.conf.server1 > /etc/rsyslog.conf" 0 "Updating /etc/rsyslog.conf for UDP test"
        rlIsRHEL 5 6 || rlRun "sed -i '/imuxsock/d' /etc/rsyslog.conf" 0 "Delete ModLoad imuxsock.so for RHEL >6"
	rlRun "echo 'SYSLOGD_OPTIONS=\"-c 4 -6\"' > /etc/sysconfig/rsyslog" 0 "Making rsyslog to listen on IPv6 only"
	cat /etc/rsyslog.conf
	rlServiceStart rsyslog
    rlPhaseEnd

    rlPhaseStartTest Server

        rlRun "syncExp CLIENT_TEST_READY" 0 "Waiting till client is ready for the test"
	rlRun "syncSet SERVER_TEST1_READY" 0 "Server ready for the test1"
        rlRun "syncExp CLIENT_TEST1_DONE" 0 "Waiting for the client"

	tail /var/log/rsyslogtest
	rlRun "grep 'client IPv6 message1' /var/log/rsyslogtest" 0 "Searching for client message sent via UDP"
	rlRun "grep 'client IPv6 message2' /var/log/rsyslogtest" 1 "Should not receive client message sent via TCP"
	rlRun "grep 'client IPv4 message1' /var/log/rsyslogtest" 1 "Should not receive client message sent via UDP IPv4"
	
	rlRun "cat rsyslog.conf.server2 > /etc/rsyslog.conf" 0 "Updating /etc/rsyslog.conf for TCP test"
        rlIsRHEL 5 6 || rlRun "sed -i '/imuxsock/d' /etc/rsyslog.conf" 0 "Delete ModLoad imuxsock.so for RHEL >6"
	rlRun "service rsyslog restart" 0 "Restarting rsyslog"
	sleep 30

	rlRun "syncSet SERVER_TEST2_READY" 0 "Server ready for the test2"
        rlRun "syncExp CLIENT_TEST2_DONE" 0 "Waiting for the client"
	tail /var/log/rsyslogtest

	rlRun "grep 'client IPv6 message3' /var/log/rsyslogtest" 1 "Should not receive client message sent via UDP"
	rlRun "grep 'client IPv6 message4' /var/log/rsyslogtest" 0 "Searching for client message sent via TCP"
	rlRun "grep 'client IPv4 message2' /var/log/rsyslogtest" 1 "Should not receive client message sent via TCP IPv4"

    rlPhaseEnd

    rlPhaseStartCleanup "rsyslog test server"
        rlFileRestore
	rlRun "rm -f /var/log/rsyslogtest"
	rlServiceRestore rsyslog
	rlIsRHEL 5 && rlServiceRestore syslog
    rlPhaseEnd
}

function performClient() {
 
    rlPhaseStartSetup "rsyslog test client"
	rlIsRHEL 5 && rlServiceStop syslog
        rlFileBackup /etc/rsyslog.conf
	SERVER_IPv6=`getIP6Addr $SERVERS`
	SERVER_IPv4=`getIP4Addr $SERVERS`
	rlRun "cat rsyslog.conf.client > /etc/rsyslog.conf" 0 "Updating /etc/rsyslog.conf"
        rlIsRHEL 5 6 || rlRun "sed -i '/imuxsock/d' /etc/rsyslog.conf" 0 "Delete ModLoad imuxsock.so for RHEL >6"
	rlRun "sed -i 's/RSYSLOGSERVER_IPV6/$SERVER_IPv6/g' /etc/rsyslog.conf"
	rlRun "sed -i 's/RSYSLOGSERVER_IPV4/$SERVER_IPv4/g' /etc/rsyslog.conf"
	cat /etc/rsyslog.conf
	rlServiceStart rsyslog
	#disableIP4
rlPhaseEnd

   rlPhaseStartTest Client

        rlRun "syncSet CLIENT_TEST_READY" 0 "Client ready for the test"
        rlRun "syncExp SERVER_TEST1_READY" 0 "Waiting until the server is ready for the test1"
	rlRun "logger -p local1.info 'rsyslog test: client IPv6 message1'" 0 "Sending log message via UDP"
	rlRun "logger -p local2.info 'rsyslog test: client IPv6 message2'" 0 "Sending log message via TCP"
	rlRun "logger -p local3.info 'rsyslog test: client IPv4 message1'" 0 "Sending log message via IPv4"
	tail /var/log/messages
        rlRun "syncSet CLIENT_TEST1_DONE" 0 "Client test1 done"
        
	rlRun "syncExp SERVER_TEST2_READY" 0 "Waiting until the server is ready for the test2"
	rlRun "logger -p local1.info 'rsyslog test: client IPv6 message3'" 0 "Sending log message via UDP"
	rlRun "logger -p local2.info 'rsyslog test: client IPv6 message4'" 0 "Sending log message via TCP"
	rlRun "logger -p local4.info 'rsyslog test: client IPv4 message2'" 0 "Sending log message via IPv4"
	tail /var/log/messages
        rlRun "syncSet CLIENT_TEST2_DONE" 0 "Client test2 done"
   rlPhaseEnd

    rlPhaseStartCleanup "rsyslog test client"
        rlFileRestore
	#enableIP4
	rlServiceRestore rsyslog
	rlIsRHEL 5 && rlServiceRestore syslog
    rlPhaseEnd
}


rlJournalStart

    rlPhaseStartSetup
	rlRun "rlImport --all" || rlDie 'cannot continue'
	rlAssertRpm $PACKAGE
        if echo $SERVERS | grep -q $HOSTNAME ; then
            prepareServer
        elif echo $CLIENTS | grep -q $HOSTNAME ; then
            prepareClient
        else
            rlReport "Stray" "FAIL"
        fi
    rlPhaseEnd

    if echo $SERVERS | grep -q $HOSTNAME ; then
        performServer
    elif echo $CLIENTS | grep -q $HOSTNAME ; then
        performClient
    else
        rlReport "Stray" "FAIL"
    fi

    rlPhaseStartCleanup
	cleanMachine
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd

