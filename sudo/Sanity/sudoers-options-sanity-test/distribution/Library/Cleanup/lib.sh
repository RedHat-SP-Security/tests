#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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
#   library-prefix = Cleanup
#   library-version = 9
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_Cleanup_LIB_VERSION=9
: <<'=cut'
=pod

=head1 NAME

BeakerLib library Cleanup

=head1 DESCRIPTION

This file contains functions which provides cleanup stack functionality.

=head1 USAGE

To use this functionality you need to import library distribution/Cleanup and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/Cleanup)" >> $(METADATA)

B<Code example>

	rlJournalStart
	  rlPhaseStartSetup
	    rlImport 'distribution/Cleanup'
	    tmp=$(mktemp)
	    CleanupRegister "
	      rlLog 'Removing data'
	      rlRun \"rm -f ${tmp}\"
	    "
	    rlLog 'Creating some data'
	    rlRun "echo 'asdfalkjh' > $tmp"

	    CleanupRegister "
	      rlLog 'just something to demonstrate unregistering'
	    "
	    ID1=$CleanupRegisterID
	    CleanupUnregister $ID1

	    CleanupRegister "
	      rlLog 'just something to demonstrate partial cleanup'
	    "
	    ID2=$CleanupRegisterID
	    CleanupRegister "rlLog 'cleanup some more things'"
	    # cleanup everything upto ID2
	    CleanupDo $ID2

	    CleanupRegister --mark "
	      rlLog 'yet another something to demonstrate partial cleanup using internal ID saving'
	    "
	    CleanupRegister "rlLog 'cleanup some more things'"
	    # cleanup everything upto last mark
	    CleanupDo --mark
	  rlPhaseEnd

	  rlPhaseStartCleanup
	    CleanupDo
	  rlPhaseEnd

	  rlJournalPrintText
	rlJournalEnd

=head1 FUNCTIONS

=cut

echo -n "loading library Cleanup v$__INTERNAL_Cleanup_LIB_VERSION... "

__INTERNAL_Cleanup_stack_file="$BEAKERLIB_DIR/Cleanup_stack"
touch "$__INTERNAL_Cleanup_stack_file"
chmod ug+rw "$__INTERNAL_Cleanup_stack_file"

# CleanupRegister ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# CleanupRegister [--mark] CLEANUP_CODE
#   --mark  - also mark this position
CleanupRegister() {
  local mark=0
  [[ "$1" == "--mark" ]] && {
    mark=1
    shift
  }
  if ! CleanupGetStack; then
    rlLogError "cannot continue, could not get cleanup stack"
    return 1
  fi
  CleanupRegisterID="${RANDOM}$(date +"%s%N")"
  echo -n "Registering cleanup ID=$CleanupRegisterID" >&2
  if [[ $mark -eq 1 ]]; then
    __INTERNAL_CleanupMark=( "$CleanupRegisterID" "${__INTERNAL_CleanupMark[@]}" )
    echo -n " with mark" >&2
  fi
  echo " '$1'" >&2
  rlLogDebug "prepending '$1'"
  local ID_tag="# ID='$CleanupRegisterID'"
  __INTERNAL_Cleanup_stack="$ID_tag
$1
$ID_tag
$__INTERNAL_Cleanup_stack"
  if ! CleanupSetStack "$__INTERNAL_Cleanup_stack"; then
    rlLogError "an error occured while registering the cleanup '$1'"
    return 1
  fi
  return 0
}; # end of CleanupRegister }}}


