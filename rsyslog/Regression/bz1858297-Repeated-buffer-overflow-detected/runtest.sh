#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Regression/bz1858297-Repeated-buffer-overflow-detected
#   Description: Test for BZ#1858297 (Repeated "buffer overflow detected")
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    CleanupRegister 'rlRun "rsyslogCleanup"'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "systemctl daemon-reload"'
    CleanupRegister 'rlRun "rlFileRestore"'
    CleanupRegister 'rlRun "rm -rf /var/log/test*"'
    rlRun "rlFileBackup --clean /etc/systemd/system/rsyslog.service.d/"
    rlRun "mkdir -p /etc/systemd/system/rsyslog.service.d"
    rlRun "echo -e '[Service]\nLimitNOFILE=16384' > /etc/systemd/system/rsyslog.service.d/10-LimitNOFILE.conf"
    rlRun "ulimit -n 16384"
    rlRun "systemctl daemon-reload"
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
cn = "$(hostname)"
serial = 002
expiration_days = 365
dns_name = "$(hostname)"
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
cn = "$(hostname)"
serial = 002
expiration_days = 365
dns_name = "$(hostname)"
EOF
    cat client.tmpl
    rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
    rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
    rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"

    rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
    rlRun "cp *.pem /etc/rsyslogd.d/"
    rlRun "chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d"

      rsyslogConfigAddTo "GLOBALS" <<EOF
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
EOF
      rsyslogConfigAddTo "MODULES" <<EOF
module( load="imtcp"

        # Update if handling large numbers of clients
        MaxSessions = "8000"

        StreamDriver.Name = "gtls"
        StreamDriver.Mode = "1"

        StreamDriver.AuthMode = "x509/name"
        PermittedPeer = [ "$(hostname)" ]
)
input(type="imtcp" port="6514")
EOF
      rsyslogPrintEffectiveConfig -n
      rlRun "rsyslogServiceStart"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      rsyslogResetLogFilePointer /var/log/messages
      since=$(date +"%F %T")
      tcfChk "open connections" && {
        CleanupRegister 'rlRun "kill \$(pidof sleep)"'
        progressHeader 1024
        for (( i=30000; i<=31024; i++)); do
          (
            sleep 1200 \
             | nc --ssl --ssl-cert /etc/rsyslogd.d/client-cert.pem \
                  --ssl-key /etc/rsyslogd.d/client-key.pem \
                  127.0.0.1 6514 &>/dev/null &
          )
          progressDraw $((i-30000))
        done
        progressFooter
      tcfFin; }
      rlRun "echo 'muj test' | nc --ssl --ssl-cert /etc/rsyslogd.d/client-cert.pem --ssl-key /etc/rsyslogd.d/client-key.pem 127.0.0.1 6514"
      rlRun -s "journalctl -u rsyslog -l --since '$since' --no-pager"
      rlAssertNotGrep "code=dumped" $rlRun_LOG
      rlAssertNotGrep "code=killed" $rlRun_LOG
      rm -f $rlRun_LOG
      rlRun "rsyslogServiceStatus"
      sleepWithProgress 15
      rlRun "rsyslogCatLogFileFromPointer /var/log/messages | grep 'muj test'"
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
