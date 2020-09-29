#!/bin/bash
# try-check-final.sh
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
#   library-prefix = testUser
#   library-version = 7
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 NAME

BeakerLib library testUser

=head1 DESCRIPTION

This library provide s function for maintaining testing users.

=head1 USAGE

To use this functionality you need to import library distribution/testUser and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/testUser)" >> $(METADATA)

=head1 VARIABLES

=over

=item testUser

Array of testing user login names.

=item testUserPasswd

Array of testing users passwords.

=item testUserUID

Array of testing users UIDs.

=item testUserGID

Array of testing users primary GIDs.

=item testUserGroup

Array of testing users primary group names.

=item testUserGIDs

Array of space separated testing users all GIDs.

=item testUserGroups

Array of space separated testing users all group names.

=item testUserGecos

Array of testing users gecos fields.

=item testUserHomeDir

Array of testing users home directories.

=item testUserShell

Array of testing users default shells.

=back

=head1 FUNCTIONS

=cut

echo -n "loading library testUser... "

: <<'=cut'
=pod

=head3 testUserSetup, testUserCleanup

Creates/removes testing user(s).

    rlPhaseStartSetup
        testUserSetup [NUM]
    rlPhaseEnd
    
    rlPhaseStartCleanup
        testUserCleanup
    rlPhaseEnd

=over

=item NUM

Optional number of user to be created. If not specified one user is created.

=back

Returns 0 if success.

=cut


testUserSetup() {
  # parameter dictates how many users should be created, defaults to 1
  local res=0
  local count_created=0
  local count_wanted=${1:-"1"}
  local index=0
  (( $count_wanted < 1 )) && return 1

  while (( $count_created != $count_wanted ));do
    let index++
    local newUser="testuser${index}"
    local newUserPasswd="redhat"
    id "$newUser" &> /dev/null && continue # if user with the name exists, try again

    # create
    useradd -m $newUser >&2 || ((res++))
    echo "$newUserPasswd" | passwd --stdin $newUser || ((res++))

    # save the users array
    testUser+=($newUser)
    testUserPasswd+=($newUserPasswd)
    set | grep "^testUser=" > $__INTERNAL_testUser_users_file
    set | grep "^testUserPasswd=" >> $__INTERNAL_testUser_users_file
    ((count_created++))
  done
  __INTERNAL_testUserRefillInfo || ((res++))

  echo ${res}
  [[ $res -eq 0 ]]
}


__INTERNAL_testUserRefillInfo() {
  local res=0
  local user
  testUserUID=()
  testUserGID=()
  testUserGroup=()
  testUserGIDs=()
  testUserGroups=()
  testUserGecos=()
  testUserHomeDir=()
  testUserShell=()

  for user in ${testUser[@]}; do
    local ent_passwd=$(getent passwd ${user}) || ((res++))
    local users_id="$(id ${user})" || ((res++))
    # testUser is filled during user creation - already present
    # testUserPasswd is saved same way as testUser - already present
    testUserUID+=("$(echo "$ent_passwd" | cut -d ':' -f 3)")
    testUserGID+=("$(echo "$ent_passwd" | cut -d ':' -f 4)")
    testUserGroup+=("$(echo "$users_id" | sed -r 's/.*gid=(\S+).*/\1/;s/[[:digit:]]+\(//g;s/\)//g;s/,/ /g')")
    testUserGIDs+=("$(echo "$users_id" | sed -r 's/.*groups=(\S+).*/\1/;s/\([^\)]+\)//g;s/\)//g;s/,/ /g')")
    testUserGroups+=("$(echo "$users_id" | sed -r 's/.*groups=(\S+).*/\1/;s/[[:digit:]]+\(//g;s/\)//g;s/,/ /g')")
    testUserGecos+=("$(echo "$ent_passwd" | cut -d ':' -f 5)")
    testUserHomeDir+=("$(echo "$ent_passwd" | cut -d ':' -f 6)")
    testUserShell+=("$(echo "$ent_passwd" | cut -d ':' -f 7)")
  done

  echo ${res}
  [[ $res -eq 0 ]]
}


testUserCleanup() {
  local res=0
  for user in ${testUser[@]}; do
    userdel -rf "$user" >&2 || ((res++))
  done
  unset testUser
  __INTERNAL_testUserRefillInfo
  rm -f $__INTERNAL_testUser_users_file >&2 || ((res++))

  echo ${res}
  [[ $res -eq 0 ]]
}



# testUserLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
testUserLibraryLoaded() {
  local res=0
  # necessary init steps
  __INTERNAL_testUser_users_file="$BEAKERLIB_DIR/users"

  # try to fill in users array with previous data
  [[ -f ${__INTERNAL_testUser_users_file} ]] && . ${__INTERNAL_testUser_users_file} >&2
  __INTERNAL_testUserRefillInfo >&2 || ((res++))

  [[ $res -eq 0 ]]
}; # end of testUserLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo "done."

