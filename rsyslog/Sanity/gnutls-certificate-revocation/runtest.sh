#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/gnutls-certificate-revocation
#   Description: Test for GnuTLS certificate revocation checking (stapled OCSP)
#   Author: Anderson Toshiyuki Sasaki <ansasaki@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
PACKAGES="rsyslog rsyslog-gnutls openssl policycoreutils-python-utils"

rlJournalStart
    rlPhaseStartSetup
        rlAsertRpms --all
        rlRun "rlImport openssl/certgen"

        rlServiceStop rsyslog.service

        # Prevent SELinux AVC
        rlRun "semanage port -a -t http_port_t -p tcp 8888"
        rlRun "semanage port -a -t http_port_t -p tcp 4433"

        # Backup configuration
        rlFileBackup "/etc/rsyslog.conf"
        rlFileBackup --clean "/etc/rsyslog.d"
        rlFileBackup --clean "/etc/systemd/system/"

        rlRun "TmpDir=\$(mktemp -d)" 0 "Create tmp directory"
        chmod a+rx $TmpDir
        rlRun "pushd $TmpDir"

        # Generate keys and certs
        rlRun "x509KeyGen ca"
        rlRun "x509KeyGen server"
        rlRun "x509KeyGen ocsp"
        rlRun "x509KeyGen client"

        rlRun "x509SelfSign ca"
        rlRun "x509CertSign --CA ca --ocspResponderURI http://localhost:8888 server"
        rlRun "x509CertSign --CA ca ocsp --basicKeyUsage critical,digitalSignature,nonRepudiation --extendedKeyUsage critical,ocspSigning --ocspNoCheck --DN CN=ocspserver"
        rlRun "x509CertSign --CA ca -t webclient client"

        rlRun "cp $(x509Cert ca) /etc/rsyslog.d/ca.pem"
        rlRun "cp $(x509Cert client) /etc/rsyslog.d/cert.pem"
        rlRun "cp $(x509Key client) /etc/rsyslog.d/key.pem"

        # Setup rsyslog configuration to connect to a local server using TLS.
        # An OpenSSL server configured to send stapled OCSP responses will serve
        # as the server - we are interested on the TLS handshake and certificate
        # revocation status verification via stapled OCSP.
cat >> /etc/rsyslog.conf << EOF

global(DefaultNetstreamDriver="gtls"
       DefaultNetstreamDriverCAFile="/etc/rsyslog.d/ca.pem"
       DefaultNetstreamDriverCertFile="/etc/rsyslog.d/cert.pem"
       DefaultNetstreamDriverKeyFile="/etc/rsyslog.d/key.pem")

# set up the action for all messages
action(type="omfwd" protocol="tcp" port="4433" Target="127.0.0.1"
       StreamDriver="gtls" StreamDriverMode="1"
       StreamDriverAuthMode="x509/name"
       StreamDriverPermittedPeers="localhost")

global(internalmsg.severity="debug"
       debug.gnutls="1"
       debug.logFile="/var/log/debug.log")
EOF

        # Setup GnuTLS debug log generation. Using an override file seems to be
        # a reliable way.
        rlRun "mkdir -p /etc/systemd/system/rsyslog.service.d"
