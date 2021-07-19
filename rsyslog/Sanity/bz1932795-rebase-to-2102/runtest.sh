#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Sanity/bz1932795-rebase-to-2102
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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

. /usr/share/beakerlib/beakerlib.sh || exit 1
PACKAGE="rsyslog"

rlJournalStart

    client_config() {
        local driver=$1
        local depth=$2
        rsyslogConfigReplace "CUSTOM" <<EOF
global(
    DefaultNetstreamDriver="$driver"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-root-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/client-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/client-key.pem"
)
local6.info action(type="omfwd"
    Protocol="tcp"
    Target="127.0.0.1"
    Port="6514"
    StreamDriver="$driver"
    StreamDriverMode="1"
    RebindInterval="50"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="$(hostname)"
    StreamDriver.TlsVerifyDepth="$depth"
)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
    }

    server_config() {
        local driver=$1
        local depth=$2
        rsyslogServerConfigReplace "CUSTOM" <<EOF
global(
    DefaultNetstreamDriver="$driver"
    DefaultNetstreamDriverCAFile="/etc/rsyslogd.d/ca-cert.pem"
    DefaultNetstreamDriverCertFile="/etc/rsyslogd.d/server-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/rsyslogd.d/server-key.pem"
)
module(
    load="imtcp"
    StreamDriver.AuthMode="x509/name"
    PermittedPeer="$(hostname)"
    StreamDriver.Mode="1"
    StreamDriver.Name="$driver"
    StreamDriver.TlsVerifyDepth="$depth"
)
ruleset(name="rs") { action(type="omfile" File="/var/log/rsyslog-stats.log")}
input(type="imtcp" Port="6514" ruleset="rs")
EOF
        rlRun "rsyslogServerPrintEffectiveConfig -n"
    }

    generate_certificate_chain() {
        cat > ca-root.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "rootca"
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
        rlRun "certtool --generate-privkey --outfile ca-root-key.pem" 0 "Generate key for root CA"
        rlRun "certtool --generate-self-signed --load-privkey ca-root-key.pem --template ca-root.tmpl --outfile ca-root-cert.pem" 0 "Generate self-signed root CA cert"

        cat > ca.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "ca"
serial = 002
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
        rlRun "certtool --generate-request --template ca.tmpl --load-privkey ca-key.pem --outfile ca-request.pem" 0 "Generate CA cert request"
        rlRun "certtool --generate-certificate --template ca.tmpl --load-request ca-request.pem  --outfile ca-cert.pem --load-ca-certificate ca-root-cert.pem --load-ca-privkey ca-root-key.pem" 0 "Generate CA cert"

##
cat > ca2.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "ca2"
serial = 003
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)"
crl_dist_points = "http://127.0.0.1/getcrl/"
ca
cert_signing_key
crl_signing_key
EOF
rlRun "certtool --generate-privkey --outfile ca2-key.pem" 0 "Generate key for CA2"
rlRun "certtool --generate-request --template ca2.tmpl --load-privkey ca2-key.pem --outfile ca2-request.pem" 0 "Generate CA2 cert request"
rlRun "certtool --generate-certificate --template ca2.tmpl --load-request ca2-request.pem  --outfile ca2-cert.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem" 0 "Generate CA2 cert"
##

        cat > server.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "server"
serial = 004
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)
tls_www_server
EOF
        cat server.tmpl
        rlRun "certtool --generate-privkey --outfile server-key.pem --bits 2048" 0 "Generate key for server"
        rlRun "certtool --generate-request --template server.tmpl --load-privkey server-key.pem --outfile server-request.pem" 0 "Generate server cert request"
        rlRun "certtool --generate-certificate --template server.tmpl --load-request server-request.pem  --outfile server-cert.pem --load-ca-certificate ca2-cert.pem --load-ca-privkey ca2-key.pem" 0 "Generate server cert"

        cat > client.tmpl <<EOF
