#!/bin/bash
# try-check-final.sh
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
#   library-prefix = tcf
#   library-version = 14
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_tcf_LIB_VERSION=14
: <<'=cut'
=pod

=head1 NAME

BeakerLib library Try-Check-Final

=head1 DESCRIPTION

This file contains functions which gives user the ability to define blocks of
code where some of the blocks can be automatically skipped if some of preceeding
blocks failed.

ATTENTION
This plugin modifies some beakerlib functions! If you suspect that it breakes
some functionality set the environment variable TCF_NOHACK to nonempty value.

=head1 USAGE

To use this functionality you need to import library distribution/tcf and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/tcf)" >> $(METADATA)

=head1 FUNCTIONS

=cut

echo -n "loading library try-check-final v$__INTERNAL_tcf_LIB_VERSION... "


let __INTERNAL_tcf_DEBUG_LEVEL_LOW=3
let __INTERNAL_tcf_DEBUG_LEVEL_MED=$__INTERNAL_tcf_DEBUG_LEVEL_LOW+1
let __INTERNAL_tcf_DEBUG_LEVEL_HIGH=$__INTERNAL_tcf_DEBUG_LEVEL_LOW+2

# global variables {{{
__INTERNAL_tcf_result=0
__INTERNAL_tcf_result_file="${BEAKERLIB_DIR:-"/var/tmp"}/tcf.result"
echo -n "$__INTERNAL_tcf_result" > "$__INTERNAL_tcf_result_file"
__INTERNAL_tcf_current_level_data=()
__INTERNAL_tcf_current_level_val=0
__INTERNAL_tcf_journal=()
#}}}


# __INTERNAL_tcf_colorize ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_colorize() {
  local a
  case $1 in
    PASS)
      a="${__INTERNAL_tcf_color_green}${1}${__INTERNAL_tcf_color_reset}"
      ;;
    FAIL)
      a="${__INTERNAL_tcf_color_red}${1}${__INTERNAL_tcf_color_reset}"
      ;;
    SKIPPING|WARNING)
      a="${__INTERNAL_tcf_color_yellow}${1}${__INTERNAL_tcf_color_reset}"
      ;;
    BEGIN|INFO)
      a="${__INTERNAL_tcf_color_blue}${1}${__INTERNAL_tcf_color_reset}"
      ;;
    *)
      a=$1
  esac
  echo -n "$a"
}; # end of __INTERNAL_tcf_colorize }}}


# __INTERNAL_tcf_colors_setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_colors_setup(){
  T="$TERM"
  [[ -t 1 ]] || T=""
  [[ -t 2 ]] || T=""
  [[ "$1" == "--force" ]] && T="xterm"
  case $T in
    xterm|screen)
      __INTERNAL_tcf_color_black="\e[0;30m"
      __INTERNAL_tcf_color_dark_gray="\e[1;30m"
      __INTERNAL_tcf_color_blue="\e[0;34m"
      __INTERNAL_tcf_color_light_blue="\e[1;34m"
      __INTERNAL_tcf_color_green="\e[0;32m"
      __INTERNAL_tcf_color_light_green="\e[1;32m"
      __INTERNAL_tcf_color_cyan="\e[0;36m"
      __INTERNAL_tcf_color_light_cyan="\e[1;36m"
      __INTERNAL_tcf_color_red="\e[0;31m"
      __INTERNAL_tcf_color_light_red="\e[1;31m"
      __INTERNAL_tcf_color_purple="\e[0;35m"
      __INTERNAL_tcf_color_light_purple="\e[1;35m"
      __INTERNAL_tcf_color_brown="\e[0;33m"
      __INTERNAL_tcf_color_yellow="\e[1;33m"
      __INTERNAL_tcf_color_light_gray="\e[0;37m"
      __INTERNAL_tcf_color_white="\e[1;37m"
      __INTERNAL_tcf_color_reset="\e[00m"
      ;;
    * )
      __INTERNAL_tcf_color_black=""
      __INTERNAL_tcf_color_dark_gray=""
      __INTERNAL_tcf_color_blue=""
      __INTERNAL_tcf_color_light_blue=""
      __INTERNAL_tcf_color_green=""
      __INTERNAL_tcf_color_light_green=""
      __INTERNAL_tcf_color_cyan=""
      __INTERNAL_tcf_color_light_cyan=""
      __INTERNAL_tcf_color_red=""
      __INTERNAL_tcf_color_light_red=""
      __INTERNAL_tcf_color_purple=""
      __INTERNAL_tcf_color_light_purple=""
      __INTERNAL_tcf_color_brown=""
      __INTERNAL_tcf_color_yellow=""
      __INTERNAL_tcf_color_light_gray=""
      __INTERNAL_tcf_color_white=""
      __INTERNAL_tcf_color_reset=""
      ;;
  esac
}; # end of __INTERNAL_tcf_colors_setup
__INTERNAL_tcf_colors_setup; # }}}


# __INTERNAL_tcf_copy_function ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_copy_function() {
    declare -F $1 > /dev/null || return 1
    eval "$(echo -n "${2}() "; declare -f ${1} | tail -n +2)"
}; # end of __INTERNAL_tcf_copy_function }}}


# __INTERNAL_tcf_addE2R ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_addE2R() {
  __INTERNAL_tcf_copy_function $1 TCF_orig_$1
  eval "${1}() { TCF_orig_${1} \"\$@\"; tcfE2R; }"
}; # end of __INTERNAL_tcf_addE2R }}}


# __INTERNAL_tcf_insertE2R ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_insertE2R() {
  __INTERNAL_tcf_copy_function $1 TCF_orig_$1
  eval "$(echo -n "${1}() "; declare -f ${1} | tail -n +2 | sed -e 's/\(.*__INTERNAL_ConditionalAssert.*\)/\1\ntcfE2R;/')"
}; # end of __INTERNAL_tcf_insertE2R }}}


# __INTERNAL_tcf_get_current_level ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_get_current_level() {
  local l=$__INTERNAL_tcf_current_level_val
  if [[ $1 ]]; then
    l=$(($l+$1))
  fi
  local i
  for i in $(seq 1 $(($l*2)) ); do echo -n " "; done
  return $l
}; # end of __INTERNAL_tcf_get_current_level }}}


# __INTERNAL_tcf_incr_current_level ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_incr_current_level() {
  let __INTERNAL_tcf_current_level_val++
  __INTERNAL_Log_prefix=$(__INTERNAL_tcf_get_current_level)
}; # end of __INTERNAL_tcf_incr_current_level }}}


# __INTERNAL_tcf_decr_current_level ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_decr_current_level() {
  let __INTERNAL_tcf_current_level_val--
  __INTERNAL_Log_prefix=$(__INTERNAL_tcf_get_current_level)
}; # end of __INTERNAL_tcf_decr_current_level }}}


# __INTERNAL_tcf_do_hack ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_do_hack() {
   LogDebug "TCF_NOHACK='$TCF_NOHACK'"
   if [[ -z "$TCF_NOHACK" ]]; then
    tcfChk "Apply TCF beakerlib hacks" && {
      rlLog "  injecting tcf hacks into the beakerlib functions"
      echo -n "patching rlLog"
      local rlL=$(declare -f rlLog | sed -e 's|\] ::|\0${__INTERNAL_Log_prefix}|;s|$3 $1"|${3:+"$3 "}$1"|')
      eval "$rlL"

      echo -n ", rljAddTest"
      __INTERNAL_tcf_copy_function rljAddTest __INTERNAL_tcf_orig_rljAddTest
      true; rljAddTest() {
        local a="${__INTERNAL_Log_prefix}$1"; shift
        [[ "$1" != "FAIL" ]]; tcfE2R
        __INTERNAL_tcf_journal=("${__INTERNAL_tcf_journal[@]}" "$1" "$a")
        __INTERNAL_tcf_orig_rljAddTest "$a" "$@"
      }
      echo -n ", rljAddMessage"
      __INTERNAL_tcf_copy_function rljAddMessage __INTERNAL_tcf_orig_rljAddMessage
      true; rljAddMessage() {
        local a="${__INTERNAL_Log_prefix}$1"; shift
        __INTERNAL_tcf_journal=("${__INTERNAL_tcf_journal[@]}" "$1" "$a")
        __INTERNAL_tcf_orig_rljAddMessage "$a" "$@"
      }
      echo -n ", __INTERNAL_LogAndJournalFail"
      __INTERNAL_tcf_copy_function __INTERNAL_LogAndJournalFail __INTERNAL_tcf_orig___INTERNAL_LogAndJournalFail
      true; __INTERNAL_LogAndJournalFail() {
        tcfNOK
        __INTERNAL_tcf_orig___INTERNAL_LogAndJournalFail "$@"
      }
      echo "."
    tcfFin --no-assert --ignore; }
  else
    Log "skip hacking beakerlib functions"
  fi
}; # end of __INTERNAL_tcf_do_hack }}}


