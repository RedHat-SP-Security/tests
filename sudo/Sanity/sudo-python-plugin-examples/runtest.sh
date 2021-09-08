#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Sanity/sudo-python-plugin-examples
#   Description: Load the sudo python plugin examples provided in /usr/share/doc/sudo/examples
#   Author: Martin Zeleny <mzeleny@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="sudo"
PACKAGES="${PACKAGE} sudo-python-plugin expect"
examplesDir="/usr/share/doc/sudo/examples"
sudoConf="/etc/sudo.conf"
testFile="/bz1981278"

listOfExamples=( \
    example_approval_plugin.py \
    example_audit_plugin.py \
    example_conversation.py \
    example_io_plugin.py \
    example_policy_plugin.py \
)

configurePlugin()
{
    local example=$1
    local name=$2

    rlRun "echo Plugin ${name} python_plugin.so ModulePath=${examplesDir}/${example} >> ${sudoConf}"
}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlAssertRpm --all" || rlDie "Missing required packages"
        rlRun "rlImport --all" 0 "Import libraries" || rlDie "Missing requireed beakerlib libraries"
        rlRun "testUserSetup 3"

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd ${TmpDir}"
        rlRun "rlFileBackup ${sudoConf}"

    rlPhaseEnd


    rlPhaseStartTest "Checking presence of examples"
        countOfExamples=$(ls ${examplesDir}/example* | wc -l)
        rlLog "Found ${countOfExamples} examples in ${examplesDir}"
        rlLog "At least ${#listOfExamples[@]} examples are expected"
        rlAssertGreaterOrEqual "Expected count of examples found" "${countOfExamples}" "${#listOfExamples[@]}"

        for example in ${listOfExamples[@]}; do
            rlAssertExists "${examplesDir}/${example}"
        done
    rlPhaseEnd


    rlPhaseStartTest "Testing example_approval_plugin.py python plugin"
        configurePlugin "example_approval_plugin.py" "python_approval"
        rlRun -s "sudo true" 0,1
        exitCode=$?

        [ $exitCode == "0" ] && rlRun "[ ! -s $rlRun_LOG ]" 0 "Output is empty"
        [ $exitCode == "1" ] && rlAssertGrep "That is not allowed outside the business hours!" $rlRun_LOG

        rm $rlRun_LOG
        rlRun "rlFileRestore"
    rlPhaseEnd


    rlPhaseStartTest "Testing example_audit_plugin.py python plugin"
        configurePlugin "example_audit_plugin.py" "python_audit"
        rlRun -s "sudo true"
        rlAssertGrep '(AUDIT)' $rlRun_LOG

        rm $rlRun_LOG
        rlRun "rlFileRestore"
    rlPhaseEnd


    rlPhaseStartTest "Testing example_conversation.py python plugin"
        configurePlugin "example_conversation.py" "python_io"

        reasonsLog="/tmp/sudo_reasons.txt"
        rlRun "rlFileBackup --clean --missing-ok $reasonsLog"

        cat > conversation.exp << EOF
            set timeout 10
            spawn sh -c "sudo true"
            expect {
                "Reason:" {
                    send "test_string_1\r"
                    exp_continue
                }
                "Secret reason:" {
                    send "test_string_2\r"
                    puts "\nexpect: PASS"
                    sleep 1
                    exit 0
                }
                expect eof
                wait
            }
            exit 1
