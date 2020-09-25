#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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
#   library-prefix = Log
#   library-version = 11
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_Log_LIB_VERSION=11
: <<'=cut'
=pod

=head1 NAME

BeakerLib library Log

=head1 DESCRIPTION

This library provide logging capability which does not rely on beakerlib so it
can be used standalone.

If it is used within beakerlib it automatically bypass all messages to the
beakerlib.

Also this library provide journaling feature so the summary can be printed out
at the end.

=head1 USAGE

To use this functionality you need to import library distribution/Log and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/Log)" >> $(METADATA)

=head1 FUNCTIONS

=cut

echo -n "loading library Log v$__INTERNAL_Log_LIB_VERSION... "


__INTERNAL_Log_prefix=''
__INTERNAL_Log_prefix2=''
__INTERNAL_Log_postfix=''
__INTERNAL_Log_default_level=3
__INTERNAL_Log_level=$__INTERNAL_Log_default_level
LogSetDebugLevel() {
  if [[ -n "$1" ]]; then 
    if [[ "$1" =~ ^[0-9]+$ ]]; then 
      let __INTERNAL_Log_level=$__INTERNAL_Log_default_level+$1;
    else
      __INTERNAL_Log_level=255
    fi
  else
    __INTERNAL_Log_level=$__INTERNAL_Log_default_level
  fi
}
LogSetDebugLevel "$DEBUG"
let __INTERNAL_Log_level_LOG=0
let __INTERNAL_Log_level_FATAL=0
let __INTERNAL_Log_level_ERROR=1
let __INTERNAL_Log_level_WARNING=2
let __INTERNAL_Log_level_INFO=3
let __INTERNAL_Log_level_DEBUG=4
let __INTERNAL_Log_level_MORE=5
let __INTERNAL_Log_level_MORE_=$__INTERNAL_Log_level_MORE+1
let __INTERNAL_Log_level_MORE__=$__INTERNAL_Log_level_MORE_+1
let __INTERNAL_Log_level_MORE___=$__INTERNAL_Log_level_MORE__+1

# Log ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
Log() {
  LogMore___ -f "begin '$*'"
  local pri=$2 message="${__INTERNAL_Log_prefix}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
  if [[ -n "$pri" ]]; then
    LogPrintMessage "$pri" "$message"
    LogjAddMessage "$pri" "$message"
  else
    LogPrintMessage "$(date +%H:%M:%S)" "$message"
    LogjAddMessage "INFO" "$message"
  fi
  LogMore___ -f "end"
  return 0
}; # end of Log }}}


__INTERNAL_Log_condition() {
  cat <<EOF
  __INTERNAL_Log_level_do=$1
  if [[ \$__INTERNAL_Log_level -ge \$__INTERNAL_Log_level_do ]]; then
    [[ -z "$2" ]] && return 1
  else
    return 0
  fi
EOF
}


# LogInfo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogInfo() {
  __INTERNAL_LogPrio='INFO'
  eval "$(__INTERNAL_Log_condition \$__INTERNAL_Log_level_INFO  \"\$1\")"
  LogMore___ -f "begin '$*'"
  __INTERNAL_LogPrio='INFO'
  Log "$1" $__INTERNAL_LogPrio
  LogMore___ -f "end"
  return 0
}; # end of LogInfo }}}


# LogWarn ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogWarn() {
  __INTERNAL_LogPrio='WARNING'
  eval "$(__INTERNAL_Log_condition \$__INTERNAL_Log_level_WARNING  \"\$1\")"
  LogMore___ -f "begin '$*'"
  __INTERNAL_LogPrio='WARNING'
  Log "$1" $__INTERNAL_LogPrio
  LogMore___ -f "end"
  return 0
}; # end of LogWarn }}}


# LogWarning ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogWarning() {
  __INTERNAL_LogPrio='WARNING'
  eval "$(__INTERNAL_Log_condition \$__INTERNAL_Log_level_WARNING  \"\$1\")"
  LogMore___ -f "begin '$*'"
  __INTERNAL_LogPrio='WARNING'
  Log "$1" $__INTERNAL_LogPrio
  LogMore___ -f "end"
  return 0
}; # end of LogWarning }}}


# LogError ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogError() {
  __INTERNAL_LogPrio='ERROR'
  eval "$(__INTERNAL_Log_condition \$__INTERNAL_Log_level_ERROR  \"\$1\")"
  LogMore___ -f "begin '$*'"
  __INTERNAL_LogPrio='ERROR'
  Log "$1" $__INTERNAL_LogPrio
  LogMore___ -f "end"
  return 0
}; # end of LogError }}}


