#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/sets
#   Description: Test for sets and named sets.
#   Author: Zoltan Fridrich <zfridric@redhat.com>
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

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" || rlDie 'cannot continue'
      rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    cat > test_package.spec <<'EOF'
Name:       test_package
Version:    1
Release:    1
Summary:    this is a test package
License:    MIT
BuildArch:  noarch

%description
this is a test package

%prep
# let's skip this for now

%build
true

%install
mkdir -p $RPM_BUILD_ROOT/usr/lib/test_package
echo "this is a test file" > $RPM_BUILD_ROOT/usr/lib/test_package/test_file.txt

%files
/usr/lib/test_package/test_file.txt

%changelog
EOF
    CleanupRegister 'rlRun "rm -f ~/rpmbuild/RPMS/noarch/test_package-1-1.noarch.rpm"'
    rlRun "rpmbuild -bb --define '_binary_filedigest_algorithm 1' ./test_package.spec" 0 "create rpm with md5 digest"
    CleanupRegister 'rlRun "rpm -e test_package"'
    rlRun "rpm -i ~/rpmbuild/RPMS/noarch/test_package-1-1.noarch.rpm"
  rlPhaseEnd; }

  rlPhaseStartTest "md5 package" && {
    rlRun "sed -r -i '/rpm_sha256_only/d' /etc/fapolicyd/fapolicyd.conf"
    rlRun "rm -f /var/lib/fapolicyd/*"
    fapStart
    fapStop
    rlRun "fapolicyd-cli -D | grep /usr/lib/test_package/test_file.txt"
  rlPhaseEnd; }

  rlPhaseStartTest "md5 package with rpm_sha256_only = 0" && {
    rlRun "sed -r -i '/rpm_sha256_only/d' /etc/fapolicyd/fapolicyd.conf"
    rlRun "echo 'rpm_sha256_only = 0' >> /etc/fapolicyd/fapolicyd.conf"
    rlRun "rm -f /var/lib/fapolicyd/*"
    fapStart
    fapStop
    rlRun "fapolicyd-cli -D | grep /usr/lib/test_package/test_file.txt"
  rlPhaseEnd; }

  rlPhaseStartTest "md5 package with rpm_sha256_only = 1" && {
    rlRun "sed -r -i '/rpm_sha256_only/d' /etc/fapolicyd/fapolicyd.conf"
    rlRun "echo 'rpm_sha256_only = 1' >> /etc/fapolicyd/fapolicyd.conf"
    rlRun "rm -f /var/lib/fapolicyd/*"
    fapStart
    fapStop
    rlRun "fapolicyd-cli -D | grep /usr/lib/test_package/test_file.txt" 1
  rlPhaseEnd; }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
rlJournalPrintText
rlJournalEnd; }
