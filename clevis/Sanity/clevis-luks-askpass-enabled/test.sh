#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartTest "Check 'systemctl is-enabled clevis-luks-askpass.path' output"
        rlAssertEquals "'systemctl is-enabled clevis-luks-askpass.path' output has to be enabled" \
            "$(systemctl is-enabled clevis-luks-askpass.path)" "enabled"
    rlPhaseEnd
rlJournalEnd