# __INTERNAL_Cleanup_get_stack_part ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# 1: ID
#    -ID    - everything upto the ID
# 2: ''     - return ID only
#    'rest' - return exact oposit
__INTERNAL_Cleanup_get_stack_part() {
  rlLogDebug "__INTERNAL_Cleanup_get_stack_part(): $* begin"
  local ID="$1"
  local n='1 0 1'
  local stack=''
  [[ "${ID:0:1}" == "-" ]] && {
    ID="${ID:1}"
    n='0 0 1'
  }
  [[ "$2" == "rest" ]] && {
    n="$(echo "${n//0/2}")"
    n="$(echo "${n//1/0}")"
    n="$(echo "${n//2/1}")"
  }
  n=($n)
  [[ -n "$DEBUG" ]] && rlLogDebug "$(set | grep ^n=)"
  local ID_tag="# ID='$ID'"
  while IFS= read -r line; do

    [[ "$line" == "$ID_tag" ]] && {
      n=( "${n[@]:1}" )
      continue
    }
    if [[ $n -eq 0 ]]; then
      stack="$stack
$line"
    fi
  done < <(echo "$__INTERNAL_Cleanup_stack")
  rlLogDebug "__INTERNAL_Cleanup_get_stack_part(): cleanup stack part is '${stack:1}'"
  echo "${stack:1}"
  rlLogDebug "__INTERNAL_Cleanup_get_stack_part(): $* end"
}; # end of __INTERNAL_Cleanup_get_stack_part }}}

# CleanupUnregister ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupUnregister() {
  local ID="$1"
  rlLog "Unregistering cleanup ID='$ID'"
  if ! CleanupGetStack; then
    rlLogError "cannot continue, could not get cleanup stack"
    return 1
  fi
  rlLogDebug "removing ID='$ID'"
  if ! CleanupSetStack "$(__INTERNAL_Cleanup_get_stack_part "$ID" 'rest')"; then
    rlLogError "an error occured while registering the cleanup '$1'"
    return 1
  fi
  return 0
}; # end of CleanupUnregister }}}


# CleanupMark ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_CleanupMark=()
CleanupMark() {
  echo -n "Setting cleanup mark" >&2
  CleanupRegister --mark '' 2>/dev/null
  local res=$?
  echo " ID='$CleanupRegisterID'" >&2
  return $res
}; # end of CleanupMark }}}


# CleanupDo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# 1: ''   - cleanup all
#    ID   - cleanup ID only
#    -ID  - cleanup all upto ID, including
#    mark - cleanup all unto last mark, including
CleanupDo() {
  local ID="$1"
  if ! CleanupGetStack; then
    rlLogError "cannot continue, could not get cleanup stack"
    return 1
  fi
  local res tmp newstack=''
  tmp="$(mktemp)"
  if [[ "$ID" == "mark" || "$ID" == "--mark" ]]; then
    echo "execute cleanup upto mark='$__INTERNAL_CleanupMark'" >&2
    __INTERNAL_Cleanup_get_stack_part "-$__INTERNAL_CleanupMark" | grep -v "^# ID='" > "$tmp"
    newstack="$(__INTERNAL_Cleanup_get_stack_part "-$__INTERNAL_CleanupMark" 'rest')"
    __INTERNAL_CleanupMark=("${__INTERNAL_CleanupMark[@]:1}")
  elif [[ -n "$ID" ]]; then
    echo "execute cleanup for ID='$ID'" >&2
    __INTERNAL_Cleanup_get_stack_part "$ID" | grep -v "^# ID='" > "$tmp"
    newstack="$(__INTERNAL_Cleanup_get_stack_part "$ID" 'rest')"
  else
    CleanupTrapUnhook
    trap "echo 'temporarily blocking ctrl+c until cleanup is done' >&2" SIGINT
    cat "$__INTERNAL_Cleanup_stack_file" | grep -v "^# ID='" > "$tmp"
    echo "execute whole cleanup stack" >&2
  fi
  . "$tmp"
  res=$?
  [[ $res -ne 0 ]] && {
    echo "cleanup code:" >&2
    cat -n "$tmp" >&2
  }
  rm -f "$tmp"
  echo "cleanup execution done" >&2
  if [[ -z "$ID" ]]; then 
    trap - SIGINT
  fi
  if ! CleanupSetStack "$newstack"; then
    rlLogError "an error occured while cleaning the stack"
    return 1
  fi
  return $res
}; # end of CleanupDo }}}


# CleanupGetStack ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupGetStack() {
  rlLogDebug "getting cleanup stack"
  if [[ -r "$__INTERNAL_Cleanup_stack_file" ]]; then
    if __INTERNAL_Cleanup_stack="$(cat "$__INTERNAL_Cleanup_stack_file")"; then
      rlLogDebug "cleanup stack is '$__INTERNAL_Cleanup_stack'"
      return 0
    fi
  fi
  rlLogError "could not load cleanup stack"
  return 1
}; # end of CleanupGetStack }}}


# CleanupSetStack ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupSetStack() {
  rlLogDebug "setting cleanup stack to '$1'"
  __INTERNAL_Cleanup_stack="$1"
  if echo "$__INTERNAL_Cleanup_stack" > "$__INTERNAL_Cleanup_stack_file"; then
    rlLogDebug "cleanup stack is now '$__INTERNAL_Cleanup_stack'"
    return 0
  fi
  rlLogError "could not set cleanup stack"
  return 1
}; # end of CleanupSetStack }}}


__INTERNAL_Cleanup_signals=''
__INTERNAL_Cleanup_trap_code='rlJournalStart; rlPhaseStartCleanup; CleanupDo; rlPhaseEnd; rlJournalPrintText; rlJournalEnd; exit'
# CleanupTrapHook ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupTrapHook() {
  rlLog "register cleanup trap"
  __INTERNAL_Cleanup_signals="${1:-"SIGHUP SIGINT SIGTERM EXIT"}"
  eval "trap \"${__INTERNAL_Cleanup_trap_code}\" $__INTERNAL_Cleanup_signals"
}; # end of CleanupTrapHook }}}


# CleanupTrapUnhook ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupTrapUnhook() {
  if [[ -n "$__INTERNAL_Cleanup_signals" ]]; then
    rlLog "unregister cleanup trap"
    eval trap - $__INTERNAL_Cleanup_signals
    __INTERNAL_Cleanup_signals=''
  fi
}; # end of CleanupTrapUnhook }}}


# CleanupLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
CleanupLibraryLoaded() {
  CleanupTrapHook
}; # end of CleanupLibraryLoaded }}}


echo "done."

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

