#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/rsyslog-gssapi-log-delivery-sanity
#   Description: the test can be used for testing several scenarios of rsyslog gssapi communication
#   Author: Karel Srot <ksrot@redhat.com>
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

# set client & server manually if debugging
#SERVERS="tyan-gt24-11.rhts.eng.bos.redhat.com"
#CLIENTS="kvm-guest-05.rhts.eng.bos.redhat.com"

# set up default values, if not passed
[ "$CLIENT_SETUP" != "gssapi" -a "$CLIENT_SETUP" != "plain" ] && CLIENT_SETUP=both   # variants: both gssapi plain
[ "$SERVER_SETUP" != "gssapi" ] && SERVER_SETUP=both   # variants: both gssapi

MSG=100   #number of log messages to be sent

CLIENT_SETUP_MESSAGE="Client sends gssapi and tcp/plain test messages"
[ "$CLIENT_SETUP" == "plain" ] && CLIENT_SETUP_MESSAGE="Client sends tcp/plain test messages only"
[ "$CLIENT_SETUP" == "gssapi" ] && CLIENT_SETUP_MESSAGE="Client sends gssapi test messages only"

SERVER_SETUP_MESSAGE="server is accepting messages via gssapi and tcp/plain"
[ "$SERVER_SETUP" == "gssapi" ] && SERVER_SETUP_MESSAGE="server is accepting messages via gssapi only"


# server part of the test

export REALM='RSYSLOGTEST.COM'

