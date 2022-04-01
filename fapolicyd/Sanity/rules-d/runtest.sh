#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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
    IFS=' ' read -r SRC N V R A < <(rpm -q --qf '%{sourcerpm} %{name} %{version} %{release} %{arch}\n' fapolicyd)
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /root/rpmbuild"
    CleanupRegister --mark "rlRun 'RpmSnapshotRevert'; rlRun 'RpmSnapshotDiscard'"
    rlRun "RpmSnapshotCreate"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    rlRun "rlFetchSrcForInstalled fapolicyd"
    rlRun "rpm -ivh ./fapolicyd*.src.rpm"
    rlRun "yum-builddep -y ~/rpmbuild/SPECS/fapolicyd.spec"
    R2=".$(echo "$R" | cut -d . -f 2-)"
    rlRun -s "rpmbuild -bb -D 'dist ${R2}_98' ~/rpmbuild/SPECS/fapolicyd.spec" 0 "build newer package"
    rlRun_LOG1=$rlRun_LOG
    rlRun "(cd ~/rpmbuild/SPECS/; patch -p0)" << 'EOF'
--- fapolicyd.spec      2022-01-26 09:04:22.000000000 -0500
+++ fapolicyd.spec  2022-02-08 13:42:23.601603383 -0500
@@ -37,1 +37,2 @@
+Patch99: rules.patch
 %description
@@ -89,1 +89,2 @@
+%patch99 -p1 -b .rules
 %build
EOF
    cat > ~/rpmbuild/SOURCES/rules.patch << 'EOF'
