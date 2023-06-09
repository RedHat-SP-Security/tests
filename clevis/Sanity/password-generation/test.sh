#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PWQ_CONF="/etc/security/pwquality.conf"

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun "pushd $tmp"
        rlRun "set -o pipefail"

        rlRun "dd if=/dev/zero of=loopfile bs=100M count=1"
        rlRun "lodev=\$(losetup -f --show loopfile)" 0 "Create device from file"
        rlRun "echo -n redhat123 | cryptsetup luksFormat --batch-mode --key-file - ${lodev}"

        rlRun "rlServiceStart tangd.socket"

        rlFileBackup "${PWQ_CONF}"
        rlRun "echo 'maxclassrepeat = 4' > ${PWQ_CONF}"
    rlPhaseEnd

    rlPhaseStartTest
        counter=1
        while [ $counter -ne 7 ]; do
            echo "===  binding:$counter ==="
            echo -n "redhat123" | clevis luks bind -k - -d ${lodev}  -y tang '{"url":"localhost"}'
            echo "=== /binding:$counter ==="
            ((counter++))
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
        rlFileRestore
    rlPhaseEnd
rlJournalEnd