EOF
        rlRun "expect -f conversation.exp"

        rlAssertExists $reasonsLog
        rlAssertGrep 'Executed true' $reasonsLog
        rlAssertGrep 'Reason: test_string_1' $reasonsLog
        rlAssertGrep 'Hidden reason: test_string_2' $reasonsLog

        rlRun "rlFileRestore"
    rlPhaseEnd


    rlPhaseStartTest "Testing example_io_plugin.py python plugin"
        configurePlugin "example_io_plugin.py" "python_io"

        sudoLog="/tmp/sudo.log"
        rlRun "rlFileBackup --clean --missing-ok $sudoLog"

        rlRun -s "sudo true"
        rlAssertGrep 'Example sudo python plugin will log to /tmp/sudo.log' $rlRun_LOG
        rm $rlRun_LOG

        rlAssertExists $sudoLog
        rlAssertGrep 'EXEC true' $sudoLog
        rlRun "cat $sudoLog" 0 "Show sudo log"

        rlRun "rlFileRestore"
    rlPhaseEnd


    rlPhaseStartTest "Testing example_policy_plugin.py python plugin"
        rlRun "sed -i '/sudoers_policy/d' ${sudoConf}" 0 "Remove previous policy plugin - only a single policy plugin may be specified"
        configurePlugin "example_policy_plugin.py" "python_policy"

        rlRun -s "sudo true" 1
        rlAssertGrep 'You are not allowed to run this command!' $rlRun_LOG
        rm $rlRun_LOG

        for c in "id" "whoami"; do
            rlRun -s "sudo $c" 0 "Check working command"
            rlAssertGrep 'The command returned with exit_status 0' $rlRun_LOG
            rm $rlRun_LOG
        done

        rlRun "rlFileRestore"
        rlRun "sudo true" 0 "Restored working state"
    rlPhaseEnd


    rlPhaseStartTest "Testing example_group_plugin.py python plugin"
        rlAssertNotExists "${testFile}"
        rlRun -s "sudoRunAsUser ${testUser[0]} ${testUserPasswd[0]} 'sudo touch ${testFile}'" 1 "Expected failure before setup the plugin."
        rlAssertGrep "${testUser[0]} is not in the sudoers file." $rlRun_LOG
        rm $rlRun_LOG
        rlAssertNotExists "${testFile}"

        sudoersFile="/etc/sudoers"
        rlRun "rlFileBackup ${sudoersFile}"

        rlLog "Configation of group plugin in ${sudoersFile}"
        echo Defaults group_plugin=\"python_plugin.so ModulePath=${examplesDir}/example_group_plugin.py\" >> ${sudoersFile}
        rlRun "echo '%:testgroup ALL=(ALL) NOPASSWD: ALL' >> ${sudoersFile}" 0 "Non-unix group ':testgroup' must be configred with ':'"

        rlRun "tail -n 2 ${sudoersFile}" 0 "Show the ${sudoersFile} configuration change"

        rlRun -s "sudoRunAsUser ${testUser[0]} '' 'sudo touch ${testFile}'" 0 "Main test: must pass sudo without password"
        rlAssertNotGrep "${testUser[0]} is not in the sudoers file." $rlRun_LOG
        rm $rlRun_LOG
        rlAssertExists "${testFile}"
        rlRun "rm ${testFile}"

        rlRun "rlFileRestore"

        rlRun -s "sudoRunAsUser ${testUser[0]} ${testUserPasswd[0]} 'sudo touch ${testFile}'" 1 "Expected failure with restored configuration."
        rlAssertGrep "${testUser[0]} is not in the sudoers file." $rlRun_LOG
        rm $rlRun_LOG
        rlAssertNotExists "${testFile}"
    rlPhaseEnd


    rlPhaseStartTest "Testing relative path to sudo plugin python module"
        rlRun "modulePath=/usr/libexec/sudo/python/" 0 "Default to the sudo Python plugin directory"
        rlRun "rlFileBackup --clean --missing-ok ${modulePath}"
        rlRun "mkdir -p ${modulePath}" 0 "Ensure the path exists"

        example=example_io_plugin.py
        rlRun "cp ${examplesDir}/${example} ${modulePath}"
        rlRun "echo Plugin python_io python_plugin.so ModulePath=${example} >> ${sudoConf}" 0 "Confugire module with relative path"

        sudoLog="/tmp/sudo.log"
        rlRun "rlFileBackup --clean --missing-ok $sudoLog"

        rlRun -s "sudo true"
        rlAssertGrep 'Example sudo python plugin will log to /tmp/sudo.log' $rlRun_LOG
        rm $rlRun_LOG

        rlAssertExists $sudoLog
        rlAssertGrep 'EXEC true' $sudoLog
        rlRun "cat $sudoLog" 0 "Show sudo log"

        rlRun "rlFileRestore"
    rlPhaseEnd


    rlPhaseStartCleanup
        rlRun "rlFileRestore"
        rlRun "popd"
        rlRun "rm -r ${TmpDir}" 0 "Removing tmp directory"
        rlRun "testUserCleanup"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
