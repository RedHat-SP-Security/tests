#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/pin-sss
#   Description: tests the sss pin functionality of clevis
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

# TODO: rewrite this test to use non-tang pins, possibly
#       a local-key-file pin or something
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
        for i in {8020..8999}; do
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
            rlRun "mkdir -p tangd/db{1,2,3} tangd/cache{1,2,3}"
            gen_tang_keys "tangd/db1"
            gen_tang_cache "tangd/db1" "tangd/cache1"
            gen_tang_keys "tangd/db2"
            gen_tang_cache "tangd/db2" "tangd/cache2"
            gen_tang_keys "tangd/db3"
            gen_tang_cache "tangd/db3" "tangd/cache3"
            port1=$(start_tang "tangd/cache1")
            port2=$(start_tang "tangd/cache2")
            port3=$(start_tang "tangd/cache3")
        else
            rlRun "mkdir -p tangd/cache{1,2,3}"
            gen_tang_keys "tangd/cache1"
            gen_tang_keys "tangd/cache2"
            gen_tang_keys "tangd/cache3"
            port1=$(start_tang "tangd/cache1")
            port2=$(start_tang "tangd/cache2")
            port3=$(start_tang "tangd/cache3")
        fi
    rlPhaseEnd

    if [ $(rpm -q --queryformat '%{VERSION}' clevis) -ge 15 ]; then
        # Tests feature added in clevis-15.1 for RHEL-8.4
        rlPhaseStart FAIL "Valid sss config with wrong tang config"
            rlRun "wget -nv -O adv1.json \"http://localhost:$port1/adv\""
            rlRun "wget -nv -O adv2.json \"http://localhost:$port2/adv\""
            echo -n "testing data string" > plain
            rlRun "clevis encrypt sss '{
                    \"t\": 2,
                    \"pins\": {
                        \"tang\": [
                            { \"url\": \"http://wronghost\", \"adv\": \"adv1.json\" },
                            { \"url\": \"http://localhost:9999\", \"adv\": \"adv2.json\" },
                            { \"url\": \"http://localhost:$port1\", \"adv\": \"nonexisting_file\" }
                        ]
                    }
                }' < plain > enc" 1 "Valid sss config with wrong tang config"
        rlPhaseEnd
    fi

    rlPhaseStart FAIL "clevis setup, encrypt using t=2 and 3 servers"
        rlRun "wget -nv -O adv1.json \"http://localhost:$port1/adv\""
        rlRun "wget -nv -O adv2.json \"http://localhost:$port2/adv\""
        rlRun "wget -nv -O adv3.json \"http://localhost:$port3/adv\""
        echo -n "testing data string" > plain
        rlRun "clevis encrypt sss '{
                \"t\": 2,
                \"pins\": {
                    \"tang\": [
                        { \"url\": \"http://localhost:$port1\", \"adv\": \"adv1.json\" },
                        { \"url\": \"http://localhost:$port2\", \"adv\": \"adv2.json\" },
                        { \"url\": \"http://localhost:$port3\", \"adv\": \"adv3.json\" }
                    ]
                }
            }' < plain > enc" 0 "clevis setup, encrypt using t=2 and 3 servers"
    rlPhaseEnd

    rlPhaseStart FAIL "clevis decrypt, all tang servers available"
        rlRun "clevis decrypt < enc > plain2"
        rlAssertNotDiffer plain plain2
    rlPhaseEnd

    rlPhaseStart FAIL "clevis decrypt, no servers available"
        stop_tang "$port1"
        stop_tang "$port2"
        stop_tang "$port3"
        rlRun "clevis decrypt < enc > plain2" 1
        rlAssertDiffer plain plain2
    rlPhaseEnd

    rlPhaseStart FAIL "clevis decrypt, one server available"
        start_tang "tangd/cache1" "$port1"
        rlRun "clevis decrypt < enc > plain2" 1
        rlAssertDiffer plain plain2
    rlPhaseEnd

    rlPhaseStart FAIL "clevis decrypt, two servers available"
        start_tang "tangd/cache3" "$port3"
        rlRun "clevis decrypt < enc > plain2"
        rlAssertNotDiffer plain plain2
    rlPhaseEnd

    rlPhaseStartCleanup
        stop_tang "$port1"
        #stop_tang "$port2"  # already down
        stop_tang "$port3"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