# LogFatal ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogFatal() {
  __INTERNAL_LogPrio='FATAL'
  eval "$(__INTERNAL_Log_condition \$__INTERNAL_Log_level_FATAL  \"\$1\")"
  LogMore___ -f "begin '$*'"
  __INTERNAL_LogPrio='FATAL'
  Log "$1" $__INTERNAL_LogPrio
  exit 255
  LogMore___ -f "end"
}; # end of LogFatal }}}


# LogPASS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogPASS() {
  LogMore___ -f "begin '$*'"
  Log "$1" PASS
  LogMore___ -f "end"
  return 0
}
LogPass() {
  LogPASS "$@"
}; # end of LogPASS }}}


# LogFAIL ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogFAIL() {
  LogMore___ -f "begin '$*'"
  Log "$1" FAIL
  LogMore___ -f "end"
  return 0
}
LogFail() {
  LogFAIL "$@"
}; # end of LogFAIL }}}


# LogDo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogDo() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    local tmp=${BASH_REMATCH[1]:-1}
    pref="${FUNCNAME[$tmp]}(): "
  }
  LogPrintMessage "$__INTERNAL_LogPrio" "${__INTERNAL_Log_prefix}${pref}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
  return 0
}; # end of LogDo }}}


# LogDebug ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogDebug() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  __INTERNAL_Log_level_do=${2:-$__INTERNAL_Log_level_DEBUG}
  __INTERNAL_LogPrio='DEBUG'
  [[ $__INTERNAL_Log_level_do -ge $__INTERNAL_Log_level_MORE ]] && __INTERNAL_LogPrio="${__INTERNAL_LogPrio}:$(($__INTERNAL_Log_level_do-$__INTERNAL_Log_level_DEBUG+1))"
  eval "$(__INTERNAL_Log_condition \${2:-\$__INTERNAL_Log_level_DEBUG}  \"\$1\")"
  LogDo $pref "$1"
  return 0
}; # end of LogDebug }}}


# LogMore ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogMore() {
  # log if DEBUG does not containg a number
  # or the number is greater or equal to 2
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" ${2:-$__INTERNAL_Log_level_MORE}
}; # end of LogMore }}}


# LogMore_ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogMore_() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE_
}; # end of LogMore_ }}}


# LogMore__ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogMore__() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE__
}; # end of LogMore__ }}}


# LogMore___ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogMore___() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE___
}; # end of LogMore___ }}}


# LogMoreLow ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_LogMoreLow_Obs=''
LogMoreLow() {
  [[ -z "$__INTERNAL_LogMoreLow_Obs" ]] && {
    LogMore_ -f "LogMoreLow is obsoleted by LogMore_"
    __INTERNAL_LogMoreLow_Obs=1
  }
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE_
}; # end of LogMoreLow }}}


# LogMoreMed ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_LogMoreMed_Obs=''
LogMoreMed() {
  [[ -z "$__INTERNAL_LogMoreMed_Obs" ]] && {
    LogMore__ -f "LogMoreMed is obsoleted by LogMore__"
    __INTERNAL_LogMoreMed_Obs=1
  }
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE__
}; # end of LogMoreMed }}}


# LogMoreHigh ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_LogMoreHigh_Obs=''
LogMoreHigh() {
  [[ -z "$__INTERNAL_LogMoreHigh_Obs" ]] && {
    LogMore___ -f "LogMoreHigh is obsoleted by LogMore___"
    __INTERNAL_LogMoreHigh_Obs=1
  }
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogDebug $pref "$1" $__INTERNAL_Log_level_MORE___
}; # end of LogMoreHigh }}}


# LogjAddMessage ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogjAddMessage() {
  LogMore__ -f "begin '$*'"
  __INTERNAL_Log_journal=("${__INTERNAL_Log_journal[@]}" "$1" "$2")
  LogMore__ -f "end"
  true;
}; # end of LogjAddMessage }}}

# __INTERNAL_LogCenterText ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_LogCenterText() {
  local spaces='                                                                              '
  # strip colors
  local log_pri_strip=$(echo -en "$1" | sed -r "s:\x1B\[[0-9;]*[mK]::g")
  local log_pri_strip_count=${#log_pri_strip}
  local left_spaces=$(( ($2 - $log_pri_strip_count) / 2 ))
  local right_spaces=$(( $2 - $log_pri_strip_count - $left_spaces ))
  echo -en "${spaces:0:$left_spaces}${1}${spaces:0:$right_spaces}"
}; # end of __INTERNAL_LogCenterText }}}


# LogPrintMessage ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogPrintMessage() {
  echo -e ":: [$(__INTERNAL_LogCenterText "$1" 10)] :: $2" >&2
  return 0
}; # end of LogPrintMessage }}}


# LogReport ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
: <<'=cut'
=pod

=head3 LogReport

Prints final report similar to breakerlib's rlJournalPrintText. This is useful
mainly if you use TCF without beakerlib.

    LogReport

=cut
#'

LogReport() {
  echo -e "\n ====== Summary report begin ======"
  local a p l i
  for i in $(seq 0 2 $((${#__INTERNAL_Log_journal[@]}-1)) ); do
    LogPrintMessage "${__INTERNAL_Log_journal[$i]}" "${__INTERNAL_Log_journal[$((++i))]}"
  done
  echo " ======= Summary report end ======="
  __INTERNAL_Log_journal=()
}; # end of LogReport }}}


# LogFile ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogFile() {
  LogMore__ -f "begin '$*'"
  local prio=''
  [[ $# -ge 3 ]] && {
    optsBegin
    optsAdd 'prio|tag|p|t' --mandatory
    optsDone; eval "${optsCode}"
  }
  cat $1 | while IFS= read line; do
    Log "$line" "${prio:-$2}"
  done
  LogMore__ -f "end"
}; #}}}


# LogText ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogText() {
  LogMore__ -f "begin '$*'"
  local prio=''
  [[ $# -ge 3 ]] && {
    optsBegin
    optsAdd 'prio|tag|p|t' --mandatory
    optsDone; eval "${optsCode}"
  }
  {
    if [[ "$1" == "-" ]]; then
      cat -
    else
      echo "$1"
    fi
  } | while IFS= read line; do
    Log "$line" "${prio:-$2}"
  done
  LogMore__ -f "end"
}; #}}}


# LogStrippedDiff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogStrippedDiff() {
  LogMore__ -f "begin '$*'"
  local prio=''
  [[ $# -ge 3 ]] && {
    optsBegin
    optsAdd 'prio|tag|p|t' --mandatory
    optsDone; eval "${optsCode}"
  }
  {
    if [[ -n "$2" ]]; then
      diff -U0 "$1" "$2"
    else
      cat $1
    fi
  } | grep -v -e '^@@ ' -e '^--- ' -e '^+++ ' | while IFS= read line; do
    Log "$line" "$prio"
  done
  LogMore__ -f "end"
}; #}}}


# LogRun ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogRun() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}+1))"
  }
  LogMore
  local dolog=$?
  [[ $dolog -eq 0 ]] || {
    local param params blacklist="[[:space:]]|>|<|\|"
    [[ "${#@}" -eq 1 ]] && params="$1" || {
      for param in "$@"; do
        if [[ "$param" =~ $blacklist ]]; then
          params="$params \"${param//\"/\\\"}\""
        else
          params="$params $param"
        fi
      done
      params="${params:1}"
    }
    LogDo $pref "executing >>>>> ${params} <<<<<"
  }
  eval "$@"
  ret=$?
  [[ $dolog -eq 0 ]] || LogMore $pref "execution >>>>> ${params} <<<<< returned '$ret'"
  return $ret
}; # end of LogRun }}}


# LogDebugNext ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogDebugNext() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}))"
  }
  LogDebug '' ${1:-$__INTERNAL_Log_level_DEBUG} || {
    __INTERNAL_Log_DEBUGING=0
    trap "
      __INTERNAL_Log_DEBUGING_res=\$?
      let __INTERNAL_Log_DEBUGING++
      if [[ \$__INTERNAL_Log_DEBUGING -eq 1 ]]; then
        __INTERNAL_Log_DEBUGING_cmd=\"\$BASH_COMMAND\"
        LogDebug $pref \"executing >>>>> \$__INTERNAL_Log_DEBUGING_cmd <<<<<\" ${1:-$__INTERNAL_Log_level_DEBUG}
      else
        trap - DEBUG
        LogDebug $pref \"execution >>>>> \$__INTERNAL_Log_DEBUGING_cmd <<<<< returned \$__INTERNAL_Log_DEBUGING_res\" ${1:-$__INTERNAL_Log_level_DEBUG}
      fi" DEBUG 
  }
}; # end of LogDebugNext }}}


