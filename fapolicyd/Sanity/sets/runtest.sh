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

spaces=${spaces:-false}

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
        rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory'
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "fapCleanup"'
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
        rlAssertExists $exe1
        rlAssertExists $exe2
        rlAssertExists $exe3
        rlAssertExists $exe4
    rlPhaseEnd

    rlPhaseStartTest "list in path AC12 AC14" && {
      tcfChk "one file" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 126
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
      tcfChk "two files" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1,$TmpDir/$exe2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 0
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
      tcfChk "three files" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1,$TmpDir/$exe2,$TmpDir/$exe3
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 0
        rlRun "./$exe3" 0
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "named list in path AC13 AC14" && {
      tcfChk "one file" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%mylist=$TmpDir/$exe1
allow perm=any all : path=%mylist
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 126
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
      tcfChk "two files" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%mylist=$TmpDir/$exe1,$TmpDir/$exe2
allow perm=any all : path=%mylist
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 0
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
      tcfChk "three files" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%mylist=$TmpDir/$exe1,$TmpDir/$exe2,$TmpDir/$exe3
allow perm=any all : path=%mylist
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "./$exe1" 0
        rlRun "./$exe2" 0
        rlRun "./$exe3" 0
        rlRun "./$exe4" 126
        rlRun "fapStop"
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "unusual character in file name" && {
      tcfChk "semicollon (;)" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1;2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "cp $TmpDir/$exe1 $TmpDir/$exe1\;2"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1\;2"
        rlRun "./$exe1" 126
        rlRun "fapStop"
      tcfFin; }
      tcfChk "collon (:)" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1:2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "cp $TmpDir/$exe1 $TmpDir/$exe1:2"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1:2"
        rlRun "./$exe1" 126
        rlRun "fapStop"
      tcfFin; }
      $spaces && tcfChk "space ( )" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/${exe1}\ 2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "cp $TmpDir/$exe1 $TmpDir/${exe1}\ 2"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1\ 2"
        rlRun "./$exe1" 126
        rlRun "fapStop"
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "list with bad syntax AC18" && {
      tcfChk "semicollon (;)" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1;$TmpDir/$exe2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1" 126
        rlRun "./$exe2" 126
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
        rlRun "cat $fapolicyd_out"
      tcfFin; }
      $spaces && tcfChk "space ( )" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=$TmpDir/$exe1 $TmpDir/$exe2
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1" 126
        rlRun "./$exe2" 126
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
        rlRun "cat $fapolicyd_out"
      tcfFin; }
    rlPhaseEnd; }

    $spaces && rlPhaseStartTest "named list with bad syntax AC18" && {
      tcfChk "space ( )" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
%mylist=$TmpDir/$exe1 $TmpDir/$exe2
allow perm=any all : path=%mylist
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart"
        rlRun "fapolicyd-cli -l"
        rlRun "./$exe1" 126
        rlRun "./$exe2" 126
        rlRun "./$exe3" 126
        rlRun "./$exe4" 126
        rlRun "fapStop"
        rlRun "cat $fapolicyd_out"
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "non-existing named list AC19" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all : path=%mylist
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart" 1-255
        #rlRun "./$exe1" 126
        #rlRun "./$exe2" 126
        #rlRun "./$exe3" 126
        #rlRun "./$exe4" 126
        rlRun "fapStop"
        rlAssertGrep "set 'mylist'.*not defined before" $fapolicyd_out -Eiq
    rlPhaseEnd; }

    rlPhaseStartTest "invalid rule AC20" && {
        cat > /etc/fapolicyd/fapolicyd.rules <<EOF
allow perm=any all :
deny perm=any all : dir=$TmpDir/
allow perm=any all : all
EOF
        rlRun "cat /etc/fapolicyd/fapolicyd.rules"
        rlRun "fapStart" 1-255
        #rlRun "./$exe1" 126
        #rlRun "./$exe2" 126
        #rlRun "./$exe3" 126
        #rlRun "./$exe4" 126
        rlRun "fapStop"
    rlPhaseEnd; }

    rlPhaseStartCleanup
      CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
