#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Functional/SoftwareRestrictionPoliciesTest12
#   Description: The evaluator will configure the OS to only allow code execution from the core OS di    rectories. The evaluator will then attempt to execute code from a directory that is in the allowed list. The evaluator will ensure that the code they attempted to execute has been executed. The evaluator will then attempt to execute code from a directory that is not in the allowed list. The evaluator will ensure that the code they attempted to execute has not been executed.
#   Author: Marek Tamaskovic <mtamasko@redhat.com>
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
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "useradd xxx"
        rlRun "fapSetup"
        cat >main.c <<EOF
/*execv_ls-l.c*/
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

int main(int argc, char * argv[]){
  char * ls_args[] = { "/bin/ls" , "-l", NULL};
  execv(   ls_args[0],     ls_args);
  //only get here on error
  perror("execv");
  return 2;
}
EOF
    rlRun "gcc main.c -o my-ls"
        rlRun "chown -R xxx:xxx ."
    rlRun "cat /etc/fapolicyd/fapolicyd.rules"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "fapStart"
        rlAssertExists "my-ls"
        rlRun "ls -l"
        rlRun "su -c 'cd $PWD; ./my-ls' - xxx" 126
        rlRun "sudo -u xxx ./my-ls" 1
        rlRun "fapStop"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
        rlRun "userdel -fr xxx"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
