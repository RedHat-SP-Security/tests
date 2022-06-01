#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Multihost/relp
#   Description: Test for bz701782 (rsyslog TLS does not encrypt traffic on s390x and)
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
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
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="rsyslog"
rpm -q rsyslog5 && PACKAGE="rsyslog5"
rpm -q rsyslog7 && PACKAGE="rsyslog7"

# set client & server manually if debugging
#SERVERS="server.redhat.com"
#CLIENTS="client.redhat.com"

check_messages() {
  local res=0 dupl msgs missing duplicates
  msgs=( $(rsyslogCatLogFileFromPointer /var/log/messages | grep -oE "bz701782 rsyslog-gnutls test '[0-9]+'" | grep -oE '[0-9]+' | sort -n) )
  missing=()
  duplicates=()
  progressHeader 500 1
  j=0
  for ((i=1; i<=500; i++)); do
    progressDraw $i
    dupl=0
    while [[ "$i" == "${msgs[j]}" ]]; do
      let j++
      let dupl++
    done
    [[ $dupl -eq 0 ]] && missing+=("$i")
    [[ $dupl -gt 1 ]] && duplicates+=("$i")
    [[ $dupl -ne 1 ]] && res=1
  done
  progressFooter
  [[ ${#missing[@]} -gt 0 ]] && rlFail "missing messages: $(echo "${missing[*]}" | sed 's/ /, /g')"
  [[ ${#duplicates[@]} -gt 0 ]] && rlFail "duplicit messages: $(echo "${duplicates[*]}" | sed 's/ /, /g')"
  [[ $res -ne 0 ]] && rlRun "rsyslogCatLogFileFromPointer /var/log/messages"
  return $res
}

# server part of the test

Server() {
    rlPhaseStartSetup "keys setup"
        # prepare entropy generator
        pidof rngd || {
          CleanupRegister 'kill `pidof rngd`'
          rngd -r /dev/urandom
        }
        # prepare certificates

        cat > ca.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rsyslog+gnutls"
serial = 001
expiration_days = 365
dns_name = "$syncSERVER_HOSTNAME"
ip_address = "$syncSERVER_IP"
email = "root@$syncSERVER_HOSTNAME"
crl_dist_points = "http://$syncSERVER_HOSTNAME/getcrl/"
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
dns_name = "$syncSERVER_HOSTNAME"
ip_address = "$syncSERVER_IP"
email = "root@$syncSERVER_HOSTNAME"
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
dns_name = "$syncCLIENT_HOSTNAME"
ip_address = "$syncCLIENT_IP"
email = "root@$syncCLIENT_HOSTNAME"
tls_www_client
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem" 0 "Generate client cert"
    rlPhaseEnd
  if [[ -n "$ANSIBLE" ]]; then
    rlPhaseStartSetup "setup both sides using ansible" && {
      ls /root/.ssh/id*.pub >/dev/null 2>&1 || {
        rlRun "ssh-keygen -N '' <<<'
y'"
      }
      rlRun "cat /root/.ssh/id*.pub >> /root/.ssh/authorized_keys"
      rlRun "cat /root/.ssh/id*.pub | syncSet SSH_KEY -"
      rlRun "epel yum install ansible -y || epel yum install ansible-core -y"
      rlRun "rpm -q ansible || rpm -q ansible-core"
      rlRun "rpm -q rhel-system-roles"
      cat > inventory.ini <<EOF
[servers]
server ansible_host=$syncSERVER_HOSTNAME
[clients]
client ansible_host=$syncCLIENT_HOSTNAME
EOF
      cat > playbook.yaml <<EOF
- name: server relp
  hosts: servers
  roles:
    - linux-system-roles.logging
  vars:
    #logging_purge_confs: true
    #logging_pki_files:
    #  - ca_cert_src: $PWD/ca.pem
    #    cert_src: $PWD/server-cert.pem
    #    private_key_src: $PWD/server-key.pem
    logging_inputs:
      - name: system_input
        type: basics
      - name: remote_input
        type: relp
        port: 6514
        tls: true
        ca_cert_src: $PWD/ca.pem
        cert_src: $PWD/server-cert.pem
        private_key_src: $PWD/server-key.pem
        pki_authmode: name
        permitted_clients:
         - $syncCLIENT_HOSTNAME
    logging_outputs:
      - name: files_output
        type: files
    logging_flows:
      - name: flows
        inputs: [system_input, remote_input]
        outputs: [files_output]

- name: client relp
  hosts: clients
  roles:
    - linux-system-roles.logging
  vars:
    #logging_purge_confs: true
    #logging_pki_files:
    #  - ca_cert_src: $PWD/ca.pem
    #    cert_src: $PWD/client-cert.pem
    #    private_key_src: $PWD/client-key.pem
    logging_inputs:
      - name: system_input
        type: basics
    logging_outputs:
      - name: files_output
        type: files
      - name: forward_output
        type: relp
        target: $syncSERVER_IP
        port: 6514
        tls: true
        ca_cert_src: $PWD/ca.pem
        cert_src: $PWD/client-cert.pem
        private_key_src: $PWD/client-key.pem
        permitted_servers:
          - $syncSERVER_HOSTNAME
    logging_flows:
      - name: flows
        inputs: [system_input]
        outputs: [files_output, forward_output]
EOF
      rlRun "cat playbook.yaml"
      rlRun "syncExp CLIENT_SETUP_READY"
      rlRun "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yaml"
      rlRun "syncSet SETUP_DONE"
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
      #debugPrompt
    rlPhaseEnd; }
  else
    rlPhaseStartSetup "Server setup"
        # provide certs for the client
        rlRun "tar -cf certs.tar ca.pem client-key.pem client-cert.pem" 0 "tar certs to archive"
        rlRun "syncSet CERTS_READY - < certs.tar"

        # rsyslog setup
        rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "cp ca.pem server-key.pem server-cert.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Copy certificates to /etc/rsyslogd.d"
        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
EOF
        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
module(
    load="imrelp"
)

global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)

input(type="imrelp" port="6514"
    tls="on"
    tls.caCert="/etc/rsyslogd.d/ca.pem"
    tls.myCert="/etc/rsyslogd.d/server-cert.pem"
    tls.myPrivKey="/etc/rsyslogd.d/server-key.pem"
    tls.authMode="name"
    tls.permittedpeer=["$syncCLIENT_HOSTNAME"]
)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
#        rlRun "tcpdump -A -i any 'host $CLIENTS and port 6514' > tcpdump.log &" 0 "Running tcpdump"
    rlPhaseEnd
  fi


    rlPhaseStartTest Server
        # server setup goes here
        rlRun "rsyslogServiceStart"
        rlRun "tshark -i any -f 'tcp port 6514' -a 'filesize:100' -w wireshark.dump 2>tshark.stderr &" 0 "Running wireshark"
        TSHARK_PID=$!
        rlLogInfo 'Waiting for the capturing to actually start...'
        rlWaitForCmd "grep -q '^Capturing on' tshark.stderr"
        rlRun "cat tshark.stderr"
        rlLogInfo 'Capturing started, moving on'

        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"

        rlRun "syncSet SERVER_TEST_READY"

        rlRun "syncExp CLIENT_TEST_DONE"

        sleep 10; ps -p $TSHARK_PID &> /dev/null && kill $TSHARK_PID; sleep 3
#        sleep 10; kill `pidof tcpdump`; sleep 3
        rlRun "cat tshark.stderr"
        rlRun "rm -f tshark.stderr"
        CLIENT_SHORT=`echo $syncCLIENT_HOSTNAME | cut -d '.' -f 1`
        rlRun "check_messages"
        rlRun "tshark -V -r wireshark.dump | grep 'bz701782'" 1 "wireshark log should not contain unencrypted message"
        #rlRun "grep 'bz701782 rsyslog-gnutls test' tcpdump.log" 1 "tcpdump.log should not contain unencrypted message"
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
  if [[ -n "$ANSIBLE" ]]; then
    rlPhaseStartSetup "setup both sides using ansible" && {
      rlRun "syncExp SSH_KEY >> /root/.ssh/authorized_keys"
      rlRun "syncSet CLIENT_SETUP_READY"
      #debugPrompt
      rlRun "syncExp SETUP_DONE"
      rlRun "cat -n /etc/rsyslog.conf"
      rlRun "cat -n /etc/rsyslog.d/*"
    rlPhaseEnd; }
  else
    rlPhaseStartSetup "Client setup"
        rlRun "syncExp CERTS_READY > certs.tar"
        rlRun "tar -xf certs.tar" 0 "Extract certificates"

        rlRun "mkdir /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "mv *.pem /etc/rsyslogd.d/ && chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d" 0 "Move certificates to /etc/rsyslogd.d"
        rsyslogConfigIsNewSyntax || rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
EOF

        rsyslogConfigIsNewSyntax && rsyslogConfigAppend "MODULES" /etc/rsyslog.conf <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)

module(load="omrelp")
*.* action(type="omrelp"
    target="$syncSERVER_HOSTNAME"
    port="6514"
    tls="on"
    tls.caCert="/etc/rsyslogd.d/ca.pem"
    tls.myCert="/etc/rsyslogd.d/client-cert.pem"
    tls.myPrivKey="/etc/rsyslogd.d/client-key.pem"
    tls.authmode="name"
    tls.permittedpeer=["$syncSERVER_HOSTNAME"]
)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
    rlPhaseEnd
  fi

    rlPhaseStartTest Client
        # client action goes here
        rlRun "syncExp SERVER_TEST_READY"

        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"
        rlRun "rsyslogPID=$(pidof rsyslogd)"
        rlLog "sending 500 test messages to the logger"
        progressHeader 500 1
        for I in `seq 500`; do
            progressDraw $I
            logger "bz701782 rsyslog-gnutls test '$I'"
        done
        progressFooter
        rlRun "rsyslogServiceStatus" 0 "Verify that rsyslog is running"
        rlRun "ps $rsyslogPID" 0 "Verify that rsyslog did not stop"

        rlRun "sleep 15" 0 "Give client 15 seconds to finish log transfer"
        rlRun "syncSet CLIENT_TEST_DONE"
        rlRun "check_messages"
    rlPhaseEnd
}

rlJournalStart
    rlPhaseStartSetup
        rsyslogSyntax=new
        rlRun "rlImport --all" || rlDie "cannot continue"
        rlRun "rlCheckRequirements $(rlGetMakefileRequires | sed -r 's/ansible//;s/rhel-system-roles//')" || rlDie "cannot continue"
        CleanupRegister 'rlRun "RpmSnapshotRevert"; rlRun "RpmSnapshotDiscard"'
        rlRun "RpmSnapshotCreate"
        CleanupRegister 'rlRun "rlFileRestore"'
        rlRun "rlFileBackup --clean /root/.ssh/"
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "rsyslogServiceStop"
        rlRun "rpm -qa nss\* nspr\* |sort"
        rlRun "rsyslogServiceStop"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        rsyslogResetLogFilePointer /var/log/messages
    rlPhaseEnd

    syncIsServer && Server
    syncIsClient && Client

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd

  rlPhaseStartTest "the other side result"
    rlRun "syncSet SYNC_RESULT $(rlGetTestState; echo $?)"
    rlAssert0 'check ther the other site finished successfuly' $(syncExp SYNC_RESULT)
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
