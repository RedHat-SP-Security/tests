#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/aide/Sanity/aide-rules-test
#   Description: Tests if aide properly handles default rules
#   Author: Karel Srot <ksrot@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || :
. /usr/lib/beakerlib/beakerlib.sh

# handle the global parameter
[ "${SYSLOG_FORMAT}" == 'true' ] || SYSLOG_FORMAT=false

PACKAGE="aide"

PATTERN_FILE=./patterns

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\`mktemp -d -p /var/tmp\`" 0 "Creating tmp directory"
	rlRun "./prepare_test.sh $TmpDir" 0 "Preparing files for the test"
	if rlIsRHEL 4; then  # remove selinux test on rhel4
            rlRun "sed -i '/selinux/d' $TmpDir/aide.conf" 0 "Disabling SELinux check in aide.conf"
            rlRun "sed -i '/selinux/d' $PATTERN_FILE" 0 "Disabling SELinux check in test config file"
	fi
	if rlIsRHEL 6; then  # remove e2fsattrs test
            rlRun "sed -i '/e2fsattrs/d' $TmpDir/aide.conf" 0 "Disabling e2fsattrs check in aide.conf"
            rlRun "sed -i '/e2fsattrs/d' $PATTERN_FILE" 0 "Disabling e2fsattrs check in test config file"
	    grep -q ';Permissions' $PATTERN_FILE || rlRun "sed -i 's/;Perm/;Permissions/' $PATTERN_FILE" 0 "Replacing Perm with Permissions in the test config file!"
        fi
	${SYSLOG_FORMAT} && rlRun "sed -i 's/#syslog_format=no/syslog_format=yes/' $TmpDir/aide.conf" 0 "Configuring syslog_format in aide.conf"
	# context changes to make it work on MLS policy
	chcon -t aide_db_t $TmpDir/db
	chcon -t etc_t $TmpDir/aide.conf
	chcon -t aide_log_t $TmpDir/log

	rlRun "aide -c $TmpDir/aide.conf -i" 0 "Initializing aide database"
	rlRun "cp $TmpDir/db/aide.db.new $TmpDir/db/aide.db" 0 "Save aide database"

	sleep 60  # some time delay because of timestamp related tests
	rlRun "./update_files.sh $TmpDir" 0 "Updating test files"
	export AIDE_LOG="$TmpDir/log/aide.log"
	rlRun "aide -u -c $TmpDir/aide.conf" 7 "Re-run aide test"

    rlPhaseEnd

# Test the default aide output format
if ! ${SYSLOG_FORMAT}; then

    rlPhaseStartTest "Verify the summary"
        if rlIsRHEL '<=6'; then  # ignoring RHEL-4 specifics
 	    rlAssertGrep "Total number of files:[[:space:]]+23\$" $AIDE_LOG -E
        elif rlIsRHEL 7; then
 	    rlAssertGrep "Total number of files:[[:space:]]+2[34]\$" $AIDE_LOG -E
	else
 	    rlAssertGrep "Total number of entries:[[:space:]]+17\$" $AIDE_LOG -E
        fi
        if rlIsRHEL '<=7'; then
	    rlAssertGrep "Added files:[[:space:]]+1\$" $AIDE_LOG -E
	    rlAssertGrep "Removed files:[[:space:]]+1\$" $AIDE_LOG -E
        else
	    rlAssertGrep "Added entries:[[:space:]]+1\$" $AIDE_LOG -E
	    rlAssertGrep "Removed entries:[[:space:]]+1\$" $AIDE_LOG -E
        fi
        if rlIsRHEL '<=6'; then
	    rlAssertGrep "Changed files:[[:space:]]+15\$" $AIDE_LOG -E
        elif rlIsRHEL 7; then
	    rlAssertGrep "Changed files:[[:space:]]+16\$" $AIDE_LOG -E
        else
	    rlAssertGrep "Changed entries:[[:space:]]+16\$" $AIDE_LOG -E
        fi
    rlPhaseEnd

    rlPhaseStartTest "Verify added and removed files"
        if rlIsRHEL '<=7'; then
	  rlAssertGrep "added: $TmpDir/data/subdir/newfile\$" $AIDE_LOG -E
	  rlAssertGrep "removed: $TmpDir/data/subdir/tobedeleted\$" $AIDE_LOG -E
	else
	  rlRun "grep -A 3 'Added entries:' $AIDE_LOG | grep '$TmpDir/data/subdir/newfile\$'"
	  rlRun "grep -A 3 'Removed entries:' $AIDE_LOG | grep '$TmpDir/data/subdir/tobedeleted\$'"
        fi
    rlPhaseEnd

    while read LINE; do
	# proceed with earch pattern from pattern file
	TEST_DESC=`echo $LINE | cut -d ';' -f 1`
	FILE=`echo $LINE | cut -d ';' -f 2`
	PATTERNS=`echo $LINE | cut -d ';' -f 3`

	[ -z "$PATTERNS" ] && break

	rlPhaseStartTest "$TEST_DESC"
	    rlRun "grep 'File: $TmpDir/$FILE' $AIDE_LOG" 0 "Searching for $TmpDir/$FILE changed files"
	    NUM_PATTERNS=`echo $PATTERNS | wc -w`
	    for PATTERN in $PATTERNS; do
	        rlRun "grep -A $NUM_PATTERNS '$TmpDir/$FILE' $AIDE_LOG | grep '$PATTERN'" 0 "Searching for '$PATTERN' in detailed info of $TmpDir/$FILE"
	    done
        rlPhaseEnd
    done < $PATTERN_FILE

else  # test the (compact) aide syslog_format output format
    rlPhaseStartTest "Verify added and removed files"
	rlAssertGrep "file=$TmpDir/data/subdir/newfile; added" $AIDE_LOG
	rlAssertGrep "file=$TmpDir/data/subdir/tobedeleted; removed" $AIDE_LOG
    rlPhaseEnd

    while read LINE; do
	# proceed with earch pattern from pattern file
	TEST_DESC=`echo $LINE | cut -d ';' -f 1`
	FILE=`echo $LINE | cut -d ';' -f 2`
	PATTERN=`echo $LINE | cut -d ';' -f 3 | cut -d ' ' -f 1`
	[ -z "$PATTERN" ] && break
	rlPhaseStartTest "$TEST_DESC"
	    rlRun "egrep 'file=$TmpDir/$FILE;${PATTERN}_old=.*${PATTERN}_new=' $AIDE_LOG" 0 "Searching for $TmpDir/$FILE changed with pattern $PATTERN"
        rlPhaseEnd
    done < $PATTERN_FILE

    rlPhaseStartTest "Verify that all file changes are listed on one line"
	rlRun "sed -n 1p $AIDE_LOG | egrep 'AIDE.*found differences between database and filesystem!!'" 0 "Checking 1st line format"
        if rlIsRHEL '<=6'; then
	  rlRun "sed -n 2p $AIDE_LOG | grep 'summary;total_number_of_files=23;added_files=1;removed_files=1;changed_files=15'" 0 "Checking 2nd output line format"
        elif rlIsRHEL 7; then
	  rlRun "sed -n 2p $AIDE_LOG | grep 'summary;total_number_of_files=24;added_files=1;removed_files=1;changed_files=16'" 0 "Checking 2nd output line format"
        else
	  rlRun "sed -n 2p $AIDE_LOG | grep 'summary;total_number_of_files=17;added_files=1;removed_files=1;changed_files=16'" 0 "Checking 2nd output line format"
	fi
	rlRun "sed -n '3,\$p' $AIDE_LOG | grep -v '^file='" 1 "All output lines starting the 3rd one should start with 'file='"
    rlPhaseEnd
fi

    rlPhaseStartCleanup
	rlBundleLogs $TmpDir/log/aide.log $TmpDir/db/aide.db.new $TmpDir/db/aide.db $TmpDir/aide.conf
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
