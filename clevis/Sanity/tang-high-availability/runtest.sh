#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/tang-high-availability
#   Description: verifies sharing keys between tang servers
#   Author: Jiri Jaburek <jjaburek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

legacy_tang() {
    test -x /usr/libexec/tangd-update
}
gen_tang_keys() {
    rlRun "/usr/libexec/tangd-keygen \"$1\""
}
gen_tang_cache() {
    rlRun "/usr/libexec/tangd-update \"$1\" \"$2\""
}
grep_b64() {
    rlRun "jose b64 dec -i \"$2\" -O - | grep -q \"$1\"" 0 \
        "File '$2' should contain '$1' when b64-decrypted" || \
            jose b64 dec -i "$2" -O -
}
start_tang() {
    local i= cache="$1" port="$2"
    if [ -z "$port" ]; then
        for i in {8000..8999}; do
            if ! fuser -s -n tcp "$i"; then
                port="$i"
                break
            fi
        done
    fi
    if [ -z "$port" ] || fuser -s -n tcp "$port"; then
        rlLogFatal "no free port found for tangd: $port" 1>&2
        return 1
    fi
    nohup socat "tcp-listen:$port,fork" exec:"/usr/libexec/tangd $cache" >/dev/null &
    local pid=$!
    rlWaitForSocket "$port" -p "$pid"
    rlLogInfo "started tangd $cache as pid $pid on port $port" 1>&2
    [ ! -t 1 ] && echo "$port"
    return 0
}
stop_tang() {
    rlRun "fuser -s -k \"$1/tcp\""
}


PACKAGE="clevis"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStart FAIL "tangd setup"
        if legacy_tang; then
            rlRun "mkdir -p tangd/db tangd/cache tangd/cache2"
            gen_tang_keys "tangd/db"
            gen_tang_cache "tangd/db" "tangd/cache"
            gen_tang_cache "tangd/db" "tangd/cache2"
            port=$(start_tang "tangd/cache")
        else
            rlRun "mkdir -p tangd/cache tangd/cache2"
            gen_tang_keys "tangd/cache"
            rlRun "cp -a tangd/cache/* tangd/cache2"
            port=$(start_tang "tangd/cache")
        fi
    rlPhaseEnd

    rlPhaseStart FAIL "clevis encrypt using first server, decrypt using second"
        rlRun "wget -nv -O adv.json \"http://localhost:$port/adv\""
        echo -n "testing data string" > plain
        rlRun "clevis encrypt tang '{ \"url\": \"http://localhost:$port\", \"adv\": \"adv.json\" }' < plain > enc"
        grep_b64 "http:" enc
        stop_tang $port
        start_tang "tangd/cache2" $port  # same port
        rlRun "clevis decrypt < enc > plain2"
        rlAssertNotDiffer plain plain2
        rm -f adv plain enc plain2
    rlPhaseEnd

    rlPhaseStartCleanup
        stop_tang $port
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