# LogMoreNext ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogMoreNext() {
  LogMore || {
    local pref=''
    [[ "$1" =~ ^-f([0-9]*) ]] && {
      shift
      pref="-f$((${BASH_REMATCH[1]:-1}))"
    }
    LogDebugNext $pref  ${1:-$__INTERNAL_Log_level_MORE}
  }
}; # end of LogMoreNext }}}
LogNext() {
  LogMoreNext "$@"
}


# LogDebugOn ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogDebugOn() {
  local pref=''
  [[ "$1" =~ ^-f([0-9]*) ]] && {
    shift
    pref="-f$((${BASH_REMATCH[1]:-1}))"
  }
  LogDebug '' ${1:-$__INTERNAL_Log_level_DEBUG} || {
    trap "
      __INTERNAL_Log_DEBUGING_res=\$?
      let __INTERNAL_Log_DEBUGING++
      if [[ -z \"\$__INTERNAL_Log_DEBUGING_cmd\" ]]; then
        __INTERNAL_Log_DEBUGING_cmd=\"\$BASH_COMMAND\"
        LogDebug $pref \"executing >>>>> \$__INTERNAL_Log_DEBUGING_cmd <<<<<\" ${1:-$__INTERNAL_Log_level_DEBUG}
      else
        LogDebug $pref \"execution >>>>> \$__INTERNAL_Log_DEBUGING_cmd <<<<< returned \$__INTERNAL_Log_DEBUGING_res\" ${1:-$__INTERNAL_Log_level_DEBUG}
        __INTERNAL_Log_DEBUGING_cmd=\"\$BASH_COMMAND\"
        if [[ \"\$__INTERNAL_Log_DEBUGING_cmd\" =~ LogDebugOff ]]; then
          trap - DEBUG
        else
          LogDebug $pref \"executing >>>>> \$__INTERNAL_Log_DEBUGING_cmd <<<<<\" ${1:-$__INTERNAL_Log_level_DEBUG}
        fi
      fi" DEBUG 
  }
}; # end of LogDebugOn }}}


# LogMoreOn ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogMoreOn() {
  LogMore || {
    local pref=''
    [[ "$1" =~ ^-f([0-9]*) ]] && {
      shift
      pref="-f$((${BASH_REMATCH[1]:-1}))"
    }
    LogDebugOn $pref ${1:-$__INTERNAL_Log_level_MORE}
  }
}; # end of LogMoreOn }}}


# LogDebugOff ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
# log info about execution to Debug level
LogDebugOff() {
  __INTERNAL_Log_DEBUGING_cmd=''
}; # end of LogDebugOff }}}


# LogVar ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogVar() {
  [[ -n "$DEBUG" ]] && {
    echo -n 'eval '
    while [[ -n "$1" ]]; do
      echo -n "LogDebug -f \"\$(set | grep -P '^$1=')\";"
      shift
    done
  }
}; # end of LogVar }}}


# __INTERNAL_LogRedirectToBeakerlib ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
__INTERNAL_LogRedirectToBeakerlib() {
  echo -e "\nrunning inside the beakerlib - redirect own logging functions to beakerlib ones"
  true; LogjAddMessage() {
    LogMore___ -f "begin $*"
    rljAddMessage "$2" "$1"
    LogMore___ -f "end $*"
  }
  true; Log() {
    LogMore___ -f "begin $*"
    case ${2} in
      INFO)
        LogjAddMessage "INFO" "$1"
        LogPrintMessage "$2" "${__INTERNAL_Log_prefix}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
        ;;
      BEGIN)
        LogjAddMessage "INFO" "$*:"
        LogPrintMessage "$2" "${__INTERNAL_Log_prefix}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
        ;;
      WARNING|WARN|ERROR|FATAL)
        LogjAddMessage "WARNING" "$1"
        LogPrintMessage "$2" "${__INTERNAL_Log_prefix}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
        ;;
      SKIP|SKIPPING)
        LogjAddMessage "WARNING" "$*:"
        LogPrintMessage "$2" "${__INTERNAL_Log_prefix}${__INTERNAL_Log_prefix2}${1}${__INTERNAL_Log_postfix}"
        ;;
      FAIL)
        rlFail "$*"
        return $?
        ;;
      PASS)
        rlPass "$*"
        return $?
        ;;
      *)
        rlLog "$*"
        ;;
    esac
    LogMore___ -f "end $*"
    return 0;
  }
}
# end of __INTERNAL_LogRedirectToBeakerlib }}}


# LogLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
LogLibraryLoaded() {
  declare -F rlDie > /dev/null && __INTERNAL_LogRedirectToBeakerlib
  return 0
}; # end of LogLibraryLoaded }}}


echo "done."

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

