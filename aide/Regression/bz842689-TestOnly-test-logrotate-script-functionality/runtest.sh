#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Regression/bz842689-TestOnly-test-logrotate-script-functionality
#   Description: Test for BZ#842689 ([TestOnly] test logrotate script functionality)
#   Author: Michal Trunecka <mtruneck@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc. All rights reserved.
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

PACKAGE="aide"
AIDE_CONFIG="/etc/aide.conf"
AIDE_LOG="/var/log/aide/aide.log"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlFileBackup $AIDE_CONFIG
        rlFileBackup --clean /var/lib/aide
        rlFileBackup --clean /var/log/aide  # backup current logs
        rlRun "echo > $AIDE_LOG" 0 "Clear $AIDE_LOG to ease the testing"
        rlRun "rm -f ${AIDE_LOG}*"  # remove rotated logs

        # Init the aide db twice with different config files
        # (will cause   aide --check   to log differences to log file)
        rlRun "cp aide_first.conf $AIDE_CONFIG"
        rlRun "aide --init"
        rlAssertExists "/var/lib/aide/aide.db.new.gz"
        rlRun "mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz"
        rlRun "cp aide_second.conf $AIDE_CONFIG"
        rlRun "aide --init"
    rlPhaseEnd

    rlPhaseStartTest
        # Generate some logs and check them
        rlRun "aide --check" 0-255
        rlRun "sleep 2"
        rlRun "cat $AIDE_LOG | grep 'Old db contains a \(file\|entry\) that shouldn.t be there'"

        #The test cannot be executed too closely to the end of a minute, otherwise
        #+cron manage to rotate the aide logs twice and the test will fail
        #+so let's try to plan the execution (cron start at the start of minute)
        while [[ `date +%S |sed 's/^0//'` -gt 50 ]] || [[ `date +%S |sed 's/^0//'` -lt 40 ]] ; do
            sleep 1
        done
        date

        # update anacron with test script to initiate logrotate
        rlRun "cat > /etc/cron.d/0aide-test <<EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root
HOME=/
*/1 * * * * root logrotate -f /etc/logrotate.d/aide
EOF"
        rlRun "rlServiceStart crond"
        rlRun "sleep 60"
        # Verify that cron has executed the logrotate job
	if rlIsRHEL '<=7'; then
        	rlAssertGrep "logrotate -f /etc/logrotate.d/aide" /var/log/cron
	else
        	rlRun -s "journalctl -u crond.service --since '-60s'"
        	rlAssertGrep 'logrotate -f /etc/logrotate.d/aide' $rlRun_LOG
        	rm -f $rlRun_LOG
	fi
        tail -50 /var/log/cron

        # Generate some logs and check them again
        rlRun "aide --check" 0-255
        rlRun "sleep 2"
        rlRun -s "cat $AIDE_LOG"
         # check that new message has been logged
        rlAssertGrep 'Old db contains a \(file\|entry\) that shouldn.t be there' $rlRun_LOG -qi
        rm -f $rlRun_LOG
        # check that old message is in the rotated log
        rlRun -s "cat ${AIDE_LOG}.1 "
        rlAssertGrep 'Old db contains a \(file\|entry\) that shouldn.t be there' $rlRun_LOG -qi
        rm -f $rlRun_LOG

        rlRun "matchpathcon -V $AIDE_LOG" 0 "Verify that $AIDE_LOG has correct SELinux context"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore
        rlRun "rm -rf /etc/cron.d/0aide-test"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