# __INTERNAL_tcf_kill_old_plugin ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_kill_old_plugin() {
    tcfChk "Get rid of the old TCF implementation. removing" && {
      local comma='' i
      for i in Try Chk Fin E2R RES OK NOK NEG TCFcheckFinal TCFreport; do
        echo -n "${comma}rl$i"
        unset -f rl$i
        comma=', '
      done
      echo '.'
    tcfFin --no-assert; }
}; # end of __INTERNAL_tcf_kill_old_plugin }}}


: <<'=cut'
=pod

=head2 Block functions

=cut

# __INTERNAL_tcf_parse_params ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_tcf_parse_params() {
  local GETOPT=$(getopt -q -o if: -l ignore,no-assert,fail-tag: -- "$@")
  eval set -- "$GETOPT"
  echo "local ignore noass title fail_tag"
  echo "[ -z \"\$ignore\" ] && ignore=0"
  echo "[ -z \"\$noass\" ] && noass=0"
  echo "[ -z \"\$fail_tag\" ] && fail_tag='FAIL'"
  while [[ -n "$@" ]]; do
    case $1 in
    --)
      shift; break
      ;;
    --ignore|-i)
      echo "ignore=1"
      echo "noass=1"
      ;;
    --no-assert|-n)
      echo "noass=1"
      ;;
    --fail-tag|-f)
      shift
      echo "fail_tag='$1'"
      ;;
    *)
      echo "unknown option $1"
      return 1
      ;;
    esac
    shift;
  done
  [[ -n "$1" ]] && echo "title=\"${1}\""
  echo "eval set -- \"$(echo "$GETOPT" | sed -e 's/.*-- //')\""
}; # end of __INTERNAL_tcf_parse_params }}}


# tcfTry ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfTry

Starting function of block which will be skipped if an error has been detected
by tcfFin function occurent before.

    tcfTry ["title"] [-i|--ignore] [--no-assert] [--fail-tag TAG] && {
      <some code>
    tcfFin; }

If title is omitted than noting is printed out so no error will be reported (no
Assert is executed) thus at least the very top level tcfTry should have title.

tcfTry and tcfChk blocks are stackable so you can organize them into a hierarchy
structure.

Note that tcfFin has to be used otherwise the overall result will not be
accurate.

=over

=item title

Text which will be displayed and logged at the beginning and the end (in tcfFin
function) of the block.

=item -i, --ignore

Do not propagate the actual result to the higher level result.

=item -n, --no-assert

Do not log error into the journal.

=item -f, --fail-tag TAG

If the result of the block is FAIL, use TAG instead ie. INFO or WARNING.

=back

Returns 1 if and error occured before, otherwise returns 0.

=cut

tcfTry() {
  LogMoreLow -f "begin '$*'"
  local vars=$(__INTERNAL_tcf_parse_params "$@") || { Log "$vars" FAIL; return 1; }
  LogMoreMed -f "vars:\n$vars"
  LogMoreLow -f "evaluating options start"
  eval "$vars"
  LogMoreLow -f "evaluating options end"
  local incr=
  local pp="SKIPPING"
  tcfRES; # to set __INTERNAL_tcf_result
  LogMoreLow -f "result was $__INTERNAL_tcf_result"
  if [[ $__INTERNAL_tcf_result -eq 0 ]]; then
    __INTERNAL_tcf_current_level_data=("$__INTERNAL_tcf_result" "$vars" "${__INTERNAL_tcf_current_level_data[@]}")
    pp="BEGIN"
    incr=1
  fi
  if [[ -n "$title" ]]; then
    Log "$title" "$pp"
    [[ -n "$incr" ]] && {
      LogMoreLow -f "increment indentation level"
      __INTERNAL_tcf_incr_current_level
    }
  fi
  LogMoreLow -f "end"
  return $__INTERNAL_tcf_result
}; # end of tcfTry }}}


# tcfChk ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfChk

Starting function of block which will be always executed.

    tcfChk ["title"] [-i|--ignore] [--no-assert] [--fail-tag TAG] && {
      <some code>
    tcfFin; }

