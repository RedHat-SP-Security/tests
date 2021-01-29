#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/fapolicyd/Library/common
#   Description: A library for manipulation with sudoers entries locally and in ldap via sudo-ldap or sssd.
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
#   library-prefix = fap
#   library-version = 19
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

library(fapolicyd/common) - A set of fimple function to support testing of fapolicyd.

=head1 DESCRIPTION

The library contains function for running and stopping the daemon,
backing up and restoring the necessary files.

=head1 USAGE

To use this functionality you need to import library fapolicyd/ldap and
add following line to Makefile.

        @echo "RhtsRequires:    library(fapolicyd/common)" >> $(METADATA)

And in the code to include rlImport fapolicyd/common or just
I<rlImport --all> to import all libraries specified in Makelife.
You should always run fapSetup in Setup phase and fapClenaup in Cleanup phase.
It restores files,services and selinux booleans.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 FUNCTIONS

=cut

fapSetup() {
  rlRun "rlServiceStop fapolicyd"
  rlRun "rlFileBackup --namespace fap --clean /etc/fapolicyd/"
  rlRun "rm -f /var/lib/fapolicyd/*"
  rlRun "rlSEBooleanOn --namespace fap daemons_use_tty"
  if [[ -z "$(sesearch -A -s init_t -t unconfined_t -c fifo_file -p write)" ]]; then
    cat > mujfamodul.te <<EOF
policy_module(mujfamodul,1.0)

require {
  type unconfined_t;
  type init_t;
}

allow init_t unconfined_t : fifo_file { append getattr ioctl lock read write };
EOF
    rlRun "make -f /usr/share/selinux/devel/Makefile"
    rlRun "semodule -i mujfamodul.pp"
    __INTERNAL_fap_semodule=true
  fi
}

__INTERNAL_fap_semodule=false

fapCleanup() {
  fapStop
  $__INTERNAL_fap_semodule && rlRun "semodule -r mujfamodul"
  rlRun 'rm -rf /var/lib/fapolicyd/*'
  [[ -n "${fapolicyd_out[*]}" ]] && rm -f "${fapolicyd_out[@]}"
  rlRun "rlSEBooleanRestore --namespace fap"
  rlRun "rlFileRestore --namespace fap"
  rlRun "rlServiceRestore fapolicyd"
}

fapStart() {
  fapolicyd_out=( `mktemp` "${fapolicyd_out[@]}" )
  local res fapolicyd_path tail_pid FADEBUG
  res=0
  FADEBUG='--debug-deny'
  [[ "$1" == "--debug" ]] && {
    FADEBUG='--debug'
    shift
  }
  fapolicyd_path="$1"
  if [[ -n "$fapolicyd_path" ]]; then
    [[ "$fapolicyd_path" =~ /$ ]] || fapolicyd_path+="/"
    rlLogInfo "running fapolicyd from alternative path $fapolicyd_path"
  fi
  runcon -u system_u -r system_r -t init_t bash -c "${fapolicyd_path}fapolicyd $FADEBUG; echo -e \"\nRETURN CODE: \$?\"" 2>&1 | cat > $fapolicyd_out &
  tail -f $fapolicyd_out >&2 &
  tail_pid=$!
  local i=50
  # wait up to 5s to start the process
  while ((--i)) && ! pidof fapolicyd >/dev/null; do sleep 0.1; done
  local t=$(($(date +%s) + 120))
  while ! grep -q 'Starting to listen for events' $fapolicyd_out >&2 && pidof fapolicyd >/dev/null; do
    sleep 1
    echo -n . >&2
    [[ $(date +%s) -gt t ]] && {
      let res++
      break
    }
  done
  disown $tail_pid
  kill $tail_pid
  echo
  pidof fapolicyd >/dev/null || let res++
  return $res
}

# -k - keep output log file
fapStop() {
  local keep=false tail_pid
  tail -n 0 -f $fapolicyd_out >&2 &
  tail_pid=$!
  rlLogInfo "stopping the daemon"
  kill $(pidof fapolicyd)
  local t=$(($(date +%s) + 120))
  while pidof fapolicyd > /dev/null; do
    sleep 1
    echo -n .
    [[ $(date +%s) -gt t ]] && {
      res=1
      break
    }
  done
  pidof fapolicyd > /dev/null && {
    rlLogInfo "killing the daemon"
    rlRun "kill -9 \$(pidof fapolicyd); sleep 1s"
  }
  disown $tail_pid
  kill $tail_pid
  ! pidof fapolicyd > /dev/null
}

fapServiceStart() {
  local res
  rlServiceStart fapolicyd
  res=$?
  [[ $res -eq 0 ]] && sleep 30
  return $?
}

fapServiceStop() {
  local res
  rlServiceStop fapolicyd
  res=$?
  [[ $res -eq 0 ]] && sleep 5
  return $?
}

fapServiceRestore() {
  local res
  rlServiceRestore fapolicyd
  res=$?
  [[ $res -eq 0 ]] && sleep 30
  return $?
}

fapPrepareTestPackages() {
  rlRun "rm -rf ~/rpmbuild"
  rlRun "rpmdev-setuptree"
  cat > ~/rpmbuild/SOURCES/fapTestProgram.c << 'EOF'
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
    printf("fapTestProgram\n");
    sleep(10);
  }
  return 0;
}
EOF

  cat > ~/rpmbuild/SPECS/fapTestPackage.spec << EOS
Name:       fapTestPackage
Version:    1
Release:    1
Summary:    Most simple RPM package
License:    FIXME

%description
This is RPM package, containing just a testing script.

%prep
# let's skip this for now

%build
gcc -o fapTestProgram ../SOURCES/fapTestProgram.c

%install
mkdir -p %{buildroot}/usr/local/bin/
install -m 755 fapTestProgram %{buildroot}/usr/local/bin/fapTestProgram

%files
/usr/local/bin/fapTestProgram

%changelog
# let's skip this for now
EOS

  rlRun "rpmbuild -ba ~/rpmbuild/SPECS/fapTestPackage.spec"
  rlRun "sed -i -r 's/(Version:).*/\1 2/' ~/rpmbuild/SPECS/fapTestPackage.spec"
  rlRun "sed -i -r 's/fapTestProgram/\02/' ~/rpmbuild/SOURCES/fapTestProgram.c"
  rlRun "rpmbuild -ba ~/rpmbuild/SPECS/fapTestPackage.spec"
  rlRun "mv ~/rpmbuild/RPMS/*/fapTestPackage-* ./"
  rlRun "rm -rf ~/rpmbuild"
  fapTestPackage=( $(find $PWD | grep 'fapTestPackage-') )
  fapTestProgram=/usr/local/bin/fapTestProgram
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

fapLibraryLoaded() {
    if rpm=$(rpm -q fapolicyd); then
        rlLogDebug "Library fapolicyd/common running with $rpm"
        return 0
    else
        rlLogError "Package sudo not installed"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut
