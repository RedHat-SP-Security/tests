#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/rules-fuzz
#   Description: performs fuzz testing on config/rules files
#   Author: Jiri Jaburek <jjaburek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

PACKAGE="usbguard"
LATEST_BUILDROOT="http://download-node-02.eng.bos.redhat.com/redhat/rhel-7/rel-eng/BUILDROOT-7/latest-BUILDROOT-7-RHEL-7/compose/Server/$(uname -m)/os/"

install_repo() {
    cat > "/etc/yum.repos.d/$1.repo" <<EOF
[$1]
name=$1
baseurl=$2
enabled=1
gpgcheck=0
EOF
}
remove_repo() {
    rm -f "/etc/yum.repos.d/$1.repo"
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "rlImport distribution/fuzz"

        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "cp usbguard-rules.dict $TmpDir"
        rlRun "pushd $TmpDir"

        rlRun "install_repo usbguard-latest-buildroot $LATEST_BUILDROOT"
        rlRun "yum remove -y usbguard.i686" 0 "Workaround to be able to run in beaker - remove secondary arch before rebuild"

        rlRun "fuzzInstallAfl"
        rlRun "fuzzOptimizeSystem"
        rlRun "CC=afl-gcc CXX=afl-g++ AFL_HARDEN=1 fuzzRebuildPackage usbguard-tools"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "mkdir input && echo > input/seed"
        rlWatchdog "AFL_NO_UI=1 afl-fuzz -i input -o tmp/output -x usbguard-rules.dict -- usbguard-rule-parser -f @@" 86400 INT
        for type in crashes hangs; do
            rlAssertExists "tmp/output/$type"
            if [ "$(ls -1 tmp/output/$type)" ]; then
                rlFail "some $type found"
                for i in tmp/output/$type/*; do
                    rlLogInfo "reproducer $i (base64): $(base64 $i)"
                done
            else
                rlPass "no $type found"
            fi
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "fuzzRestorePackages"
        rlRun "fuzzUnoptimizeSystem"
        rlRun "remove_repo usbguard-latest-buildroot"
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
