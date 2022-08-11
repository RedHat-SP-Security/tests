#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm "clevis-systemd"
        rlIsRHEL && rlAssertRpm "redhat-release"
        rlIsFedora && rlAssertRpm "fedora-release-common"
    rlPhaseEnd

    rlPhaseStartTest "Check 'systemctl is-enabled clevis-luks-askpass.path' output"
        rlAssertEquals "'systemctl is-enabled clevis-luks-askpass.path' output has to be enabled" \
            "$(systemctl is-enabled clevis-luks-askpass.path)" "enabled"
    rlPhaseEnd
rlJournalEnd