If title is omitted than noting is printed out so no error will be reported (no
Assert is executed) thus at least the very top level tcfChk should have title.

tcfTry and tcfChk blocks are stackable so you can organize them into a hierarchy
structure.

Note that tcfFin has to be used otherwise the overall result will not be
accurate.

For details about arguments see tcfTry.

Returns 0.

=cut

tcfChk() {
  LogMoreLow -f "begin '$*'"
  tcfRES; # to set __INTERNAL_tcf_result
  local res=$__INTERNAL_tcf_result
  tcfRES 0
  tcfTry "$@"
  __INTERNAL_tcf_current_level_data[0]=$res
  LogMoreLow -f "end"
  return $__INTERNAL_tcf_result
}; # end of tcfChk }}}


# tcfFin ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfFin

Ending function of block. It does some evaluation of previous local and global
results and puts it into the global result.

    tcfTry ["title"] && {
      <some code>
    tcfFin [-i|--ignore] [--no-assert] [--fail-tag TAG]; }

Local result is actualy exit code of the last command int the body.

Global result is an internal varibale hodning previous local results.
Respectively last error or 0.

For details about arguments see tcfTry.

Returns local result of the preceeding block.

=cut

tcfFin() {
  local RES=$?
  LogMoreLow -f "begin '$*'"
  LogMoreMed -f "previous exit code was '$RES'"
  local vars=$(__INTERNAL_tcf_parse_params "$@") || { Log "$vars" FAIL; return 1; }
  LogMoreMed -f "vars:\n$vars"
  LogMoreLow -f "evaluating options start"
  eval "$vars"
  LogMoreLow -f "evaluating options end"
  tcfRES; # to set __INTERNAL_tcf_result
  [[ $RES -ne 0 ]] && tcfRES $RES
  RES=$__INTERNAL_tcf_result
  LogMoreMed -f "overall result is '$RES'"
  LogMoreMed -f "data:\n${__INTERNAL_tcf_current_level_data[1]}"
  LogMoreLow -f "evaluating data start"
  eval "${__INTERNAL_tcf_current_level_data[1]}"
  LogMoreLow -f "evaluating data end"
  if [[ -n "$title" ]]; then
    __INTERNAL_tcf_decr_current_level
    if [[ $ignore -eq 1 ]]; then
      RES=0
      [[ $__INTERNAL_tcf_result -ne 0 ]] && title="$title - ignored"
    fi
    if [[ $noass -eq 0 ]]; then
      tcfAssert0 "$title" $__INTERNAL_tcf_result "$fail_tag"
    else
      if [[ $__INTERNAL_tcf_result -eq 0 ]]; then
        local pp="PASS"
        LogInfo "$title - $pp"
      else
        local pp="${fail_tag:-FAIL}"
        LogWarn "$title - $pp"
      fi
    fi
  fi
  if [[ $__INTERNAL_tcf_result -eq 0 || $ignore -eq 1 ]]; then
    tcfRES ${__INTERNAL_tcf_current_level_data[0]}
  fi
  local i
  for i in 0 1; do unset __INTERNAL_tcf_current_level_data[$i]; done
  __INTERNAL_tcf_current_level_data=("${__INTERNAL_tcf_current_level_data[@]}")
  LogMoreLow -f "end"
  return $RES
}; # end of tcfFin }}}

: <<'=cut'
=pod

=head2 Functions for manipulation with the results

=cut


# tcfRES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfRES

Sets and return the global result.

    tcfRES [-p|--print] [number]

=over

=item -p --print

Also print the result value.

=item number

If present the global result is set to this value.

=back

Returns global result.

=cut

tcfRES() {
  local p=0
  while [[ -n "$1" ]]; do
    case $1 in
    --print|-p)
      p=1
      ;;
    *)
      break
      ;;
    esac
    shift
  done
  if [[ -n "$1" ]]; then
    __INTERNAL_tcf_result=$1
    echo -n "$__INTERNAL_tcf_result" > "$__INTERNAL_tcf_result_file"
  else
    __INTERNAL_tcf_result="$(cat "$__INTERNAL_tcf_result_file")"
  fi
  [[ $p -eq 1 ]] && echo $__INTERNAL_tcf_result
  return $__INTERNAL_tcf_result
}; # end of tcfRES }}}


# tcfOK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfOK

Sets the global result to 0.

    tcfOK

Returns global result.

