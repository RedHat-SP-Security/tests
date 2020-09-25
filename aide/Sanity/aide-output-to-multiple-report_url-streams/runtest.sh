#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-output-to-multiple-report_url-streams
#   Description: Checks that aide can output to multiple streams
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc.
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


# handle the global parameter
[ "${SYSLOG_FORMAT}" == 'true' ] || SYSLOG_FORMAT=false

PACKAGE="aide"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
	rlServiceStart rsyslog
	# prepare aide.conf
	rlRun "cp aide.conf $TmpDir"
	${SYSLOG_FORMAT} && rlRun "sed -i 's/#syslog_format=no/syslog_format=yes/' $TmpDir/aide.conf" 0 "C    onfiguring syslog_format in aide.conf"
	rlRun "sed -i -e 's:AIDE_DIR:$TmpDir:g' $TmpDir/aide.conf"
	rlRun "mkdir $TmpDir/db $TmpDir/log $TmpDir/data"
        # context changes to make it work on MLS policy
        chcon -t aide_db_t $TmpDir/db
        chcon -t etc_t $TmpDir/aide.conf
        chcon -t aide_log_t $TmpDir/log
	# prepare test data
	rlRun "echo hello > $TmpDir/data/to_be_modified"
	rlRun "touch $TmpDir/data/to_be_removed"
	# initialize aide
	rlRun "aide -c $TmpDir/aide.conf -i" 0 "Initializing aide database"
        rlRun "cp $TmpDir/db/aide.db.new $TmpDir/db/aide.db" 0 "Save aide database"
	# modify data
	rlRun "echo bye > $TmpDir/data/to_be_modified"
	rlRun "rm $TmpDir/data/to_be_removed"
	rlRun "touch $TmpDir/data/to_be_added"
	# rerun aide
	AIDE_LOG="$TmpDir/log/aide.log"
	SYSLOG_LENGTH=$( cat /var/log/messages | wc -l)
        [ $SYSLOG_LENGTH == 0 ] && SYSLOG_LENGTH=1 
	rlRun "exec 5>$TmpDir/fd5" 0 "Attach file descriptor 5 to $TmpDir/fd5"
	rlRun "rm -f $AIDE_LOG && aide -c $TmpDir/aide.conf > $TmpDir/stdout 2> $TmpDir/stderr" 7 "Run aide verification"
	sleep 2
	rlRun "sed -n '$SYSLOG_LENGTH,\$ p' /var/log/messages > $TmpDir/syslog" 0 "Extracting the new syslog content"
    rlPhaseEnd

# verify that all streams were used for the output
for F in $TmpDir/stdout $TmpDir/stderr $TmpDir/log/aide.log $TmpDir/syslog $TmpDir/fd5; do
    rlPhaseStartTest "Checking for the output in $F"
        cat $F
	if ! ${SYSLOG_FORMAT}; then
	    if rlIsRHEL '<=7'; then
	        rlAssertGrep "AIDE.*found differences between database and filesystem!!" $F -E
	        rlAssertGrep "added: $TmpDir/data/to_be_added" $F
	        rlAssertGrep "removed: $TmpDir/data/to_be_removed" $F
	        rlAssertGrep "changed: $TmpDir/data/to_be_modified" $F
	    else
	        rlAssertGrep "found differences between database and filesystem!!" $F -E
	        rlRun "grep -A 3 'Added entries:' $F | grep $TmpDir/data/to_be_added"
		rlRun "grep -A 3 'Removed entries:' $F | grep $TmpDir/data/to_be_removed" 
		rlRun "sed -n '/Changed entries/,\$ p' $F | grep $TmpDir/data/to_be_modified" 
	    fi
	else
	    rlAssertGrep "AIDE.*found differences between database and filesystem!!" $F -E
	    rlAssertGrep "file=$TmpDir/data/to_be_added; added" $F
	    rlAssertGrep "file=$TmpDir/data/to_be_removed; removed" $F
	    rlAssertGrep "file=$TmpDir/data/to_be_modified;Size_old=6;Size_new=4" $F
	fi
    rlPhaseEnd
done

    rlPhaseStartCleanup
	rlBundleLogs $TmpDir/log/aide.log $TmpDir/db/aide.db.new $TmpDir/db/aide.db $TmpDir/aide.conf
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlServiceRestore
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
