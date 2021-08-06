#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /rsyslog/Sanity/bz1932795-rebase-to-2102
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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

. /usr/share/beakerlib/beakerlib.sh || exit 1
PACKAGE="rsyslog"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        CleanupRegister 'rlRun "rsyslogCleanup"'
        rlRun "rsyslogSetup"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating TmpDir directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"

        rsyslogPrepareConf
        rsyslogConfigAddTo "GLOBALS"  < <(rsyslogConfigCreateSection 'CUSTOM')
        rsyslogServiceStart
    rlPhaseEnd

    # 'exists()' function on the Rainer script can be used to check if variable exists
    # e.g.: if exists($!somevar) then ...
    rlPhaseStartTest "Function 'exists(!path!var)' - variable exists" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
template(name="custom-template" type="string" string="%!result%\n")
if \$msg startswith "test message" then {
    set \$!path!var="yes";
    if exists(\$!path!var) then
        set \$!result = "Variable does exist";
    else
        set \$!result = "Variable does not exist";
    action(type="omfile" file="/var/log/messages" template="custom-template")
}
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        rsyslogServiceStatus
        rlRun "logger 'test message'"
        sleep 3
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep "Variable does exist" $rlRun_LOG
        rlAssertNotGrep "Variable does not exist" $rlRun_LOG
    rlPhaseEnd; }

    # 'exists()' function on the Rainer script can be used to check if variable exists
    # e.g.: if exists($!somevar) then ...
    rlPhaseStartTest "Function 'exists(!path!var)' - variable does not exist" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
template(name="custom-template" type="string" string="%!result%\n")
if \$msg startswith "test message" then {
    # set \$!path!var="yes"; do not set the variable
    if exists(\$!path!var) then
        set \$!result = "Variable does exist";
    else
        set \$!result = "Variable does not exist";
    action(type="omfile" file="/var/log/messages" template="custom-template")
}
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        rsyslogServiceStatus
        rlRun "logger 'test message'"
        sleep 3
        rlRun -s "rsyslogCatLogFileFromPointer /var/log/messages"
        rlAssertGrep "Variable does not exist" $rlRun_LOG
        rlAssertNotGrep "Variable does exist" $rlRun_LOG
    rlPhaseEnd; }

    # cat <filename> does not cause segfault if the filename does not exist
    rlPhaseStartTest "cat <filename> inside config file segfault when filename does not exist" && {
        rsyslogResetLogFilePointer /var/log/messages
        rsyslogConfigReplace "CUSTOM" <<EOF
include(text=\`cat /var/log/some-non-existing-dir\`)
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rsyslogServiceStart
        sleep 3
        rlRun -s "rsyslogServiceStatus" 0 "Rsyslog daemon should be running"
        rlAssertNotGrep "core=dumped" $rlRun_LOG
        rlAssertGrep "file could not be accessed for" $rlRun_LOG
    rlPhaseEnd; }

    rsyslogVersion '>=8.2102.0' && rsyslogVersion '<8.2102.0-5' && rlPhaseStartTest "Rsyslog WILL abort if security.abortOnIDResolutionFail=on(default) and user does not exist" && {
        rsyslogConfigReplace "CUSTOM" <<EOF
\$PrivDropToUser some-non-existing-username
global(security.abortOnIDResolutionFail="on")
EOF
        rlRun "rsyslogPrintEffectiveConfig -n"
        rlRun "rsyslogServiceStart" 0-255
        sleep 3
        rlRun -s "rsyslogServiceStatus" 3 "Rsyslog daemon should not be running"
        rlAssertGrep "code=exited" $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