=cut

tcfOK() {
  tcfRES 0
}; # end of tcfOK }}}


# tcfNOK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfNOK

Sets the global result to 1 or given number.

    tcfNOK [number]

=over

=item number

If present the global result is set to this value.

=back

Returns global result.

=cut

tcfNOK() {
  if [[ -n "$1" ]]; then
    [[ $1 -eq 0 ]] && echo "You have requested result '0'. You should use tcfOK instead."
    tcfRES $1
  else
    tcfRES 1
  fi
}; # end of tcfNOK }}}


# tcfE2R ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfE2R

Converts exit code of previous command to local result if the exit code is not 0
(zero).

    <some command>
    tcfE2R [number]

=over

=item number

If present use it instead of exit code.

=back

Returns original exit code or given number.

=cut

tcfE2R() {
  local res=$?
  [[ -n "$1" ]] && res=$1
  [[ $res -ne 0 ]] && tcfRES $res
  return $res
}; # end of tcfE2R }}}


: <<'=cut'
=pod

=head2 Functions for manipulation with the exit codes

=cut


# tcfNEG ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfNEG

Negates exit code of previous command.

    <some command>
    tcfNEG

Returns 1 if original exit code was 0, otherwise returns 0.

=cut

tcfNEG() {
  [[ $? -eq 0 ]] && return 1 || return 0
}; # end of tcfNEG }}}


# tcfRun ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfRun

Simmilar to rlRun but it also annouces the beginnign of the command.

    tcfRun [--fail-tag|-f TAG] command [exp_result [title]]
    
Moreover if 'command not found' appears on STDERR it should produce WARNING.
    
=over

=item command

Command to execute.

=item exp_result

Specification of expect resutl.

It can be a list of values or intervals or * for any result. Also negation (!) can be used.

 Example:

    <=2,7,10-12,>252,!254 means following values 0,1,2,7,10,11,12,253,255

=item title

Text which will be displayed and logged at the beginning and the end of command execution.

=item --fail-tag | -f

If the command fails use TAG instead of FAIL.

=back

Returns exit code of the executed command.

=cut

tcfRun() {
  LogMore_ -f "begin      $*"
  optsBegin
  optsAdd 'fail-tag|f' --mandatory
  optsAdd 'timeout' --optional 'timeout="${1:-10}"'
  optsAdd 'kill-timeout|kt' --mandatory --default 5
  optsAdd 'signal' --mandatory --default TERM
  optsAdd 'check-code' --mandatory --default 'kill -0 $cmdpid >&/dev/null'
  optsAdd 'kill-code' --mandatory --default '/bin/kill -$signal -- $cmdpid'
  optsAdd 'allow-skip|as' --flag
  optsAdd 'no-assert|n' --flag
  optsDone; eval "${optsCode}"
  LogMore_ -f "after opts $*"
  [[ -z "$allowskip" ]] && tcfChk
    local orig_expecode="${2:-0}"
    local expecode="$orig_expecode"
    [[ "$expecode" == "*" ]] && expecode="0-255"
    local command="$1"
    local comment="Running command '$command'"
    [[ -n "$3" ]] && comment="$3"
    [[ -n "$expecode" ]] && {
      expecode=$(echo "$expecode" | tr ',-' '\n ' | sed -e 's/^!=/!/;s/^=//;s/^<=\(.\+\)$/0 \1/;s/^>=\(.\+\)$/\1 255/;s/^<\(.\+\)$/0 \$(( \1 - 1 ))/;s/^>\(.\+\)$/\$(( \1 + 1 )) 255/' | while read line; do [[ "$line" =~ ^[^\ ]+$ ]] && echo "$line" || eval seq $line; done; )
      tcfE2R
      LogMoreLow -f "orig_expecode='$orig_expecode'" 
      LogMoreLow -f "expecode='$expecode'" 
    }
    tcfTry ${noassert:+--no-assert} "$comment" && {
      local errout=$(mktemp)
      LogMoreLow -f "executing '$command'"
      if [[ "$optsPresent" =~ $(echo "\<timeout\>") ]]; then
        LogDebug -f "using watchdog feature"
        local ec="$(mktemp)"
        eval "$command; echo $? > $ec 2> >(tee $errout)" &
        local cmdpid=$!
        local time_start=$(date +%s)
        local timeout_t=$(( $time_start + $timeout ))
        while true; do
          if ! eval "$checkcode"; then
             Log "command finished in $(($(date +%s) - $time_start )) seconds"
             local res="$(cat $ec)"
             break
          elif [[ $(date +%s) -ge $timeout_t ]]; then
            echo
            Log "command is still running, sending $signal signal"
            eval "$killcode"
            tcfNOK 255
            echo 255 > $ec
            let timeout_t+=killtimeout
            signal=KILL
          fi
          sleep 0.1
        done
        rm -f $ec
      else
        eval "$command" 2> >(tee $errout)
        local res=$?
      fi
      LogMoreLow -f "got '$res'" 
      local resmatch=$(echo "$expecode" | grep "^\!\?${res}$")
      LogMoreLow -f "resmatch='$resmatch'" 
      [[ -n "$resmatch" && ! "$resmatch" =~ '!' ]]
      if tcfE2R; then
        ! grep -iq "command not found" $errout || { failtag='WARNING'; tcfNOK; }
      else
        Log "Expected result was '$orig_expecode', got '$res'!"
      fi
    tcfFin ${failtag:+--fail-tag "$failtag"}; }
    rm -f $errout
  [[ -z "$allowskip" ]] && tcfFin
  LogMore_ -f "end $*"
  return $res
}; # end of tcfRun }}}