organization = "Red Hat"
unit = "GSS"
locality = "Brno"
state = "Moravia"
country = CZ
cn = "client"
serial = 004
expiration_days = 365
dns_name = "$(hostname)"
ip_address = "127.0.0.1"
email = "root@$(hostname)"
tls_www_client
EOF
        cat client.tmpl
        rlRun "certtool --generate-privkey --outfile client-key.pem --bits 2048" 0 "Generate key for client"
        rlRun "certtool --generate-request --template client.tmpl --load-privkey client-key.pem --outfile client-request.pem" 0 "Generate client cert request"
        rlRun "certtool --generate-certificate --template client.tmpl --load-request client-request.pem  --outfile client-cert.pem --load-ca-certificate ca2-cert.pem --load-ca-privkey ca2-key.pem" 0 "Generate client cert"

        rlRun "mkdir -p /etc/rsyslogd.d && chmod 700 /etc/rsyslogd.d" 0 "Create /etc/rsyslogd.d"
        rlRun "cp *.pem /etc/rsyslogd.d/"
        rlRun "chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d"
        rlRun "cat server-cert.pem ca2-cert.pem ca-cert.pem > /etc/rsyslogd.d/server-cert.pem"
        rlRun "cat client-cert.pem ca2-cert.pem > /etc/rsyslogd.d/client-cert.pem"
        rlRun "chmod 400 /etc/rsyslogd.d/* && restorecon -R /etc/rsyslogd.d"
    }


    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        CleanupRegister 'rlRun "rsyslogServerCleanup"'
        rlRun "rsyslogServerSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating TmpDir directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister "rlRun 'rm -f /var/log/rsyslog-stats.log /var/log/rsyslog-imfile.log'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        generate_certificate_chain

        rsyslogPrepareConf
        rsyslogConfigAddTo "GLOBALS"  < <(rsyslogConfigCreateSection 'CUSTOM')
        rsyslogServiceStart

        rsyslogServerConfigAddTo "GLOBALS"  < <(rsyslogConfigCreateSection 'CUSTOM')
    rlPhaseEnd

    # 'exists()' function on the Rainer script can be used to check if variable exists
    # e.g.: if exists($!somevar) then ...
    rlPhaseStartTest "Function 'exists(!path!var)' - variable exists" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
template(name="custom-template" type="string" string="%!result%\n")
if \$msg startswith "test message" then {
    set \$!path!var="yes";
    if exists(\$!path!var) then
        set \$!result = "Variable does exist";
    else
        set \$!result = "Variable does not exist";
    action(type="omfile" file="/var/log/messages" template="custom-template")
}
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        rsyslogServiceStatus
        rlRun "logger 'test message'"
        sleep 5
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep "Variable does exist" $rlRun_LOG
        rlAssertNotGrep "Variable does not exist" $rlRun_LOG
    rlPhaseEnd; }

    # 'exists()' function on the Rainer script can be used to check if variable exists
    # e.g.: if exists($!somevar) then ...
    rlPhaseStartTest "Function 'exists(!path!var)' - variable does not exist" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
template(name="custom-template" type="string" string="%!result%\n")
if \$msg startswith "test message" then {
    # set \$!path!var="yes"; do not set the variable
    if exists(\$!path!var) then
        set \$!result = "Variable does exist";
    else
        set \$!result = "Variable does not exist";
    action(type="omfile" file="/var/log/messages" template="custom-template")
}
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        rsyslogServiceStatus
        rlRun "logger 'test message'"
        sleep 5
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep "Variable does not exist" $rlRun_LOG
        rlAssertNotGrep "Variable does exist" $rlRun_LOG
    rlPhaseEnd; }

    # cat <filename> does not cause segfault if the filename does not exist
    rlPhaseStartTest "cat <filename> inside config file segfault when filename does not exist" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