cat >> /etc/systemd/system/rsyslog.service.d/override.conf << EOF
[Service]
Environment="RSYSLOG_DEBUG=Debug"
EOF

        rlRun "cat /etc/rsyslog.conf"
        rlRun "cat /etc/systemd/system/rsyslog.service.d/override.conf"

        # Reload daemons after changing configuration
        rlRun "systemctl daemon-reload"
    rlPhaseEnd

    rlPhaseStartTest "Sanity check: test OCSP responder"
        # Start OCSP responder
        rlRun "openssl ocsp -index ca/index.txt -port 8888 -rsigner $(x509Cert ocsp) -rkey $(x509Key ocsp) -CA $(x509Cert ca) >ocsp.log 2>ocsp.err &"
        ocsp_pid=$!
        rlRun "rlWaitForSocket 8888 -p $ocsp_pid"
        rlRun "cat ocsp.log"
        rlRun "cat ocsp.err"

        # Start OpenSSL server
        rlRun "openssl s_server -www -CAfile ca/cert.pem -status -status_url http://localhost:8888 -status_verbose -key server/key.pem -cert server/cert.pem > server.log 2> server.err &"
        server_pid=$!

        rlRun "rlWaitForSocket 4433 -p $server_pid"
        rlRun "cat server.log"
        rlRun "cat server.err"

        # Connect to the server and check OCSP status
        rlRun "openssl s_client -CAfile $(x509Cert ca) -verify_return_error -verify 2 -connect localhost:4433 -status < /dev/null > openssl.log"
        rlRun -s "cat openssl.log"

        rlAssertGrep "Verify return code: 0 " $rlRun_LOG
        rlAssertGrep "OCSP Response Status: successful" $rlRun_LOG
        rlAssertGrep "Cert Status: good" $rlRun_LOG

        rlRun "kill $ocsp_pid"
        rlRun "kill $server_pid"

        rlRun "rm -rf $rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartTest "Test rsyslog with good certificate"
        # Start OCSP responder
        rlRun "openssl ocsp -index ca/index.txt -port 8888 -rsigner $(x509Cert ocsp) -rkey $(x509Key ocsp) -CA $(x509Cert ca) >ocsp.log 2>ocsp.err &"
        ocsp_pid=$!
        rlRun "rlWaitForSocket 8888 -p $ocsp_pid"
        rlRun "cat ocsp.log"
        rlRun "cat ocsp.err"

        # Start OpenSSL server
        rlRun "openssl s_server -www -CAfile ca/cert.pem -status -status_url http://localhost:8888 -status_verbose -key server/key.pem -cert server/cert.pem > server.log 2> server.err &"
        server_pid=$!

        rlRun "rlWaitForSocket 4433 -p $server_pid"

        # Start the service and send a test message
        rlServiceStart rsyslog.service
        rlRun "logger test"
        sleep 3

        rlRun "cat server.log"
        rlRun "cat server.err"

        rlAssertExists "/var/log/debug.log"
        rlRun "cat /var/log/debug.log | grep GnuTLS > gnutls.debug.log"
        rlAssertExists "gnutls.debug.log"
        rlRun "cat gnutls.debug.log"

        # Check that the certificate was not revoked and the service started
        # normally
        rlAssertNotGrep "The certificate was revoked via OCSP" "gnutls.debug.log"
        rlRun -s "systemctl status -l rsyslog"
        rlAssertNotGrep "not permitted to talk to peer, certificate invalid: certificate revoked" $rlRun_LOG

        rlServiceStop rsyslog.service
        rlRun "kill $ocsp_pid"
        rlRun "kill $server_pid"

        rlRun "rm -f gnutls.debug.log"
        rlRun "rm -f /var/log/debug.log"
        rlRun "rm -rf $rlRun_LOG"

    rlPhaseEnd

    rlPhaseStartTest "Test server with revoked certificate"
        # Revoke the server certificate
        rlRun "openssl ca -config ca/ca.cnf -revoke server/cert.pem -keyfile ca/key.pem -cert ca/cert.pem &> revoke.log" 0 "Revoke server cert"
        rlRun "cat revoke.log"

        # Start OCSP responder
        rlRun "openssl ocsp -index ca/index.txt -port 8888 -rsigner $(x509Cert ocsp) -rkey $(x509Key ocsp) -CA $(x509Cert ca) >ocsp.log 2>ocsp.err &"
        ocsp_pid=$!
        rlRun "rlWaitForSocket 8888 -p $ocsp_pid"
        rlRun "cat ocsp.log"
        rlRun "cat ocsp.err"

        # Start http server
        rlRun "openssl s_server -www -CAfile ca/cert.pem -status -status_url http://localhost:8888 -status_verbose -key server/key.pem -cert server/cert.pem > server.log 2> server.err &"
        server_pid=$!

        rlRun "rlWaitForSocket 4433 -p $server_pid"

        # Check if OpenSSL detects the revoked certificate
        rlRun "openssl s_client -connect localhost:4433 -status < /dev/null &> openssl2.log" 0 "Connect and get status"
        rlRun "cat openssl2.log"
        rlAssertGrep "Cert Status: revoked" openssl2.log

        # Start the service and send a test message
        rlServiceStart rsyslog.service
        sleep 3
        rlRun "logger test"

        rlRun "cat server.log"
        rlRun "cat server.err"

        rlAssertExists "/var/log/debug.log"
        rlRun "cat /var/log/debug.log | grep GnuTLS > gnutls.debug.log"
        rlAssertExists "gnutls.debug.log"
        rlRun "cat gnutls.debug.log"

        # Check that the certificate was revoked and the service refused to
        # communicate
        rlAssertGrep "The certificate was revoked via OCSP" "gnutls.debug.log"
        rlRun -s "systemctl status -l rsyslog"
        rlAssertGrep "not permitted to talk to peer, certificate invalid: certificate revoked" $rlRun_LOG

        rlServiceStop rsyslog.service
        rlRun "kill $ocsp_pid"
        rlRun "kill $server_pid"

        rlRun "rm -f /var/log/debug.log"
        rlRun "rm -f gnutls.debug.log"
        rlRun "rm -rf $rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
        rlRun "semanage port -d -t http_port_t -p tcp 8888"
        rlRun "semanage port -d -t http_port_t -p tcp 4433"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Remove tmp directory"

        # Restore service
        rlRun "systemctl daemon-reload"
        rlServiceRestore rsyslog.service
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
