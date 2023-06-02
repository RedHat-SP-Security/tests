#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/bz1326216-RFE-Include-remote-host-ip-in-some-tcp-server
#   Description: Test for BZ#1326216 ([RFE] Include remote host ip in some tcp server)
#   Author: Stefan Dordevic <sdordevi@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

# set client & server manually if debugging
# SERVERS="server.example.com"
# CLIENTS="client.example.com"

# server part of the test

Server() {
    rlPhaseStartSetup "Server setup"
        # prepare entropy generator
        pidof rngd || ENTROPY=true
        $ENTROPY && rngd -r /dev/urandom
        # prepare certificates
        SERVER_IP=`host $SERVERS | awk '/has address/ {print $NF;exit}'`
        CLIENT_IP=`host $CLIENTS | awk '/has address/ {print $NF;exit}'`

        cat > ca.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 001
expiration_days = 365
dns_name = "$SERVERS"
ip_address = "$SERVER_IP"
email = "root@$SERVERS"
crl_dist_points = "http://$SERVERS/getcrl/"
ca
cert_signing_key
crl_signing_key
EOF
        rlRun "certtool --generate-privkey --outfile ca-key.pem" 0 "Generate key for CA"
        rlRun "certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem" 0 "Generate self-signed CA cert"

        cat > server.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 002
expiration_days = 365
dns_name = "$SERVERS"
ip_address = "$SERVER_IP"
email = "root@$SERVERS"
tls_www_server
EOF
        cat server.tmpl
        rlRun "certtool --generate-privkey --outfile server-key.pem --bits 2048" 0 "Generate key for server"
        rlRun "certtool --generate-request --template server.tmpl --load-privkey server-key.pem --outfile server-request.pem" 0 "Generate server cert request"
        rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate server cert"

        cat > client.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 002
activation_date = "2004-01-29"
expiration_date = "2015-01-29"
dns_name = "$CLIENTS"
ip_address = "$CLIENT_IP"
email = "root@$CLIENTS"
tls_www_server
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"

        # provide certs for the client
        rlRun "tar -cf certs.tar ca.pem client-key.pem client-cert.pem" 0 "tar certs to archive"
        rlRun "syncSet CERTS_READY - < certs.tar"

        # rsyslog setup
        rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "cp ca.pem server-key.pem server-cert.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Copy certificates to /etc/rsyslogd.d"

        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
\$ModLoad imtcp
\$DefaultNetstreamDriver gtls
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca.pem
\$DefaultNetstreamDriverCertFile /etc/rsyslogd.d/server-cert.pem
\$DefaultNetstreamDriverKeyFile /etc/rsyslogd.d/server-key.pem
\$InputTCPServerStreamDriverAuthMode x509/name
\$InputTCPServerStreamDriverPermittedPeer $CLIENTS
\$InputTCPServerStreamDriverMode 1
\$InputTCPServerRun 6514

*.*   /var/log/bz1326216-rsyslog.log
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="x509/name"
    PermittedPeer="$CLIENTS"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
)

global(
    defaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)

input(type="imtcp" Port="6514")
*.*   action(type="omfile" file="/var/log/bz1326216-rsyslog.log")
EOF

        rlRun "rsyslogServiceStart"
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump &" 0 "Running wireshark"
        TSHARK_PID=$!
#        rlRun "tcpdump -A -i any 'host $CLIENTS and port 6514' > tcpdump.log &" 0 "Running tcpdump"
    rlPhaseEnd


    rlPhaseStartTest Server
        # server setup goes here
        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlRun "rsyslogServiceStatus"

        rlRun "syncExp CLIENT_TEST_READY"
        rlRun "syncSet SERVER_TEST_READY"

        rlRun "syncExp CLIENT_TEST_DONE"

        sleep 10; ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        CLIENT_SHORT=`echo $CLIENTS | cut -d '.' -f 1`
        NUM=`grep "$CLIENT_SHORT" /var/log/bz1326216-rsyslog.log | grep --count 'bz1326216 rsyslog-gnutls test'`
        rlAssertEquals "Checking that 500 client messages were not delivered" $NUM 0
	# check if client has send some messages in plain text, discover issue on client side
        rlRun "tshark -V -r wireshark.dump | grep 'bz1326216'" 1 "wireshark log should not contain unencrypted message"
	rlLogInfo "TLS version used (see wireshark_TLS.log for detailed log)"
	tshark -d 'tcp.port==6514,ssl' -O ssl -R 'frame.number<20' -r wireshark.dump > wireshark_TLS.log
	rlRun "egrep -o 'Version: TLS [0-9.]*' wireshark_TLS.log | sort -u"
	rlFileSubmit wireshark_TLS.log
        rlRun "rsyslogServiceStatus"
        rlRun "pidof rsyslogd" 0 "Verify that rsyslog did not stop"
        # greping CLIENT_IP not working as on some enviroments IPV-6 is used, TC can be adjusted to check if catched string beatween "from" and "will" is valid IP address
        rlAssertGrep "rsyslogd[^:]*: netstream session.*from.*will be closed due to error" /var/log/bz1326216-rsyslog.log -E
        rlAssertGrep "rsyslogd[^:]*: not permitted to talk to peer, certificate invalid" /var/log/bz1326216-rsyslog.log -E
        # seems that info is not always accurate, sometimes it's "certificate invalid: signer not found insted of next line"
        #rlAssertGrep "rsyslogd: invalid cert info:.*certificate valid from Thu Jan 29 00:00:00 2004 to Thu Jan 29 00:00:00 2015" /var/log/bz1326216-rsyslog.log -E
    rlPhaseEnd
}

Client() {
    rlPhaseStartSetup "Client setup"
        rlRun "syncExp CERTS_READY > certs.tar"
        rlRun "tar -xf certs.tar" 0 "Extract certificates"

        rlRun "mkdir /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "mv *.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Move certificates to /etc/rsyslogd.d"
        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
#\$LocalHostName $HOSTNAME
\$DefaultNetstreamDriver gtls
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca.pem
\$DefaultNetstreamDriverCertFile /etc/rsyslogd.d/client-cert.pem
\$DefaultNetstreamDriverKeyFile /etc/rsyslogd.d/client-key.pem
\$ActionSendStreamDriverAuthMode x509/name
\$ActionSendStreamDriverPermittedPeer $SERVERS
\$ActionSendStreamDriverMode 1
# rebind TCP connection every 50 messages - required for reproducer for bug 803550
\$ActionSendTCPRebindInterval 50

# send everything to the remote server
*.* @@$SERVERS:6514
EOF

        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
global(
    DefaultNetstreamDriver="gtls"
    defaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    defaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert.pem"
    defaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)

*.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    RebindInterval="50"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$SERVERS"
)
EOF
    rlPhaseEnd

    rlPhaseStartTest Client
        # client action goes here
        rlRun "syncSet CLIENT_TEST_READY"
        rlRun "syncExp SERVER_TEST_READY"

        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlLog "sending 500 test messages to the logger"
        for I in `seq 500`; do
            logger "bz1326216 rsyslog-gnutls test $I"
        done
        rlRun "rsyslogServiceStatus"
        rlRun "ps $rsyslogPID" 0 "Verify that rsyslog did not stop"

        rlRun "sleep 5" 0 "Give client 5 seconds to finish log transfer"
        rlRun "syncSet CLIENT_TEST_DONE"
    rlPhaseEnd

    rlPhaseStartTest "Bug 803550"
        PID=`pidof rsyslogd`
        lsof -p $PID | grep /dev/urandom
        rlRun "OPENED=\`lsof -p $PID | grep /dev/urandom | wc -l\`" 0 "Getting the number of opened /dev/urandom"
        rlAssertEquals "Only one /dev/urandom should be opened" 1 $OPENED
    rlPhaseEnd
}

rlJournalStart
    rlPhaseStartSetup
        rlImport --all
        rlAssertRpm $PACKAGE
        rlAssertRpm $PACKAGE-gnutls
        rlAssertRpm gnutls
        rlAssertRpm gnutls-utils
        rlRun "rpm -qa nss\* nspr\* |sort"
        rlLog "Server: $SERVERS"
        rlLog "Client: $CLIENTS"
        rlRun "rsyslogSetup"
        rlRun "rsyslogPrepareConf"
        rlRun "rsyslogServiceStop"
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    if echo $SERVERS | grep -q $HOSTNAME ; then
        Server
    elif echo $CLIENTS | grep -q $HOSTNAME ; then
        Client
    else
        rlReport "Stray" "FAIL"
    fi

    rlPhaseStartCleanup
        rlFileSubmit /var/log/bz1326216-rsyslog.log
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlRun "rm -rf /etc/rsyslogd.d/ /var/log/bz1326216-rsyslog.log" 0 "Removing /etc/rsyslogd.d/"
        rlRun "rsyslogCleanup"
        $ENTROPY && kill `pidof rngd`
    rlPhaseEnd

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
