#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGES="clevis clevis-luks tang jose luksmeta cryptsetup"
PWQ_CONF="/etc/security/pwquality.conf"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
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


    slot_count=6
    rlPhaseStartTest "${slot_count} attempts for clevis luks bind"
        for i in $(seq 1 $slot_count); do
            rlRun "echo -n redhat123 | clevis luks bind -f -k - -d ${lodev} -y tang '{\"url\": \"localhost\"}'" \
                0 "Clevis binding attempt ${i}/${slot_count}" || break
        done
    rlPhaseEnd


    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "find /dev/mapper -name 'luks*' -exec cryptsetup close {} +"
        rlRun "losetup -d ${lodev}"
        rlRun "popd"
        rlRun "rm -r $tmp" 0 "Remove tmp directory"
        rlFileRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
