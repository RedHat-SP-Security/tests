#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

[ -z "${IMA_APPRAISE}" ] && IMA_APPRAISE="fix"
[ -z "${IMA_POLICY}" ] && IMA_POLICY="tcb"
[ -z "${IMA_HASH}" ] && IMA_HASH="sha256"
[ -z "${IMA_AUDIT}" ] && IMA_AUDIT="1"

COOKIE=/var/tmp/configure-kernel-ima-module-rebooted
TESTFILE=/var/tmp/configure-kernel-ima-module-test$$

rlJournalStart

  if [ ! -e $COOKIE ]; then
    rlPhaseStartSetup "pre-reboot phase"
        rlRun "grubby --info ALL"
        rlRun "grubby --default-index"
        rlRun "grubby --update-kernel DEFAULT --args 'ima_appraise=${IMA_APPRAISE} ima_appraise_tcb ima_policy=${IMA_POLICY} ima_hash=${IMA_HASH} ima_audit=${IMA_AUDIT}'" 
        rlRun -s "grubby --info DEFAULT | grep '^args'"
        rlAssertGrep "ima_appraise=${IMA_APPRAISE}" $rlRun_LOG
        rlAssertGrep "ima_policy=${IMA_POLICY}" $rlRun_LOG
	rlAssertGrep "ima_audit=${IMA_AUDIT}" $rlRun_LOG
	rlAssertGrep "ima_hash=${IMA_HASH}" $rlRun_LOG
    	rlRun "touch $COOKIE"
    rlPhaseEnd

    rhts-reboot

  else
    rlPhaseStartTest "post-reboot IMA test"
        rlRun -s "cat /proc/cmdline"
        rlAssertGrep "ima_appraise=${IMA_APPRAISE}" $rlRun_LOG
        rlAssertGrep "ima_policy=${IMA_POLICY}" $rlRun_LOG
        rlAssertGrep "ima_audit=${IMA_AUDIT}" $rlRun_LOG
        rlAssertGrep "ima_hash=${IMA_HASH}" $rlRun_LOG
	rlRun "grubby --info ALL"
        rlRun "grubby --default-index"
        rlRun "rm $COOKIE" 
        if [ "${IMA_STATE}" == "on" -o "${IMA_STATE}" == "1" ]; then
            rlRun "touch ${TESTFILE} && cat ${TESTFILE} && rm ${TESTFILE}"
            rlRun "grep ${TESTFILE} /sys/kernel/security/ima/ascii_runtime_measurements"
        fi
    rlPhaseEnd
  fi

rlJournalEnd
