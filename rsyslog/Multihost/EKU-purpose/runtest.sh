#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Multihost/EKU-purpose
#   Description: Test for extended key usage purpose
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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
rsyslogSyntax=new
rpm -q rsyslog5 && PACKAGE="rsyslog5"
rpm -q rsyslog7 && PACKAGE="rsyslog7"

# set client & server manually if debugging
#SERVERS="server.redhat.com"
#CLIENTS="client.redhat.com"

# server part of the test


function syncWaitForServer {

    let syncCOUNT++

    rlLog "$syncPREFIX: Synchronizing CLIENT with SERVER"
    syncIsServer && syncSet  "R_SYNC_$syncCOUNT"
    syncIsClient && syncExp "R_SYNC_$syncCOUNT"
    rlLog "$syncPREFIX: synchronized CLIENT to SERVER"

    return 0
}

function syncWaitForClient {

    let syncCOUNT++

    rlLog "$syncPREFIX: Synchronizing SERVER with CLIENT"
    syncIsClient && syncSet  "I_SYNC_$syncCOUNT"
    syncIsServer && syncExp "I_SYNC_$syncCOUNT"
    rlLog "$syncPREFIX: synchronized SERVER to CLIENT"

    return 0
}


checkMessage() {
  local msg="${1:-communication check}"
  local neg=$2
  rlRun "rsyslogResetLogFilePointer /var/log/messages"
  syncWaitForServer
  syncIsClient && {
    rlRun "logger -p local7.info '$msg'"
  }
  syncWaitForClient
  rlRun "sleep 3s"
  rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
  if syncIsClient; then
    rlAssertGrep "$msg" $rlRun_LOG
  else
    if [[ -z "$neg" ]]; then
      rlAssertGrep "$msg" $rlRun_LOG
    else
      rlAssertGrep "error" $rlRun_LOG -qi
      rlAssertNotGrep "$msg" $rlRun_LOG
    fi
  fi
  rm -f $rlRun_LOG
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckRequirements $(rlGetMakefileRequires | sed 's/\S*rng\S*//g')" || rlDie 'cannot continue'
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "rsyslogPrepareConf"
        rlRun "rsyslogServiceStop"
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        rlRun "rm -rf /etc/rsyslogd.d/" 0 "Removing /etc/rsyslogd.d/"
    rlPhaseEnd

    rlPhaseStartSetup 'setup certificates'
      syncIsServer && {
        # prepare entropy generator
        pidof rngd || {
          rngd -r /dev/urandom
          CleanupRegister "rlRun 'kill $(pidof rngd)'"
        }
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
        rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert-good.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate server cert"
        rlRun "sed -i -r 's/serial.*/serial = 003/;s/tls_www.*/tls_www_client/' server.tmpl"
        rlRun "certtool --generate-request --template server.tmpl --load-privkey server-key.pem --outfile server-request.pem" 0 "Generate server cert request"
        rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert-bad.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate server cert"
        rlRun "sed -i -r 's/serial.*/serial = 004/;s/tls_www.*/#tls_www_client/' server.tmpl"
        rlRun "certtool --generate-request --template server.tmpl --load-privkey server-key.pem --outfile server-request.pem" 0 "Generate server cert request"
        rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert-none.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate server cert"

        cat > client.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 005
expiration_days = 365
dns_name = "$CLIENTS"
ip_address = "$CLIENT_IP"
email = "root@$CLIENTS"
tls_www_client
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert-good.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"
        rlRun "sed -i -r 's/serial.*/serial = 006/;s/tls_www.*/tls_www_server/' client.tmpl"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert-bad.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"
        rlRun "sed -i -r 's/serial.*/serial = 007/;s/tls_www.*/#tls_www_server/' client.tmpl"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert-none.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"
        rm -f *-request.pem

        rlRun "tar -cf certs.tar *.pem" 0 "tar certs to archive"
        rlRun "syncSet CERTS_READY - < certs.tar"
      }

      syncIsClient && {
        rlRun "syncExp CERTS_READY > certs.tar"
        rlRun "tar -xf certs.tar" 0 "Extract certificates"
      }

      rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
      rlRun "cp *.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Copy certificates to /etc/rsyslogd.d"
    rlPhaseEnd

    rlPhaseStartSetup
      rsyslogConfigAppend "GLOBALS" < <(rsyslogConfigCreateSection keys)
      rsyslogConfigAppend "MODULES" < <(rsyslogConfigCreateSection tcp)
    rlPhaseEnd


    rlPhaseStartTest "basic communication check"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
        rsyslogConfigReplace tcp <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="anon"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
)

