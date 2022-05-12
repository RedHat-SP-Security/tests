#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc. All rights reserved.
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
. /usr/share/beakerlib/beakerlib.sh

PACKAGE="fapolicyd"

rlJournalStart
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister "testUserCleanup"
    rlRun "testUserSetup"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /usr/bin/ls2"
    rlRun "cp /usr/bin/ls /usr/bin/ls2"
    ld=$(readelf -e /usr/bin/bash | grep interpreter | grep -o '\s\S*/lib[^ ]*ld[^ ]*\.so[^] ]*')
    ld=/usr${ld:1}
    ld_real=$(realpath -e $ld)
    ld=$ld_real
    echo "ld='$ld'"
    #echo "ld_real='$ld_real'"
    cat > test-ld.c <<EOF
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

int main(void)
{
        int fd, rc, i;
        char path[32];
        char buf[48];
        char *rtl[3] = {
                "$ld",
                "/usr/bin/ls",
                NULL
        };

        printf("Hello World\n");
/*        for (i = 0; i < 5; i++) {
                fd = open("test.c", O_RDONLY);
                close(fd);
        } */
        snprintf(path, 32, "/proc/%d/exe", getpid());
        rc = readlink(path, buf, 47);
//        close(fd);
        if (rc < 0)
                return 1;
        if (rc < 48)
                buf[rc] = 0;
        else
                buf[47] = '\0';
        printf("%s\n", buf);
//        sleep(10);
        execve(rtl[0], rtl, NULL);
        return 0;
}
EOF
    rlRun "gcc -static -o /usr/local/bin/test-ld.stat test-ld.c"
    rlRun "gcc -o /usr/local/bin/test-ld.dyn test-ld.c"
    rlRun "ls -la"
    CleanupRegister "rlRun 'fapServiceRestore'"
    CleanupRegister "
      rlRun 'fapolicyd-cli --file delete /usr/local/bin/test-ld.stat'
      rlRun 'fapolicyd-cli --file delete /usr/local/bin/test-ld.dyn'
    "
    rlRun "fapolicyd-cli --file add /usr/local/bin/test-ld.stat"
    rlRun "fapolicyd-cli --file add /usr/local/bin/test-ld.dyn"
    rlRun "chmod a+x /usr/local/bin/test*"
    rlRun "ldd /usr/local/bin/test*" 0-255
    ## remove pattern=ld_so rule(s)
    #if [[ -e /etc/fapolicyd/fapolicyd.rules ]]; then
    #  rlRun "sed -r -i '/pattern=ld_so/d' /etc/fapolicyd/fapolicyd.rules"
    #else
    #  rlRun "sed -r -i '/pattern=ld_so/d' /etc/fapolicyd/rules.d/*"
    #fi
    rlRun "fapStart --debug"
  rlPhaseEnd; }

  for user in root $testUser; do
    for dynstat in dyn stat; do
        rlPhaseStartTest "execute through ld.so ${dynstat} as $user" && {
          fapResetServiceOutTimestamp
          rlRun "su -c '/usr/local/bin/test-ld.${dynstat}' - $user"
          sleep 1
          fapServiceOut > out
          pid=$(grep -E -o "rule=.*perm=execute.*path=/usr/local/bin/test-ld" out | sed -r 's/.*pid=([0-9]+) .*/\1/')
          rlRun -s "grep -E -A 100 'rule=.*perm=execute.*path=/usr/local/bin/test-ld' out | grep -E 'pid=$pid '"
          echo --
          grep -E -A 100 'rule=.*path=/usr/bin/ls' $rlRun_LOG | tail -n +2
          echo --
          [[ -z "$(grep -E -A 100 'rule=.*path=/usr/bin/ls' $rlRun_LOG | tail -n +2 | grep -v "exe=$ld")" ]]
          rlAssert0 "the output does not contain different exe than $ld after execution /usr/bin/ls" $?
        rlPhaseEnd; }
    done
  done

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }

    rlJournalPrintText
rlJournalEnd