include(text=\`cat /var/log/some-non-existing-dir\`)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        sleep 5
        rlRun -s "rsyslogServiceStatus" 0 "Rsyslog daemon should be running"
        rlAssertNotGrep "core=dumped" $rlRun_LOG
        rlAssertGrep "file could not be accessed for" $rlRun_LOG
    rlPhaseEnd; }

    rsyslogVersion '>=8.2102.0' && rsyslogVersion '<8.2102.0-5' && rlPhaseStartTest "Rsyslog WILL abort if security.abortOnIDResolutionFail=on(default) and user does not exist" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
\$PrivDropToUser some-non-existing-username
global(security.abortOnIDResolutionFail="on")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart" 0-255
        sleep 3
        rlRun -s "rsyslogServiceStatus" 3 "Rsyslog daemon should not be running"
        rlAssertGrep "code=exited" $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartTest "omfwd stats counter" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="impstats" log.file="/var/log/rsyslog-stats.log" interval="1")
template(name="outfmt" type="string" string="TEST\n") # 5 bytes
module(load="builtin:omfwd" template="outfmt")
local6.info action(type="omfwd" target="127.0.0.1" port="6514" protocol="udp")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        sleep 3
        rlRun "rsyslogServiceStatus"
        for i in {1..20}; do
            rlRun "logger -p local6.info 'test message'"
        done
        sleep 3
        grep "bytes.sent" /var/log/rsyslog-stats.log
        rlAssertGrep "origin=omfwd bytes.sent=100" /var/log/rsyslog-stats.log # 20 * 5 bytes = 100 bytes
        rlRun "rsyslogServiceStop"
        rlRun "rm -f /var/log/rsyslog-stats.log"
    rlPhaseEnd; }

    rlPhaseStartTest "omfwd segfault if port not given" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="builtin:omfwd")
local6.info action(type="omfwd" target="127.0.0.1" protocol="tcp")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        sleep 3
        rlRun -s "rsyslogServiceStatus"
        rlAssertNotGrep "code=exited" $rlRun_LOG
    rlPhaseEnd; }

    # Send 20 messages in an instant with turned on ratelimiting 1 message / 5 seconds
    # Only the first one should be sent
    rlPhaseStartTest "omfwd rate limit option" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="impstats" log.file="/var/log/rsyslog-stats.log" interval="1")
template(name="outfmt" type="string" string="TEST\n") # 5 bytes
module(load="builtin:omfwd" template="outfmt")
local6.info action(type="omfwd" target="127.0.0.1" port="514" protocol="udp" ratelimit.interval="5" ratelimit.burst="1")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        sleep 3
        rlRun "rsyslogServiceStatus"
        for i in {1..20}; do
            rlRun "logger -p local6.info 'test message'"
        done
        sleep 3
        grep "bytes.sent" /var/log/rsyslog-stats.log
        rlAssertGrep "origin=omfwd bytes.sent=5" /var/log/rsyslog-stats.log
        rlAssertNotGrep "origin=omfwd bytes.sent=100" /var/log/rsyslog-stats.log
        rm -f /var/log/rsyslog-stats.log
    rlPhaseEnd; }

    rlPhaseStartTest "imptcp - max sessions config parameter" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="imptcp" maxsessions="1")
input(type="imptcp" port="514")
input(type="imptcp" port="6514")

local6.info action(type="omfwd" Protocol="tcp" Target="127.0.0.1" Port="514")
local6.info action(type="omfwd" Protocol="tcp" Target="127.0.0.1" Port="6514")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        since=$(date +"%F %T")
        sleep 1
        for i in {1..10}; do rlRun "logger -p local6.info 'Test message for imtcp max sessions'"; done
        sleep 2
        rlRun -s "journalctl -u rsyslog -l --since '$since' --no-pager"
        rlAssertGrep "too many tcp sessions - dropping incoming request" $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartTest "imfile: per minute rate limiting(MaxLinesPerMinute)" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
ruleset(name="myruleset") {
    action(type="omfile" file="/var/log/rsyslog-stats.log")
}
module(load="imfile" PollingInterval="1")
input(type="imfile"
        File="/var/log/rsyslog-imfile.log"
        Tag="tag2"
        ruleset="myruleset"
        MaxLinesPerMinute="10"
)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        for i in {1..20}; do echo "Test $i" >> /var/log/rsyslog-imfile.log; done
        cat /var/log/rsyslog-imfile.log
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        sleep 3
        for i in {1..10}; do rlAssertGrep "Test $i" /var/log/rsyslog-stats.log; done # First 10 messages delivered
        for i in {11..20}; do rlAssertNotGrep "Test $i" /var/log/rsyslog-stats.log; done # Other messages are being dropped
        rm -f /var/log/rsyslog-stats.log /var/log/rsyslog-imfile.log
    rlPhaseEnd; }

    rlPhaseStartTest "imfile: per minute rate limiting(MaxBytesPerMinute)" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
ruleset(name="myruleset") {
    action(type="omfile" file="/var/log/rsyslog-stats.log")
}
module(load="imfile" PollingInterval="1")
input(type="imfile"
    File="/var/log/rsyslog-imfile.log"
    Tag="tag2"
    ruleset="myruleset"
    MaxBytesPerMinute="61"
)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        for i in {1..20}; do echo "Test $i" >> /var/log/rsyslog-imfile.log; done
        rlRun "cat /var/log/rsyslog-imfile.log"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        sleep 3
        for i in {1..10}; do rlAssertGrep "Test $i" /var/log/rsyslog-stats.log; done # First 10 messages delivered
        for i in {11..20}; do rlAssertNotGrep "Test $i" /var/log/rsyslog-stats.log; done # Other messages are being dropped
        rm -f /var/log/rsyslog-stats.log /var/log/rsyslog-imfile.log
    rlPhaseEnd; }

    rlPhaseStartTest "immark: ruleset, mark message content, interval" && {
        # Check default mark message
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="immark" interval="1" use.syslogcall="off")
if \$inputname == "immark" then
    action(type="omfile" file="/var/log/rsyslog-stats.log")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun -s "rsyslogServiceStatus"
        sleep 3
        rlAssertNotGrep "rsyslogd: -- MARK --" $rlRun_LOG
        rlAssertGrep "rsyslogd: -- MARK --" /var/log/rsyslog-stats.log
        rm -f /var/log/rsyslog-stats.log

        # Check custom mark message
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="immark" interval="1" use.syslogcall="off" markmessagetext="-- Custom Mark Message --")
if \$inputname == "immark" then
    action(type="omfile" file="/var/log/rsyslog-stats.log")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun "rsyslogServiceStatus"
        sleep 3
        rlAssertNotGrep "rsyslogd: -- Custom Mark Message --" $rlRun_LOG
        rlAssertGrep "rsyslogd: -- Custom Mark Message --" /var/log/rsyslog-stats.log
        rm -f /var/log/rsyslog-stats.log

        # Check use.syslogcall="on"
        rsyslogConfigReplace "CUSTOM" <<EOF
module(load="immark" interval="1" use.syslogcall="on" markmessagetext="-- Custom Mark Message --")
if \$inputname == "immark" then
    action(type="omfile" file="/var/log/rsyslog-stats.log")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun -s "rsyslogServiceStatus"
        sleep 3
        rlRun "test ! -f /var/log/rsyslog-stats.log" 0 "File should not exist due to use.syslogcall=on"
        rlAssertGrep "-- Custom Mark Message --" $rlRun_LOG
        rm -f /var/log/rsyslog-stats.log

        # Check ruleset
        rsyslogConfigReplace "CUSTOM" <<EOF
ruleset(name="rs") {
    action(type="omfile" file="/var/log/rsyslog-stats.log")
}
module(load="immark" interval="1" use.syslogcall="off" markmessagetext="-- Custom Mark Message --" ruleset="rs")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart"
        rlRun -s "rsyslogServiceStatus"
        sleep 3
        rlAssertNotGrep "rsyslogd: -- Custom Mark Message --" $rlRun_LOG
        rlAssertGrep "rsyslogd: -- Custom Mark Message --" /var/log/rsyslog-stats.log
        rm -f /var/log/rsyslog-stats.log
    rlPhaseEnd; }

    rlPhaseStartTest "tls driver: certificate verify depth(max depth:2, actual depth:3)" && {
        client_config gtls 2
        server_config gtls 2

        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "logger -p local6.info 'TLS driver: certificate chain depth'"
        rlRun "sleep 3"
        rlRun "rsyslogServerStatus"
        rlRun -s "rsyslogServiceStatus"
        rlAssertGrep 'Some constraint limits were reached.' $rlRun_LOG
        test ! -f /var/log/rsyslog-stats.log || rlAssertNotGrep 'TLS driver: certificate chain depth' /var/log/rsyslog-stats.log
    rlPhaseEnd; }

    rlPhaseStartTest "tls driver: certificate verify depth(max depth:3, actual depth:3)" && {
        client_config gtls 3
        server_config gtls 3

        rlRun "rsyslogServerStart"
        rlRun "rsyslogServiceStart"
        rlRun "logger -p local6.info 'TLS driver: certificate chain depth'"
        rlRun "sleep 3"
        rlRun "rsyslogServerStatus"
        rlRun -s "rsyslogServiceStatus"
        rlAssertNotGrep 'Some constraint limits were reached.' $rlRun_LOG
        rlAssertGrep 'TLS driver: certificate chain depth' /var/log/rsyslog-stats.log

        rlRun "rsyslogServiceStop"
        rlRun "rsyslogServerStop"
    rlPhaseEnd; }

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