: <<'=cut'
=pod

=head2 Functions for logging

=cut


# tcfAssert0 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
tcfAssert0() {
  LogMoreLow -f "begin '$*'"
  local RES="${3:-FAIL}"
  [[ $2 -eq 0 ]] && RES='PASS'
  Log "$1" $RES
  LogMoreLow -f "end"
}; # end of tcfAssert0 }}}


# tcfCheckFinal ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 tcfCheckFinal

Check that all tcfTry / tcfChk functions have been close by tcfFin.

    tcfCheckFinal

=cut

tcfCheckFinal() {
  tcfAssert0 "Check that TCF block cache is empty" ${#__INTERNAL_tcf_current_level_data[@]}
  tcfAssert0 "Check that TCF current level is 0" $__INTERNAL_tcf_current_level_val
}; # end of tcfCheckFinal }}}


echo "done."

: <<'=cut'
=pod

=head2 Self check functions

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# tcfSelfCheck {{{
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 tcfSelfCheck

Does some basic functionality tests.

    tcfSelfCheck

The function is called also by the following command:

    ./lib.sh selfcheck

=cut


tcfSelfCheck() {
  tcfChk "check 1" &&{
    tcfTry "try 1.1 - true" &&{
      true
    tcfFin;}
    tcfTry "try 1.2 - false" &&{
      false
    tcfFin;}
    tcfTry "try 1.3 - true" &&{
      true
    tcfFin;}
  tcfFin;}
  tcfChk "check 2" &&{
    tcfTry "try 2.1 - true" &&{
      true
    tcfFin;}
    tcfTry "try 2.2 - true - ignore" &&{
      true
    tcfFin -i;}
    tcfTry "try 2.3 - true" &&{
      true
    tcfFin;}
  tcfFin;}
  tcfChk "check 3" &&{
    tcfTry "try 3.1 - true" &&{
      true
    tcfFin;}
    tcfTry "try 3.2 - false - ignore" &&{
      false
    tcfFin -i;}
    tcfTry "try 3.3 - true" &&{
      true
    tcfFin;}
  tcfFin;}
  tcfCheckFinal
  tcfAssert0 "Overall result" $(tcfRES -p)
  LogReport
}
if [[ "$1" == "selfcheck" ]]; then
  tcfSelfCheck
fi; # end of tcfSelfCheck }}}


# tcfLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
tcfLibraryLoaded() {
  rlImport distribution/Log
  declare -F rlDie > /dev/null && {
    #rlJournalStart
    #rlPhaseStartSetup "TCF"
    echo -e "\nrunning inside the beakerlib - using rlAssert0"
    true; tcfAssert0() {
      local text="$1"
      [[ "$3" != "FAIL" && "$3" != "PASS" ]] && text="$text - $3"
      __INTERNAL_ConditionalAssert "$text" "$2"
    }
    __INTERNAL_tcf_do_hack
    #rlPhaseEnd
    #rlJournalEnd
  };
  if declare -F rlE2R >& /dev/null; then
    __INTERNAL_tcf_kill_old_plugin
  fi
  true
}; # end of tcfLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut


