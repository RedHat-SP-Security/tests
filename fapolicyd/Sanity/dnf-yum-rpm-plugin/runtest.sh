#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: a sanity for dnf/yum and rpm plugin
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

spaces=${spaces:-false}

rlJournalStart
  rlPhaseStartSetup
    rlRun "rlImport --all" || rlDie 'cannot continue'
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rm -rf /root/rpmbuild"'
    rlRun "rm -rf /root/rpmbuild"
    cat > myprogram.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main()
{
  int num;

  for ( int i=0; i<180; i++ ) {
    FILE *fptr;

    fptr = fopen("/etc/resolv.conf","r");

    if(fptr == NULL)
    {
       printf("Error!");
       exit(1);
    }

    fclose(fptr);
    printf("myprogram\n");
    sleep(10);
  }
  return 0;
}
EOF

    cat > mypkg.spec << EOS
Name:       mypkg
Version:    1
Release:    1
Summary:    Most simple RPM package
License:    FIXME

#Source0: myprogram.c

%description
This is RPM package, containing just a testing script.

%prep
# let's skip this for now

%build
gcc -o myprogram ../SOURCES/myprogram.c

%install
mkdir -p %{buildroot}/usr/local/bin/
install -m 755 myprogram %{buildroot}/usr/local/bin/myprogram

%files
/usr/local/bin/myprogram

%changelog
# let's skip this for now
EOS

    rlRun "rpmdev-setuptree"
    rlRun "cp myprogram.c ~/rpmbuild/SOURCES/"
    rlRun "rpmbuild -ba mypkg.spec"
    rlRun "sed -i -r 's/(Version:).*/\1 2/' mypkg.spec"
    rlRun "sed -i -r 's/myprogram/\02/' myprogram.c"
    rlRun "rpmbuild -ba mypkg.spec"
    rlRun -s "find /root/rpmbuild/RPMS"
    rpm1=$(cat $rlRun_LOG | grep mypkg-1)
    rpm2=$(cat $rlRun_LOG | grep mypkg-2)
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "fapStop"'
    rlRun "fapStart"
  rlPhaseEnd


  for comm in dnf yum; do
    which $comm > /dev/null 2>&1 && rlPhaseStartTest "$comm" && {
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram" 1-255
      rlRun "fapStart"
      rlRun "$comm install -y $rpm1"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram"
      rlRun "fapStart"
      rlRun "$comm install -y $rpm2"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram"
      rlRun "fapStart"
      rlRun "$comm remove -y mypkg"
      rlRun "fapStop"
      rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram" 1-255
      rlRun "fapStart"
    rlPhaseEnd; }
  done

  rlPhaseStartTest "rpm" && {
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram" 1-255
    rlRun "fapStart"
    rlRun "rpm -ivh $rpm1"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram"
    rlRun "fapStart"
    rlRun "rpm -Uvh $rpm2"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram"
    rlRun "fapStart"
    rlRun "rpm -evh mypkg"
    rlRun "fapStop"
    rlRun "fapolicyd-cli -D | grep /usr/local/bin/myprogram" 1-255
    rlRun "fapStart"
  rlPhaseEnd; }

  rlPhaseStartCleanup
    CleanupDo
  rlPhaseEnd
rlJournalPrintText
rlJournalEnd