diff --git a/rules.d/95-allow-open.rules b/rules.d/95-allow-open.rules
index c0ab31c..9103e12 100644
--- a/rules.d/95-allow-open.rules
+++ b/rules.d/95-allow-open.rules
@@ -1,1 +1,1 @@
-allow perm=open all : all
+allow perm=any all : all
EOF
    rlRun -s "rpmbuild -bb -D 'dist ${R2}_99' ~/rpmbuild/SPECS/fapolicyd.spec" 0 "build newer package with updated default rules"
    rlRun "mkdir rpms"
    pushd rpms
    rlRun "cp $(grep 'Wrote:' $rlRun_LOG | cut -d ' ' -f 2 | tr '\n' ' ') $(grep 'Wrote:' $rlRun_LOG1 | cut -d ' ' -f 2 | tr '\n' ' ') ./"
    packages=()
    rlIsFedora && {
      V_old=1.0.4
      R_old=1.fc35
    }
    rlIsRHEL '>=8' || rlIsRHELLike '>=8' && {
      V_old=1.0.2
      R_old=6.el8
    }
    rlIsRHEL '>=9' || rlIsRHELLike '>=9' && {
      V_old=1.0.3
      R_old=4.el9
      packages+=(
        fapolicyd-dnf-plugin-${V_old}-${R_old}.noarch
      )
    }
    packages+=(
      fapolicyd-${V_old}-${R_old}.$A
      #fapolicyd-debuginfo-${V_old}-${R_old}.$A
      #fapolicyd-debugsource-${V_old}-${R_old}.$A
      fapolicyd-selinux-${V_old}-${R_old}.noarch
    )

    for package in "${packages[@]}"; do
      rlRpmDownload $package
    done
    rlRun "createrepo --database ./"
    rlRun -s "ls -la"
    _98=$( cat $rlRun_LOG | grep -o 'fapolicyd-[0-9].*_98.*\.rpm' | sed -r 's/\.rpm//' )
    _99=$( cat $rlRun_LOG | grep -o 'fapolicyd-[0-9].*_99.*\.rpm' | sed -r 's/\.rpm//' )
    popd
    which dnf &>/dev/null && _dnfc=dnf\ || _dnfc=yum-
    rlRun "${_dnfc}config-manager --add-repo file://$PWD/rpms"
    repofile=$(grep -l "file://$PWD/rpms" /etc/yum.repos.d/*.repo)
    CleanupRegister "rlRun 'rm -f $repofile'"
    rlRun "yum clean all"
    rlRun "echo -e 'sslverify=0\ngpgcheck=0\nskip_if_unavailable=1' >> $repofile"
    rlRun "repoquery -a | grep fapolicyd" 0-255
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "clean install" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum remove fapolicyd -y"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertNotExists /etc/fapolicyd/fapolicyd.rules
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    rlPhaseStartTest "rules order" && {
      CleanupRegister --mark 'rlRun "rm -f /etc/fapolicyd/rules.d/5{1,2,3}-custom.rules"'
      rlRun "echo 'allow perm=open exe=/path/to/binary1 : all' > /etc/fapolicyd/rules.d/52-custom.rules"
      rlRun "echo 'allow perm=open exe=/path/to/binary2 : all' > /etc/fapolicyd/rules.d/51-custom.rules"
      rlRun "echo 'allow perm=open exe=/path/to/binary3 : all' > /etc/fapolicyd/rules.d/53-custom.rules"
      rlRun "fagenrules"
      rlRun "cat /etc/fapolicyd/compiled.rules"
      rlRun "cat /etc/fapolicyd/compiled.rules | tr '\n' ' ' | grep -q 'binary2.*binary1.*binary3'" 0 "check correct order"
      CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "concurent rules present" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum reinstall fapolicyd-$V-$R -y"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertNotExists /etc/fapolicyd/fapolicyd.rules
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
      cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%languages=application/x-bytecode.ocaml,application/x-bytecode.python,application/java-archive,text/x-java,application/x-java-applet,application/javascript,text/javascript,text/x-awk,text/x-gawk,text/x-lisp,application/x-elc,text/x-lua,text/x-m4,text/x-nftables,text/x-perl,text/x-php,text/x-python,text/x-R,text/x-ru
deny_audit perm=any pattern=ld_so : all
allow perm=any uid=0 : dir=/var/tmp/
allow perm=any uid=0 trust=1 : all
allow perm=open exe=/usr/bin/rpm : all
allow perm=open exe=/usr/bin/python3.10 comm=dnf : all
deny_audit perm=any all : ftype=application/x-bad-elf
allow perm=open all : ftype=application/x-sharedlib trust=1
deny_audit perm=open all : ftype=application/x-sharedlib
allow perm=any exe=/my/special/rule : trust=1
allow perm=execute all : trust=1
allow perm=open all : ftype=%languages trust=1
deny_audit perm=any all : ftype=%languages
allow perm=any all : ftype=text/x-shellscript
deny_audit perm=execute all : all
allow perm=open all : all
EOF
      rlRun -s "fapStart" 1-255
      rlAssertGrep 'Error - both old and new rules exist' $rlRun_LOG
      rm -f /etc/fapolicyd/fapolicyd.rules
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade from old version - default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V_old-$R_old -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V_old-$R_old -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertNotExists /etc/fapolicyd/fapolicyd.rules
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade from old version - changed rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V_old-$R_old -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V_old-$R_old -y --allowerasing"
      echo "allow perm=any all : all" >> /etc/fapolicyd/fapolicyd.rules
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertExists /etc/fapolicyd/fapolicyd.rules
      rlAssertEquals "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade to new version - changed default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      echo "allow perm=any all : all" >> /etc/fapolicyd/rules.d/95-allow-open.rules
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=any' $rlRun_LOG
      rlRun "yum install ${_98} -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=any' $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade to new version - updated default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlRun "yum install ${_99} -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertNotGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=any' $rlRun_LOG
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade to new version - custom rules file added" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "echo 'allow perm=open exe=/path/to/binary : all' > /etc/fapolicyd/rules.d/51-custom.rules"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=open exe=/path/to/binary : all' /etc/fapolicyd/rules.d/51-custom.rules
      rlRun "yum install ${_98} -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=open exe=/path/to/binary : all' /etc/fapolicyd/rules.d/51-custom.rules
    rlPhaseEnd; }

    rlPhaseStartTest "upgrade to new version - custom rules file added + updated default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "echo 'allow perm=open exe=/path/to/binary : all' > /etc/fapolicyd/rules.d/51-custom.rules"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=open exe=/path/to/binary : all' /etc/fapolicyd/rules.d/51-custom.rules
      rlRun "yum install ${_99} -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertNotGrep 'allow perm=any' $rlRun_LOG
      rlAssertGrep 'allow perm=open exe=/path/to/binary : all' /etc/fapolicyd/rules.d/51-custom.rules
    rlPhaseEnd; }

    rlPhaseStartTest "uninstall - default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlRun "yum remove fapolicyd -y"
      rlRun "ls -la /etc/fapolicyd/" 0-255
      rlRun "ls -la /etc/fapolicyd/rules.d/" 0-255
      [[ -d /etc/fapolicyd/rules.d/ ]] && rlAssertEquals "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    rlPhaseStartTest "uninstall - custom rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "echo 'allow perm=open exe=/path/to/binary : all' > /etc/fapolicyd/rules.d/51-custom.rules"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=open' $rlRun_LOG
      rlAssertGrep 'allow perm=open exe=/path/to/binary : all' /etc/fapolicyd/rules.d/51-custom.rules
      rlRun "yum remove fapolicyd -y"
      rlRun "ls -la /etc/fapolicyd/" 0-255
      rlRun "ls -la /etc/fapolicyd/rules.d/" 0-255
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    rlPhaseStartTest "uninstall - changed default rules" && {
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "yum reinstall fapolicyd-$V-$R -y --allowerasing"
      rlRun "sed -ir 's/open/any/' /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlRun -s "cat /etc/fapolicyd/rules.d/95-allow-open.rules"
      rlAssertGrep 'allow perm=any' $rlRun_LOG
      rlRun "yum remove fapolicyd -y"
      rlRun "ls -la /etc/fapolicyd/" 0-255
      rlRun "ls -la /etc/fapolicyd/rules.d/" 0-255
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
    rlPhaseEnd; }

    :
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
