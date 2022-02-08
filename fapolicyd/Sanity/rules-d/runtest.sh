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
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "fapCleanup"'
    rlRun "fapSetup"
    rlRun "rlFetchSrcForInstalled fapolicyd"
    rlRun "rpm -ivh ./fapolicyd*.src.rpm"
    rlRun "yum-builddep -y ~/rpmbuild/SPECS/fapolicyd.spec"
    rlRun -s "rpmbuild -bb -D 'dist _99' ~/rpmbuild/SPECS/fapolicyd.spec"
    CleanupRegister --mark "rlRun 'RpmSnapshotRevert'; rlRun 'RpmSnapshotDiscard'"
    rlRun "RpmSnapshotCreate"
    #rlRun "RpmSnapshotRevert"
    rlRun "mkdir rpms"
    pushd rpms
    rlRun "cp $(grep 'Wrote:' $rlRun_LOG | cut -d ' ' -f 2 | tr '\n' ' ') ./"
    IFS=' ' read -r SRC N V R A < <(rpm -q --qf '%{sourcerpm} %{name} %{version} %{release} %{arch}\n' fapolicyd)
    V_new="$V"
    R_new="${R}_99"
    rlIsFedora && {
      V_old=1.0.4
      R_old=1.fc35
    }
    rlIsRHELLike '>=8.6' && {
      V_old=1.0.2
      R_old=6.el8
    }
    while read -r NULL N NULL NULL A; do
      rlRpmDownload $N $V_old $R_old $A
    done < <(rpm -qa --qf '%{sourcerpm} %{name} %{version} %{release} %{arch}\n' | grep "^$SRC ")
    rlRun "createrepo --database ./"
    rlRun "ls -la"
    popd
    which dnf &>/dev/null && _dnfc=dnf\ || _dnfc=yum-
    rlRun "${_dnfc}config-manager --add-repo file://$PWD/rpms"
    repofile=$(grep -l "file://$PWD/rpms" /etc/yum.repos.d/*.repo)
    CleanupRegister "rlRun 'rm -f $repofile'"
    rlRun "echo -e 'sslverify=0\ngpgcheck=0\nskip_if_unavailable=1' >> $repofile"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
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
    
    rlPhaseStartTest "upgrade from old version - default rules" && {
      CleanupRegister --mark "rlRun 'RpmSnapshotRevert'"
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V_old-$R_old -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertNotExists /etc/fapolicyd/fapolicyd.rules
      rlAssertGreater "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
      CleanupDo --mark
    rlPhaseEnd; }
    
    rlPhaseStartTest "upgrade from old version - changed rules" && {
      CleanupRegister --mark "rlRun 'RpmSnapshotRevert'"
      rlRun "rm -rf /etc/fapolicyd"
      rlRun "yum install fapolicyd-$V_old-$R_old -y --allowerasing"
      echo "allow perm=any all : all" >> /etc/fapolicyd/fapolicyd.rules
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "yum install fapolicyd-$V-$R -y --allowerasing"
      rlRun "ls -la /etc/fapolicyd/"
      rlRun "ls -la /etc/fapolicyd/rules.d/"
      rlAssertExists /etc/fapolicyd/fapolicyd.rules
      rlAssertEquals "rules are deployed into /etc/fapolicyd/rules.d" $(ls -1 /etc/fapolicyd/rules.d | wc -w) 0
      CleanupDo --mark
    rlPhaseEnd; }
    
    false && rlPhaseStartTest "upgrade - fapolicyd.rules exists" && {
      CleanupRegister --mark "rlRun 'RpmSnapshotRevert'"
      cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%languages=application/x-bytecode.ocaml,application/x-bytecode.python,application/java-archive,text/x-java,application/x-java-applet,application/javascript,text/javascript,text/x-awk,text/x-gawk,text/x-lisp,application/x-elc,text/x-lua,text/x-m4,text/x-nftables,text/x-perl,text/x-php,text/x-python,text/x-R,text/x-ruby,text/x-script.guile,text/x-tcl,text/x-luatex,text/x-systemtap
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
      rlRun "yum update -y fapolicyd"
      rlRun "ls -la /etc/fapolicyd/rules.d"
      rlRun "ls -la /etc/fapolicyd/fapolicyd.rules"
      #rlRun "sed -ri 's///' ~/rpmbuild/SPECS/fapolicyd.spec"
      CleanupDo --mark
    rlPhaseEnd; }
  
    false && rlPhaseStartTest "precedence of fapolicyd.rules" && {
      CleanupRegister --mark 'rlRun "rm -f /etc/fapolicyd/fapolicyd.rules"'
      cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%languages=application/x-bytecode.ocaml,application/x-bytecode.python,application/java-archive,text/x-java,application/x-java-applet,application/javascript,text/javascript,text/x-awk,text/x-gawk,text/x-lisp,application/x-elc,text/x-lua,text/x-m4,text/x-nftables,text/x-perl,text/x-php,text/x-python,text/x-R,text/x-ruby,text/x-script.guile,text/x-tcl,text/x-luatex,text/x-systemtap
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
      rlRun "fapStart"
      rlRun "fapStop"
      rlRun -s "fapServiceOut"
      rlAssertGrep "/my/special/rule" $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }
    :
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
