#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/users-shell-script
#   Description: Test for BZ#1801872 (user may run and surce a shell script)
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="fapolicyd"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "testUserCleanup"'
    rlRun "testUserSetup"
    rlRun "echo '#!/bin/bash' > $testUserHomeDir/a.sh"
    rlRun "echo 'echo a' >> $testUserHomeDir/a.sh"
    rlRun "echo 'source ./b.sh' >> $testUserHomeDir/a.sh"
    rlRun "echo '#!/bin/bash' > $testUserHomeDir/b.sh"
    rlRun "echo 'echo b' >> $testUserHomeDir/b.sh"
    rlRun "chmod a+x $testUserHomeDir/a.sh $testUserHomeDir/b.sh"
    cat > myscript.spec << EOS
Name:       myscript
Version:    1
Release:    1
Summary:    Most simple RPM package
License:    FIXME
BuildArch:  noarch

%description
This is RPM package, containing just a testing script.

%prep
# we have no source, so nothing here

%build
cat > myscript.sh <<EOF
#!/bin/bash
echo trusted
EOF

%install
mkdir -p %{buildroot}/usr/bin/
install -m 755 myscript.sh %{buildroot}/usr/bin/myscript.sh

%files
/usr/bin/myscript.sh

%changelog
# let's skip this for now
EOS

    rlRun "rpmdev-setuptree"
    rlRun "rpmbuild -ba myscript.spec"
    CleanupRegister 'rpm -e myscript'
    rlRun "rpm -i /root/rpmbuild/RPMS/noarch/myscript-1-1.noarch.rpm"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    CleanupRegister 'rlRun "fapStop"'
    rlRun "fapStart" > /dev/null
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "execute user's untrusted script" && {
      rlRun -s "su - $testUser -c './a.sh'"
      rlAssertGrep '^a$' $rlRun_LOG
      rlAssertGrep '^b$' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
    rlPhaseStartTest "source user's untrusted script" && {
      rlRun -s "su - $testUser -c '. ./b.sh'"
      rlAssertGrep '^b$' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
    rlPhaseStartTest "execute trusted script" && {
      rlRun -s "su - $testUser -c 'myscript.sh'"
      rlAssertGrep '^trusted$' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
    rlPhaseStartTest "source trusted script" && {
      rlRun -s "su - $testUser -c '. myscript.sh'"
      rlAssertGrep '^trusted$' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
