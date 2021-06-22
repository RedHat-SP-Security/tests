#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1627799-RFE-Support-Intermediate-Certificate-Chains-in
#   Description: Test for BZ#1627799 ([RFE] Support Intermediate Certificate Chains in)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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


    cat > ca.tmpl <<EOF
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
    rlRun "certtool --generate-privkey --outfile ca-key.pem" 0 "Generate key for CA"
    rlRun "certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem" 0 "Generate self-signed CA cert"

    cat > server.tmpl <<EOF
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
email = "root@$(hostname)"
tls_www_server
EOF
    cat server.tmpl
    rlRun "certtool --generate-privkey --outfile server-key.pem --bits 2048" 0 "Generate key for server"
    rlRun "certtool --generate-request --template server.tmpl --load-privkey server-key.pem --outfile server-request.pem" 0 "Generate server cert request"
    rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem" 0 "Generate server cert"

    cat > client.tmpl <<EOF
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
    rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
    rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
    rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"

    rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
    rlRun "cp *.pem /etc/rsyslogd.d/"
    rlRun "chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d"

    client_config() {
      local driver="$1"
      rsyslogConfigReplace "SSL" <<EOF
*.* action(type="omfwd"
    Protocol="tcp"
    Target="127.0.0.1"
    Port="6514"
    StreamDriver="$driver"
    StreamDriverMode="1"
    RebindInterval="50"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$(hostname)")
EOF
      rlRun "rsyslogPrintEffectiveConfig -n"
    }

    tcfChk "config client" && {
      rlRun "rsyslogPrepareConf"
      rsyslogConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      rsyslogConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'SSL')
    tcfFin; }

    server_config() {
      local driver="$1"
      rsyslogServerConfigReplace "SSL" <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="x509/name"
    PermittedPeer="$(hostname)"
    StreamDriver.Mode="1"
    StreamDriver.Name="$driver"
)
input(type="imtcp" Port="6514")
EOF
      rlRun "rsyslogServerPrintEffectiveConfig -n"
    }

    tcfChk "config server" && {
      rsyslogServerConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      rsyslogServerConfigAddTo "MODULES" < <(rsyslogConfigCreateSection 'SSL')
    tcfFin; }

    rlRun "> $rsyslogServerLogDir/messages"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "gtls" && tcfChk && {
      tcfChk "setup gtls" && {
        client_config gtls
        server_config gtls
        > $rsyslogServerLogDir/messages
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
      tcfFin; }
      tcfTry "test gtls" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "ossl" && tcfChk && {
      tcfChk "setup ossl" && {
        client_config ossl
        server_config ossl
        > $rsyslogServerLogDir/messages
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
      tcfFin; }
      tcfTry "setup ossl" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "gtls->ossl" && tcfChk && {
      tcfChk "setup gtls->ossl" && {
        client_config gtls
        server_config ossl
        > $rsyslogServerLogDir/messages
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
      tcfFin; }
      tcfTry "setup gtls->ossl" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "ossl->gtls" && tcfChk && {
      tcfChk "setup ossl->gtls" && {
        client_config ossl
        server_config gtls
        > $rsyslogServerLogDir/messages
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
      tcfFin; }
      tcfTry "test ossl->gtls" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }; :
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