Server() {
    rlPhaseStartSetup "Server setup"
	# krb setup
	rlRun "wget http://pkgs.devel.redhat.com/cgit/tests/krb5/plain/common/krb5-common-lib.sh" 0 "Getting krb5 common lib"
        rlRun ". ./krb5-common-lib.sh"
        klSetup   #also stores principal at /etc/krb5.keytab
	rlRun "kadmin.local -q \"addprinc -pw rootkrb5pass root\"" 0 "Adding root user to the krb5 db"
	#rlRun "echo rootkrb5pass | kinit root" 0 "Kerberos root user authentification"

	# prepare keytab for client
	# this is not implemented, keep it just for possible use in the future, see BZ#867032
	# ---- future use ------
	#rlRun "kadmin.local -q \"addprinc -randkey host/$CLIENTS\"" 0 "Creating clients key"
	#rlRun "kadmin.local -q \"ktadd -k $TmpDir/keytab host/$CLIENTS\"" 0 "Exporting clients keytab to file"
	#rlRun "nc -l 50500 < $TmpDir/keytab &"
	#NC_PID=$!
	# ----------------------

	# rsyslog setup
    if rlIsRHEL 5 6; then
	cat > /etc/rsyslog.conf <<EOF
\$ModLoad imuxsock.so    # provides support for local system logging (e.g. via logger command)
\$ModLoad imklog.so      # provides kernel logging support (previously done by rklogd)

\$ModLoad imgssapi
\$InputGSSServerServiceName host
\$InputGSSServerPermitPlainTCP on
\$InputGSSServerRun 514

\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

*.*   /var/log/rsyslog-gssapi-log
EOF
    else
	cat > /etc/rsyslog.conf <<EOF
\$ModLoad imuxsock.so    # provides support for local system logging (e.g. via logger command)
\$ModLoad imjournal
\$ModLoad imklog.so      # provides kernel logging support (previously done by rklogd)

\$ModLoad imgssapi
\$InputGSSServerServiceName host
\$InputGSSServerPermitPlainTCP on
\$InputGSSServerRun 514

# Where to place auxiliary files
\$WorkDirectory /var/lib/rsyslog
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
# Include all config files in /etc/rsyslog.d/
\$IncludeConfig /etc/rsyslog.d/*.conf
# Turn off message reception via local log socket;
# local messages are retrieved through imjournal now.
\$OmitLocalLogging on
# File to store the position in the journal
\$IMJournalStateFile imjournal.state

*.*   /var/log/rsyslog-gssapi-log
EOF

    fi
	SERVER_SETUP_MESSAGE="server is accepting messages via gssapi and tcp/plain"
	# remove InputGSSServerPermitPlainTCP on if SERVER_SETUP=gssapi
	if [ "$SERVER_SETUP" == "gssapi" ]; then
		rlRun "sed -i 's/InputGSSServerPermitPlainTCP on/InputGSSServerPermitPlainTCP off/' /etc/rsyslog.conf"
		SERVER_SETUP_MESSAGE="server is accepting messages via gssapi only"
	fi
	cat /etc/rsyslog.conf

	rlServiceStart rsyslog
	sleep 5
        rlRun "syncSet SERVER_SETUP_READY"
    rlPhaseEnd

    rlPhaseStartTest "$SERVER_SETUP_MESSAGE"
	rlLogInfo "$CLIENT_SETUP_MESSAGE"
        # server setup goes here
	rlRun "service rsyslog status" 0 "Verify that rsyslog is running"
	rlRun "rsyslogPID=$(pidof rsyslogd)"

        rlRun "syncExp CLIENT_TEST_READY"
        rlRun "syncSet SERVER_TEST_READY"

        rlRun "syncExp CLIENT_TEST_DONE"

	sleep 10  # give server some time to log all messages
	rlRun "service rsyslog status" 0 "Verify that rsyslog is running"
	rlRun "ps $rsyslogPID" 0 "Verify that rsyslog did not stop"
	#rlServiceStop rsyslog

	# if I should receive tcp/plain messages...
	if [ "$SERVER_SETUP" == "both" ]; then
	    if [ "$CLIENT_SETUP" != "gssapi" ]; then   # client sent plain messages, check that I received all
                NUM_PLAIN=`grep --count 'rsyslog-gssapi test plain message' /var/log/rsyslog-gssapi-log`
                rlAssertEquals "Checking that 100 client tcp/plain messages was delivered" $NUM_PLAIN 100
                NUM_NC=`grep --count "rsyslog-gssapi test netcat message" /var/log/rsyslog-gssapi-log`
                rlAssertEquals "Checking that 100 netcat tcp/plain messages was delivered" $NUM_NC 100

                NUM_NC_ERR=`grep --count 'netstream session .* will be closed due to error' /var/log/rsyslog-gssapi-log`
                rlAssertGreater "Log is not supposed to be flooded with netcat errors" 2 $NUM_NC_ERR

	    fi
	    if [ "$CLIENT_SETUP" != "plain" ]; then   # client sent gssapi messages, check that I received all
                NUM_GSSAPI=`grep --count 'rsyslog-gssapi test gssapi message' /var/log/rsyslog-gssapi-log`
                rlAssertEquals "Checking that $MSG client gssapi messages was delivered" $NUM_GSSAPI $MSG
	    fi
	else   # I am receiving only gssapi messages
	    if [ "$CLIENT_SETUP" != "gssapi" ]; then  # client sent plain messages but I should not receive them
	        rlRun "grep 'rsyslog-gssapi test plain message' /var/log/rsyslog-gssapi-log" 1 "Checking that no tcp/plain message was delivered"
	        rlRun "grep 'rsyslog-gssapi test netcat message' /var/log/rsyslog-gssapi-log" 1 "Checking that no netcat tcp/plain message was delivered"
	    fi
	    if [ "$CLIENT_SETUP" != "plain" ]; then   # client sent gssapi messages, check that I received all
                NUM_GSSAPI=`grep --count 'rsyslog-gssapi test gssapi message' /var/log/rsyslog-gssapi-log`
                rlAssertEquals "Checking that $MSG client gssapi messages was delivered" $NUM_GSSAPI $MSG
	    fi
	fi

#bash
    rlPhaseEnd
}

Client() {
    rlPhaseStartSetup "Client setup"
	SEBOOL="logging_syslog_can_read_tmp"  # boolean has to be enabled
	DISABLEBOOLSTATE=false
	if getsebool $SEBOOL | grep -q off; then
	    DISABLEBOOLSTATE=true  # was off before, will restore it later
	    rlRun "setsebool $SEBOOL on" 0 "Enabling $SEBOOL on Client"
	fi
        rlRun "syncExp SERVER_SETUP_READY"
	# krb5 setup
	rlRun "authconfig --update --enablekrb5 --krb5kdc=$SERVERS --krb5realm=$REALM" 0 "Updating system to use krb5 authentication"
	# we need to get krb5 ticket
	rlRun "echo rootkrb5pass | kinit root" 0 "Kerberos root user authentification"
	# the alternative is the keytab file - but this has not been implemented in rsyslog
	# keeping for future use :-)
	# ----- future use ----
	#rlFileBackup /etc/krb5.keytab
	#rlRun "nc $SERVERS 50500 > /etc/krb5.keytab" 0 "Getting /etc/krb5.keytab from the KDC"
	#rlRun "restorecon /etc/krb5.keytab"
	# ---------------------

	# rsyslog setup
    if rlIsRHEL 5 6; then
	cat > /etc/rsyslog.conf <<EOF
\$ModLoad imuxsock.so
\$ModLoad imklog.so

\$ModLoad omgssapi
\$GSSForwardServiceName host

# send everything to the remote server

*.*   /var/log/rsyslog-gssapi-log
local1.* :omgssapi:$SERVERS:514
local2.* @@$SERVERS:514
EOF
    else
	cat > /etc/rsyslog.conf <<EOF
\$ModLoad imuxsock.so
\$ModLoad imjournal
\$ModLoad imklog.so

\$ModLoad omgssapi
\$GSSForwardServiceName host

# Where to place auxiliary files
\$WorkDirectory /var/lib/rsyslog
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
# Include all config files in /etc/rsyslog.d/
\$IncludeConfig /etc/rsyslog.d/*.conf
# Turn off message reception via local log socket;
# local messages are retrieved through imjournal now.
\$OmitLocalLogging on
# File to store the position in the journal
\$IMJournalStateFile imjournal.state

# send everything to the remote server

*.*   /var/log/rsyslog-gssapi-log
local1.* :omgssapi:$SERVERS:514
local2.* @@$SERVERS:514
EOF

    fi
	cat /etc/rsyslog.conf
    rlPhaseEnd


   rlPhaseStartTest "$CLIENT_SETUP_MESSAGE"
	rlLogInfo "$SERVER_SETUP_MESSAGE"
        rlRun "syncSet CLIENT_TEST_READY"
        rlRun "syncExp SERVER_TEST_READY"

	rlServiceStart rsyslog
	sleep 5
	rlRun "service rsyslog status" 0 "Verify that rsyslog is running"
	rlRun "rsyslogPID=$(pidof rsyslogd)"
	if [ "$CLIENT_SETUP" == "plain" ]; then
	    rlLogInfo "Sending 2x$MSG tcp/plain test messages"
	elif [ "$CLIENT_SETUP" == "gssapi" ]; then
	    rlLogInfo "Sending $MSG gssapi test messages"
	else
	    rlLogInfo "Sending 2x$MSG tcp/plain test messages mixed with with $MSG gssapi test messages"
	fi
	for I in `seq $MSG`; do
	    if [ "$CLIENT_SETUP" != "gssapi" ]; then
		echo "rsyslog-gssapi test netcat message $I" | nc -4 -p $(( 50000+$I )) $SERVERS 514   # netcat message
	        logger -p local2.info "rsyslog-gssapi test plain message $I"   # forwarded message
	    fi
	    [ "$CLIENT_SETUP" != "plain" ] && logger -p local1.info "rsyslog-gssapi test gssapi message $I"
	done
	rlRun "ps $rsyslogPID" 0 "Verify that rsyslog did not stop"
	rlRun "service rsyslog status" 0 "Verify that rsyslog is running"

        rlRun "syncSet CLIENT_TEST_DONE"

#bash
	$DISABLEBOOLSTATE && rlRun "setsebool $SEBOOL off" 0 "Restoring $SEBOOL on Client"
    rlPhaseEnd
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlLog "Server: $SERVERS"
        rlLog "Client: $CLIENTS"
	rlFileBackup /etc/rsyslog.conf
	rsyslogServiceStart
	rlServiceStop ntpd
	#rlRun "ntpdate clock.redhat.com"
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "syncSynchronize" 0 "sync both sides"
    rlPhaseEnd

    if syncIsServer; then
        Server
    elif syncIsClient; then
        Client
    else
        rlReport "Stray" "FAIL"
    fi

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"

	#  nc is not used now
	#pidof nc | grep $NC_PID && rlRun "kill -9 $!" 0 "Killing nc"

	if test -f /var/log/rsyslog-gssapi-log; then
		rlFileSubmit /var/log/rsyslog-gssapi-log
		rlRun "rm /var/log/rsyslog-gssapi-log" 0 "Removing /var/log/rsyslog-gssapi-log"
	fi
	rlRun "kdestroy"
	if echo $SERVERS | grep -q $HOSTNAME ; then
		klCleanup  # does also rlFileRestore --namespace krb5
	else
		rlRun "authconfig --update --disablekrb5" 0 "Updating system to use krb5 authentication"
	fi
	rlFileRestore
	rlServiceRestore ntpd
	rsyslogServiceRestore
    rlPhaseEnd

    rlPhaseStartTest "the other side result"
      rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
      rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
    rlPhaseEnd

rlJournalEnd
rlJournalPrintText

