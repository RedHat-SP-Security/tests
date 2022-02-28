#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Functional/SoftwareRestrictionPoliciesTest7
#   Description: The evaluator will configure the OS to allow execution based on the hash of the application executable. The evaluator will then attempt to execute the application with the matching hash. The evaluator will ensure that the code they attempted to execute has been executed.
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
        rlRun "fapSetup"
        [[ -e /etc/fapolicyd/rules.d ]] && {
          rlRun "mv /etc/fapolicyd/compiled.rules /etc/fapolicyd/fapolicyd.rules"
          rlRun "rm -f /etc/fapolicyd/rules.d/*"
        }
	rlRun "mkdir testing"
	rlRun 'echo -e "#!/bin/bash\nid\n" > testing/myscript'
	rlRun "chmod a+x testing/myscript"
	vHash=`sha256sum -b testing/myscript | awk '{print $1}'`
	rlRun "echo $TmpDir/testing/ > /etc/fapolicyd/fapolicyd.mounts" 0 "Setting fapolicyd to watch tmp diretory"
    rlPhaseEnd

    rlPhaseStartTest "positive"
	cat>/etc/fapolicyd/fapolicyd.rules <<EOF
allow all sha256hash=$vHash
deny all dir=$TmpDir/testing/
allow all dir=execdirs
allow exe=/usr/bin/bash all
deny_audit all ftype=application/x-executable
EOF
	rlRun "cat /etc/fapolicyd/fapolicyd.rules"
	rlRun "fapStart"
        rlRun "./testing/myscript"
	rlRun "fapStop"
        rlRun 'echo "true" >> testing/myscript'
	rlRun "fapStart"
        rlRun "./testing/myscript" 126
	rlRun "fapStop"
        rlRun 'sed -r -i "/true/d" testing/myscript'
    rlPhaseEnd

    rlPhaseStartTest "negative"
	cat>/etc/fapolicyd/fapolicyd.rules <<EOF
deny all sha256hash=$vHash
allow all dir=$TmpDir/testing/
allow all dir=execdirs
allow exe=/usr/bin/bash all
deny_audit all ftype=application/x-executable
EOF
	rlRun "cat /etc/fapolicyd/fapolicyd.rules"
	rlRun "fapStart"
        rlRun "./testing/myscript" 126
	rlRun "fapStop"
        rlRun 'echo "true" >> testing/myscript'
	rlRun "fapStart"
        rlRun "./testing/myscript"
	rlRun "fapStop"
        rlRun 'sed -r "/true/d" testing/myscript'
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fapCleanup"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
