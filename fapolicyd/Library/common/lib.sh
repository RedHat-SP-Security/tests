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
#   library-version = 23
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
  rlRun "rlFileBackup --namespace fap --clean /etc/fapolicyd/ /etc/systemd/system/fapolicyd.service.d"
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
  [[ -f /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf ]] && {
    rm -f /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf
    systemctl daemon-reload
  }
  [[ -n "${fapolicyd_out[*]}" ]] && rm -f "${fapolicyd_out[@]}"
  rlRun "rlSEBooleanRestore --namespace fap"
  rlRun "rlFileRestore --namespace fap"
  rlRun "rlServiceRestore fapolicyd"
}

fapServiceOut() {
  if [[ -n "$__INTERNAL_fapolicyd_start_timestamp" ]]; then
    local background='0' output_style='cat'
    while [[ -n "$1" ]]; do
      case $1 in
        -b)
          background=1
        ;;
        -t)
          output_style=short
        ;;
        *)
          break
        ;;
      esac
      shift
    done
    if [[ "$background" == "1" ]]; then
      journalctl -u fapolicyd --full --since "$__INTERNAL_fapolicyd_start_timestamp" --no-pager --output $output_style "$@" &
    else
      journalctl -u fapolicyd --full --since "$__INTERNAL_fapolicyd_start_timestamp" --no-pager --output $output_style "$@"
    fi
  fi
}

fapStart() {
  local res fapolicyd_path tail_pid FADEBUG SYSTEMD_RELOAD
  res=0
  FADEBUG='--debug-deny'
  if [[ "$1" == "--debug" ]]; then
    FADEBUG='--debug '
    shift
  elif [[ "$1" == "--no-debug" ]]; then
    FADEBUG=''
    [[ -s /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf ]] && {
      rm -f /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf
      SYSTEMD_RELOAD=1
    }
    shift
  fi
  fapolicyd_path="$1"
  if [[ -n "$fapolicyd_path" ]]; then
    [[ "$fapolicyd_path" =~ /$ ]] || fapolicyd_path+="/"
    rlLogInfo "running fapolicyd from alternative path $fapolicyd_path"
  fi
  [[ -z "$fapolicyd_path" ]] && fapolicyd_path="/usr/sbin/"
  if [[ -n "$FADEBUG" ]]; then
    mkdir -p /etc/systemd/system/fapolicyd.service.d
    ! grep -q -- "${fapolicyd_path}" /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf 2>/dev/null || \
    ! grep -q -- "$FADEBUG" /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf 2>/dev/null && {
      cat > /etc/systemd/system/fapolicyd.service.d/10-debug-deny.conf <<EOF
[Service]
Type=simple
Restart=no
ExecStart=
ExecStart=${fapolicyd_path}fapolicyd $FADEBUG
EOF
      SYSTEMD_RELOAD=1
    }
    restorecon -vR /etc/systemd/system/fapolicyd.service.d
  fi

  [[ -n "$SYSTEMD_RELOAD" ]] && systemctl daemon-reload

  rm -f /run/fapolicyd/fapolicyd.fifo
  __INTERNAL_fapolicyd_start_timestamp=$(date +"%F %T")
  rlServiceStart fapolicyd || let res++

  fapServiceOut -b -f
  tail_pid=$!

  local t=$(($(date +%s) + 120))
  while ! fapServiceOut | grep -q 'Starting to listen for events' \
        && systemctl status fapolicyd > /dev/null; do
    sleep 1
    echo -n . >&2
    [[ $(date +%s) -gt $t ]] && {
      let res++
      break
    }
  done
  disown $tail_pid
  kill $tail_pid
  echo
  systemctl status fapolicyd > /dev/null || let res++
  return $res
}

fapStop() {
  rlServiceStop fapolicyd
}

fapServiceStart() {
  fapStart --no-debug "$@"
}

fapServiceStop() {
  fapStop "$@"
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
  fapTestPackage=( $(find $PWD | grep 'fapTestPackage-' | sort) )
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
