#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/bz1174345-RFE-Support-relp-with-tls
#   Description: Test for BZ#1174345 ([RFE] Support relp with tls)
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
rpm -q rsyslog5 && PACKAGE="rsyslog5"
rpm -q rsyslog7 && PACKAGE="rsyslog7"

# RFE - for now ony tested using new syntax
rsyslogSyntax='new'

# set client & server manually if debugging
#SERVERS="server.redhat.com"
#CLIENTS="client.redhat.com"

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
expiration_days = 365
dns_name = "$CLIENTS"
ip_address = "$CLIENT_IP"
email = "root@$CLIENTS"
tls_www_client
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"
        # see BZ#1430000, SHA1 works
        #rlRun "openssl x509 -outform der -in client-cert.pem -out client-cert.der"
        #SHA1_CLIENT=$(openssl x509 -noout -fingerprint -sha1 -in client-cert.pem | cut -d"=" -f2)
        # provide certs for the client
        rlRun "tar -cf certs.tar ca.pem client-key.pem client-cert.pem" 0 "tar certs to archive"
        if rlIsRHEL 5 6; then
            # netcat
            rlRun "nc -4 -l 50001 < certs.tar &" 0 "Make certs available for the client"
        else
            # ncat
            rlRun "nc -4 --send-only -l 50001 < certs.tar &" 0 "Make certs available for the client"
        fi

        rlRun "syncSet CERTS_READY"

        # rsyslog setup
        rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "cp ca.pem server-key.pem server-cert.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Copy certificates to /etc/rsyslogd.d"
#       old syntax config have no support, or no documented support for addition options like tls
        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
module(load="imrelp" ruleset="relp")
input(type="imrelp" port="6514"
tls="on"
tls.caCert="/etc/rsyslogd.d/ca.pem"
tls.myCert="/etc/rsyslogd.d/server-cert.pem"
tls.myPrivKey="/etc/rsyslogd.d/server-key.pem"
# see BZ#1430000, SHA1 works
#tls.authMode="fingerprint"
#tls.permittedpeer=["SHA1:$SHA1_CLIENT"] )
tls.authMode="name"
tls.permittedpeer=["$CLIENTS"] )
ruleset (name="relp") { action(type="omfile" file="/var/log/bz1174345-rsyslog.log") }
EOF

        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump &" 0 "Running wireshark"
        TSHARK_PID=$!
#        rlRun "tcpdump -A -i any 'host $CLIENTS and port 6514' > tcpdump.log &" 0 "Running tcpdump"
    rlPhaseEnd


    rlPhaseStartTest Server
        # server setup goes here
        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"

        rlRun "syncExp CLIENT_TEST_READY"
        rlRun "syncSet SERVER_TEST_READY"

        rlRun "syncExp CLIENT_TEST_DONE"

        sleep 10; ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
#        sleep 10; kill `pidof tcpdump`; sleep 3
        CLIENT_SHORT=`echo $CLIENTS | cut -d '.' -f 1`
        NUM=`grep "$CLIENT_SHORT" /var/log/bz1174345-rsyslog.log | grep --count 'bz1174345 rsyslog-gnutls test'`
        rlAssertEquals "Checking that 500 client message was delivered" $NUM 500
        rlRun "tshark -V -r wireshark.dump | grep 'bz1174345'" 1 "wireshark log should not contain unencrypted message"
        #rlRun "grep 'bz1174345 rsyslog-gnutls test' tcpdump.log" 1 "tcpdump.log should not contain unencrypted message"
	# just list initial TLS communication (for debuggin purposes)
	rlLogInfo "TLS version used (see wireshark_TLS.log for detailed log)"
	tshark -d 'tcp.port==6514,ssl' -O ssl -R 'frame.number<20' -r wireshark.dump > wireshark_TLS.log
	rlRun "egrep -o 'Version: TLS [0-9.]*' wireshark_TLS.log | sort -u"
	rlFileSubmit wireshark_TLS.log
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"
        rlRun "ps $rsyslogPID" 0 "Verify that rsyslog did not stop"
    rlPhaseEnd
}

Client() {
    rlPhaseStartSetup "Client setup"
        rlRun "syncExp CERTS_READY"

        if rlIsRHEL 5 6; then
            #netcat
            rlRun "nc -4 $SERVERS 50001 > certs.tar" 0 "Download client certificates"
        else
            #ncat
            rlRun "nc -4 --recv-only $SERVERS 50001 > certs.tar" 0 "Download client certificates"
        fi
        rlRun "tar -xf certs.tar" 0 "Extract certificates"

        rlRun "mkdir /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "mv *.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Move certificates to /etc/rsyslogd.d"
#       old syntax config have no support, or no documented support for addition options like tls
        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
EOF

        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
module(load="omrelp")
module(load="imtcp")
input(type="imtcp" port="6514")
action(type="omrelp"
        target="$SERVERS"
        port="6514"
        tls="on"
        tls.caCert="/etc/rsyslogd.d/ca.pem"
        tls.myCert="/etc/rsyslogd.d/client-cert.pem"
        tls.myPrivKey="/etc/rsyslogd.d/client-key.pem"
        tls.authmode="name"
        tls.permittedpeer=["$SERVERS"] )
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
    rlPhaseEnd

    rlPhaseStartTest Client
        # client action goes here
        rlRun "syncSet CLIENT_TEST_READY"
        rlRun "syncExp SERVER_TEST_READY"

        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"
        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlLog "sending 500 test messages to the logger"
        for I in `seq 500`; do
            logger "bz1174345 rsyslog-gnutls test $I"
        done
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"
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
        rlFileBackup /etc/rsyslog.conf
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
        rlFileSubmit /var/log/bz1174345-rsyslog.log
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlRun "rm -rf /etc/rsyslogd.d/ /var/log/bz1174345-rsyslog.log" 0 "Removing /etc/rsyslogd.d/"
        rlRun "rlFileRestore"
        rlRun "rsyslogServiceRestore"
        $ENTROPY && kill `pidof rngd`
    rlPhaseEnd

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