input(type="imtcp" Port="6514")
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
        rsyslogConfigReplace tcp <<EOF
local7.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$SERVERS")
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage
    rlPhaseEnd


    rlPhaseStartSetup "configure server cert check on"
      syncIsServer && {
        rsyslogConfigReplace tcp <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="anon"
    #PermittedPeer="$CLIENTS"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
    #streamdriver.CheckExtendedKeyPurpose="on"
)

input(type="imtcp" Port="6514")
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace tcp <<EOF
local7.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    streamdriver.CheckExtendedKeyPurpose="on"
    StreamDriverPermittedPeers="$SERVERS")
EOF
      }
    rlPhaseEnd


    rlPhaseStartTest "server cert check on, good purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check on, good purpose"
    rlPhaseEnd


    rlPhaseStartTest "server cert check on, bad purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-bad.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check on, bad purpose" 1
    rlPhaseEnd


    rlPhaseStartTest "server cert check on, no purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-none.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check on, no purpose"
    rlPhaseEnd


    rlPhaseStartSetup "configure server cert check off"
      syncIsServer && {
        rsyslogConfigReplace tcp <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="anon"
    #PermittedPeer="$CLIENTS"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
    #streamdriver.CheckExtendedKeyPurpose="on"
)

input(type="imtcp" Port="6514")
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace tcp <<EOF
local7.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    streamdriver.CheckExtendedKeyPurpose="off"
    StreamDriverPermittedPeers="$SERVERS")
EOF
      }
    rlPhaseEnd


    rlPhaseStartTest "server cert check off, good purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check off, good purpose"
    rlPhaseEnd


    rlPhaseStartTest "server cert check off, bad purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-bad.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check off, bad purpose"
    rlPhaseEnd


    rlPhaseStartTest "server cert check off, no purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-none.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "server cert check off, no purpose"
    rlPhaseEnd


    rlPhaseStartSetup "configure client cert check on"
      syncIsServer && {
        rsyslogConfigReplace tcp <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="x509/name"
    PermittedPeer="$CLIENTS"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
    streamdriver.CheckExtendedKeyPurpose="on"
)

input(type="imtcp" Port="6514")
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace tcp <<EOF
local7.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$SERVERS")
EOF
      }
    rlPhaseEnd


    rlPhaseStartTest "client cert check on, good purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check on, good purpose"
    rlPhaseEnd


    rlPhaseStartTest "client cert check on, bad purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-bad.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check on, bad purpose" 1
    rlPhaseEnd


    rlPhaseStartTest "client cert check on, no purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-none.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check on, no purpose"
    rlPhaseEnd


    rlPhaseStartSetup "configure client cert check off"
      syncIsServer && {
        rsyslogConfigReplace tcp <<EOF
module(
    load="imtcp"
    StreamDriver.AuthMode="x509/name"
    PermittedPeer="$CLIENTS"
    StreamDriver.Mode="1"
    StreamDriver.Name="gtls"
    streamdriver.CheckExtendedKeyPurpose="off"
)

input(type="imtcp" Port="6514")
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace tcp <<EOF
local7.* action(type="omfwd"
    Protocol="tcp"
    Target="$SERVERS"
    Port="6514"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$SERVERS")
EOF
      }
    rlPhaseEnd


    rlPhaseStartTest "client cert check off, good purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check off, good purpose"
    rlPhaseEnd


    rlPhaseStartTest "client cert check off, bad purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-bad.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check off, bad purpose"
    rlPhaseEnd


    rlPhaseStartTest "client cert check off, no purpose"
      syncIsServer && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert-good.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      }
      syncIsClient && {
        rsyslogConfigReplace keys <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert-none.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
EOF
      }
      rlRun "rsyslogPrintEffectiveConfig -n"
      rlRun "rsyslogServiceStart"
      rlRun "rsyslogServiceStatus"

      checkMessage "client cert check off, no purpose"
    rlPhaseEnd


    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
