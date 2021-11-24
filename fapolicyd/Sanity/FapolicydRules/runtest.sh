#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/FapolicydRules
#   Description: The evaluator will configure fapolicyd to allow execution of executable based on path, hash and directory. The evaluator will then attempt to execute executables. The evaluator will ensure that the executables that are allowed to run has been executed and the executables that are not allowed to run will be denied.
#   Author: Zoltan Fridrich <zfridric@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
        rlRun "pushd $TmpDir"
        rlRun "fapSetup"
        echo 'int main(void) { return 0; }' > main.c
        exe1="exe1"
        exe2="exe2"
        exe3="test/exe3"
        exe4="test/exe4"
        rlRun "gcc main.c -o $exe1" 0 "Creating binary $exe1"
        rlRun "gcc main.c -g -o $exe2" 0 "Creating binary $exe2"
        rlRun "mkdir test" 0 "Creating directory test"
        rlRun "gcc main.c -o $exe3" 0 "Creating binary $exe3"
        rlRun "gcc main.c -g -o $exe4" 0 "Creating binary $exe4"
        rlRun "echo $TmpDir > /etc/fapolicyd/fapolicyd.mounts" 0 "Setting fapolicyd to watch tmp diretory"
    rlPhaseEnd

    rlPhaseStartTest "Allow particular binary by path"
        rlRun 'echo -e \
"allow all path=$TmpDir/$exe1
deny all dir=$TmpDir/
allow all all" > /etc/fapolicyd/fapolicyd.rules' 0 "Setting fapolicyd rule allow binary $exe1 by path"
        rlAssertExists $exe1
        rlAssertExists $exe2
        rlAssertExists $exe3
        rlAssertExists $exe4
        rlRun "fapStart"
        rlRun "./$exe1" 0 "Executing binary $exe1 expected return value 0"
        rlRun "./$exe2" 126 "Executing binary $exe2 expected return value 126"
        rlRun "./$exe3" 126 "Executing binary $exe3 expected return value 126"
        rlRun "./$exe4" 126 "Executing binary $exe4 expected return value 126"
        rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartTest "Allow binaries in particular directory"
        rlRun 'echo -e \
"allow all dir=$TmpDir/test
deny all dir=$TmpDir/
allow all all" > /etc/fapolicyd/fapolicyd.rules' 0 "Setting fapolicyd rule allow binaries in directory test"
        rlAssertExists $exe1
        rlAssertExists $exe2
        rlAssertExists $exe3
        rlAssertExists $exe4
        rlRun "fapStart"
        rlRun "./$exe1" 126 "Executing binary $exe1 expected return value 126"
        rlRun "./$exe2" 126 "Executing binary $exe2 expected return value 126"
        rlRun "./$exe3" 0 "Executing binary $exe3 expected return value 0"
        rlRun "./$exe4" 0 "Executing binary $exe4 expected return value 0"
        rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartTest "Allow binaries based on hash"
        rlAssertExists $exe1
        rlAssertExists $exe2
        exe1Hash=`sha256sum -b $exe1 | awk '{print $1}'`
        rlRun 'echo -e \
"allow all sha256hash=$exe1Hash
deny all dir=$TmpDir/
allow all all" > /etc/fapolicyd/fapolicyd.rules' 0 "Setting fapolicyd rule allow binary $exe1 by hash"
        rlRun "fapStart"
        rlRun "./$exe1" 0 "Executing binary $exe1 expected return value 0"
        rlRun "./$exe2" 126 "Executing binary $exe2 expected return value 126"
        rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
