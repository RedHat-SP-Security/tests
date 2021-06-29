#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Test for BZ#1932783 (Rebase librelp to latest upstream version)
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

rlJournalStart && {
    rlPhaseStartSetup && {
        rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
        rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        CleanupRegister 'rlRun "rsyslogServerCleanup"'
        rlRun "rsyslogServerSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"

        # GnuTLS certificates
        cat > gnutls-ca.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 001
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)"
crl_dist_points = "http://127.0.0.1/getcrl/"
ca
cert_signing_key
crl_signing_key
EOF
        rlRun "certtool --generate-privkey --outfile gnutls-ca-key.pem" 0 "Generate key for CA"
        rlRun "certtool --generate-self-signed --load-privkey gnutls-ca-key.pem --template gnutls-ca.tmpl --outfile gnutls-ca-cert.pem" 0 "Generate self-signed CA cert"

        cat > gnutls-server.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 002
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)
tls_www_server
EOF
        cat gnutls-server.tmpl
        rlRun "certtool --generate-privkey --outfile gnutls-server-key.pem --bits 2048" 0 "Generate key for server"
        rlRun "certtool --generate-request --template gnutls-server.tmpl --load-privkey gnutls-server-key.pem --outfile gnutls-server-request.pem" 0 "Generate server cert request"
        rlRun "certtool --generate-certificate --template gnutls-server.tmpl --load-request gnutls-server-request.pem  --outfile gnutls-server-cert.pem --load-ca-certificate gnutls-ca-cert.pem --load-ca-privkey gnutls-ca-key.pem" 0 "Generate server cert"

        cat > gnutls-client.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 003
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)"
tls_www_client
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile gnutls-client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template gnutls-client.tmpl --load-privkey gnutls-client-key.pem --outfile gnutls-client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template gnutls-client.tmpl --load-request gnutls-client-request.pem  --outfile gnutls-client-cert.pem --load-ca-certificate gnutls-ca-cert.pem --load-ca-privkey gnutls-ca-key.pem" 0 "Generate client cert"

        # OpenSSL certificates
        # rlRun "openssl genrsa 2048 > openssl-ca-key.pem" 0 "Generate a private key for the CA"
        # rlRun 'openssl req -new -x509 -nodes -days 365000 -key openssl-ca-key.pem -out openssl-ca-cert.pem -subj "/C=CZ/ST=Moravia/L=Brno/O=Red Hat/OU=org/CN=www.redhat.com"' 0 "Generate the X509 certificate for the CA"
        #
        # rlRun 'openssl req -newkey rsa:2048 -nodes -days 365000 -keyout openssl-server-key.pem -out openssl-server-req.pem --subj "/C=CZ/ST=Moravia/L=Brno/O=Red Hat/OU=org/CN=server"' 0 "Generate the private key and certificate request for server"
        # rlRun 'openssl x509 -req -days 365000 -set_serial 01 -in openssl-server-req.pem -out openssl-server-cert.pem -CA openssl-ca-cert.pem -CAkey openssl-ca-key.pem' 0 "Generate the X509 certificate for the server"
        #
        # rlRun 'openssl req -newkey rsa:2048 -nodes -days 365000 -keyout openssl-client-key.pem -out openssl-client-req.pem --subj "/C=CZ/ST=Moravia/L=Brno/O=Red Hat/OU=org/CN=client"' 0 "Generate the private key and certificate request for client"
        # rlRun 'openssl x509 -req -days 365000 -set_serial 01 -in openssl-client-req.pem -out openssl-client-cert.pem -CA openssl-ca-cert.pem -CAkey openssl-ca-key.pem' 0 "Generate the X509 certificate for the client"
        #
        # rlRun 'openssl verify -CAfile openssl-ca-cert.pem openssl-ca-cert.pem openssl-server-cert.pem' 0 "Verify the server certificate"
        # rlRun 'openssl verify -CAfile openssl-ca-cert.pem openssl-ca-cert.pem openssl-client-cert.pem' 0 "Verify the client certificate"

        # Store certificates
        rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "cp *.pem /etc/rsyslogd.d/"
        rlRun "chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d"

        client_config() {
            local driver="$1"
            rsyslogConfigReplace "SSL" <<EOF
module(load="omrelp" tls.tlslib="$driver")
local6.* action(type="omrelp"
    target="127.0.0.1"
    port="6514"
    tls="on"
    tls.cacert="/etc/rsyslogd.d/gnutls-ca-cert.pem"
    tls.mycert="/etc/rsyslogd.d/gnutls-client-cert.pem"
    tls.myprivkey="/etc/rsyslogd.d/gnutls-client-key.pem"
    tls.authmode="certvalid"
    tls.permittedpeer="$(hostname)")
EOF
            rlRun "rsyslogPrintEffectiveConfig -n"
        }

        tcfChk "config client" && {
            rlRun "rsyslogPrepareConf"
            rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'SSL')
        tcfFin; }

        server_config() {
            local driver="$1"
            rsyslogServerConfigReplace "SSL" <<EOF
module(
    load="imrelp"
    tls.tlslib="$driver"
)
input(type="imrelp" port="6514" maxDataSize="10k"
    tls="on"
    tls.cacert="/etc/rsyslogd.d/gnutls-ca-cert.pem"
    tls.mycert="/etc/rsyslogd.d/gnutls-server-cert.pem"
    tls.myprivkey="/etc/rsyslogd.d/gnutls-server-key.pem"
    tls.authmode="certvalid"
    tls.permittedpeer="$(hostname)")
EOF
            rlRun "rsyslogServerPrintEffectiveConfig -n"
        }

        tcfChk "config server" && {
            rsyslogServerConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'SSL')
        tcfFin; }

        rlRun "> $rsyslogServerLogDir/messages"
    rlPhaseEnd; }

    tcfTry "Tests" --no-assert && {

        for client_driver in "gnutls" "openssl"; do
            for server_driver in "gnutls" "openssl"; do
                rlPhaseStartTest "$client_driver -> $server_driver" && tcfChk && {
                    tcfChk "setup" && {
                        client_config $client_driver
                        server_config $server_driver
                        > $rsyslogServerLogDir/messages
                        rlRun "rsyslogServerStart"
                        rlRun "rsyslogServiceStart"
                        rlRun "rsyslogServiceStatus"
                    tcfFin; }
                    tcfTry "Send messages" && {
                        rlAssertNotGrep 'test message' $rsyslogServerLogDir/messages
                        rlRun "logger -p local6.info 'test message'"
                        rlRun "sleep 3s"
                        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
                        echo "" > $rsyslogServerLogDir/messages
                    tcfFin; }
                rlPhaseEnd; tcfFin; }
            done
        done

    tcfFin; }

    rlPhaseStartCleanup && {
        CleanupDo
        tcfCheckFinal
        rlPhaseEnd; }
    rlJournalPrintText
rlJournalEnd; }
