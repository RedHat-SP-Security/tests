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
      if rsyslogConfigIsNewSyntax; then
        if [[ -n "$SERVER_NO_CERT" ]]; then
          rsyslogConfigReplace "SSL" <<EOF
*.* action(type="omfwd"
    Protocol="tcp"
    Target="127.0.0.1"
    Port="6514"
    StreamDriver="$driver"
    StreamDriverMode="1"
    RebindInterval="50"
    StreamDriverAuthMode="anon")
EOF
        else
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
        fi
      else
        if [[ -n "$SERVER_NO_CERT" ]]; then
          rsyslogConfigReplace "SSL" <<EOF
\$DefaultNetstreamDriver $driver
\$ActionSendStreamDriverAuthMode anon
\$ActionSendStreamDriverMode 1
*.* @@127.0.0.1:6514
EOF
        else
          rsyslogConfigReplace "SSL" <<EOF
\$DefaultNetstreamDriver $driver
\$ActionSendStreamDriverAuthMode x509/name
\$ActionSendStreamDriverPermittedPeer $(hostname)
\$ActionSendStreamDriverMode 1
*.* @@127.0.0.1:6514
EOF
        fi
      fi
      rlRun "rsyslogPrintEffectiveConfig -n"
    }

    tcfChk "config client" && {
      rlRun "rsyslogPrepareConf"
      if rsyslogConfigIsNewSyntax; then
        if [[ -n "$CLIENT_NO_CERT" ]]; then
          rsyslogConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
)
EOF
        else
          rsyslogConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
        fi
      else
        if [[ -n "$CLIENT_NO_CERT" ]]; then
          rsyslogConfigAppend "GLOBALS" <<EOF
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca-cert.pem
EOF
        else
          rsyslogConfigAppend "GLOBALS" <<EOF
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca-cert.pem
\$DefaultNetstreamDriverCertFile /etc/rsyslogd.d/client-cert.pem
\$DefaultNetstreamDriverKeyFile /etc/rsyslogd.d/client-key.pem
EOF
        fi
      fi
      rsyslogConfigAddTo --begin "RULES" < <(rsyslogConfigCreateSection 'SSL')
    tcfFin; }

    server_config() {
      local driver="$1"
      if rsyslogConfigIsNewSyntax; then
        if [[ -n "$CLIENT_NO_CERT" ]]; then
          rsyslogServerConfigReplace "SSL" <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="anon"
    StreamDriver.Mode="1"
    StreamDriver.Name="$driver"
)
input(type="imtcp" Port="6514")
EOF
        else
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
        fi
      else
        if [[ -n "$CLIENT_NO_CERT" ]]; then
          rsyslogServerConfigReplace "SSL" <<EOF
\$ModLoad imtcp

\$DefaultNetstreamDriver $driver
\$InputTCPServerStreamDriverMode 1
\$InputTCPServerStreamDriverAuthMode anon
\$InputTCPServerRun 6514
EOF
        else
          rsyslogServerConfigReplace "SSL" <<EOF
\$ModLoad imtcp

\$DefaultNetstreamDriver $driver
\$InputTCPServerStreamDriverMode 1
\$InputTCPServerStreamDriverAuthMode x509/name
\$InputTCPServerStreamDriverPermittedPeer $(hostname)
\$InputTCPServerRun 6514
EOF
        fi
      fi
      rlRun "rsyslogServerPrintEffectiveConfig -n"
    }

    tcfChk "config server" && {
      if rsyslogConfigIsNewSyntax; then
        if [[ -n "$SERVER_NO_CERT" ]]; then
          rsyslogServerConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
)
EOF
        else
          rsyslogServerConfigAppend "GLOBALS" <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
        fi
      else
        if [[ -n "$SERVER_NO_CERT" ]]; then
          rsyslogServerConfigAppend "GLOBALS" <<EOF
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca-cert.pem
EOF
        else
          rsyslogServerConfigAppend "GLOBALS" <<EOF
\$DefaultNetstreamDriverCAFile /etc/rsyslogd.d/ca-cert.pem
\$DefaultNetstreamDriverCertFile /etc/rsyslogd.d/server-cert.pem
\$DefaultNetstreamDriverKeyFile /etc/rsyslogd.d/server-key.pem
EOF
        fi
      fi
      rsyslogServerConfigAddTo --begin "RULES" < <(rsyslogConfigCreateSection 'SSL')
    tcfFin; }

    rlRun "> $rsyslogServerLogDir/messages"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "gtls" && tcfChk && {
      tcfChk "setup gtls" && {
        > $rsyslogServerLogDir/messages
        server_config gtls
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServerStatus"
        client_config gtls
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        rsyslogResetLogFilePointer /var/log/messages
      tcfFin; }
      tcfTry "test gtls" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlRun "cat $rsyslogServerLogDir/messages"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep 'test message' $rlRun_LOG
        rlRun "rsyslogServerStatus"
        rlRun "rsyslogServiceStatus"
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "ossl" && tcfChk && {
      tcfChk "setup ossl" && {
        > $rsyslogServerLogDir/messages
        server_config ossl
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServerStatus"
        client_config ossl
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        rsyslogResetLogFilePointer /var/log/messages
      tcfFin; }
      tcfTry "test ossl" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlRun "cat $rsyslogServerLogDir/messages"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep 'test message' $rlRun_LOG
        rlRun "rsyslogServerStatus"
        rlRun "rsyslogServiceStatus"
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "gtls->ossl" && tcfChk && {
      tcfChk "setup gtls->ossl" && {
        > $rsyslogServerLogDir/messages
        server_config ossl
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServerStatus"
        client_config gtls
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        rsyslogResetLogFilePointer /var/log/messages
      tcfFin; }
      tcfTry "test gtls->ossl" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlRun "cat $rsyslogServerLogDir/messages"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep 'test message' $rlRun_LOG
        rlRun "rsyslogServerStatus"
        rlRun "rsyslogServiceStatus"
        ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        rlRun "tshark -V -r wireshark.dump | grep 'test message'" 1 "wireshark log should not contain unencrypted message"; :
      tcfFin; }
    rlPhaseEnd; tcfFin; }


    rlPhaseStartTest "ossl->gtls" && tcfChk && {
      tcfChk "setup ossl->gtls" && {
        > $rsyslogServerLogDir/messages
        server_config gtls
        rlRun "rsyslogServerStart"
        rlRun "rsyslogServerStatus"
        client_config ossl
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        rsyslogResetLogFilePointer /var/log/messages
      tcfFin; }
      tcfTry "test ossl->gtls" && {
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        sleep 1
        rlRun "logger 'test message'"
        rlRun "sleep 3s"
        rlRun "cat $rsyslogServerLogDir/messages"
        rlAssertGrep 'test message' $rsyslogServerLogDir/messages
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep 'test message' $rlRun_LOG
        rlRun "rsyslogServerStatus"
        rlRun "rsyslogServiceStatus"
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
