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
#   library-prefix = opts
#   library-version = 4
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_opts_LIB_VERSION=4
: <<'=cut'
=pod

=head1 NAME

BeakerLib library opts

=head1 DESCRIPTION

This library provides simple way for defining script's or function's option
agruments including help.

=head1 USAGE

To use this functionality you need to import library distribution/opts and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/opts)" >> $(METADATA)

B<Code example>

	testfunction() {
	  optsBegin -h "Usage: $0 [options]
	
	  options:
	"
	  optsAdd 'flag1' --flag
	  optsAdd 'optional1|o' --optional
	  optsAdd 'Optional2|O' "echo opt \$1" --optional --long --var-name opt
	  optsAdd 'mandatory1|m' "echo man \$1" --mandatory
	  optsDone; eval "${optsCode}"
	  echo "$optional1"
	  echo "$opt"
	  echo "$mandatory1"
	}

=head1 FUNCTIONS

=cut

echo -n "loading library opts v$__INTERNAL_opts_LIB_VERSION... "

# optsAdd ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
optsAdd() {
  LogMoreMed -f "begin '$*'"
  local GETOPT=$(getopt -q -o fomv:d:lh:l -l flag,opt,optional,mandatory,varname:,default:,local,help:,long -- "$@")
  eval set -- "$GETOPT"
  local type='f' var_name var_name_set default help long
  while [[ -n "$@" ]]; do
    case $1 in
    --)
      shift; break
      ;;
    -h|--help)
      shift
      help="$1"
      ;;
    -l|--long)
      long=1
      ;;
    -d|--default)
      shift
      default="$1"
      ;;
    -v|--varname|--var-name)
      shift
      var_name="$1"
      var_name_set=1
      ;;
    -f|--flag)
      type='f'
      ;;
    -o|--opt|--optional)
      type='o'
      ;;
    -m|--mandatory)
      type='m'
      ;;
    *)
      echo "unknown option '$1'"
      return 1
      ;;
    esac
    shift;
  done
  [ -z "$var_name" ] && {
    var_name=$(echo -n "$1" | cut -d '|' -f 1 | sed -e 's/-//g;s/^[0-9]/_\0/')
    LogMoreHigh -f "constructing variable name '$var_name'"
  }
  local opts='' opts_help='' optsi=''
  for optsi in $(echo -n "$1" | tr '|' ' '); do
    if [[ ${#optsi} -ge 2 || $long -eq 1 ]]; then 
      opts="$opts|--$optsi"
      opts_help="$opts_help|--$optsi[=ARG]"
      __INTERNAL_opts_long="${__INTERNAL_opts_long},${optsi}"
      LogMoreHigh -f "adding long option '$optsi'"
      case $type in
      m)
        __INTERNAL_opts_long="${__INTERNAL_opts_long}:"
        ;;
      o)
        __INTERNAL_opts_long="${__INTERNAL_opts_long}::"
        ;;
      esac
    else
      opts="$opts|-$optsi"
      opts_help="$opts_help|-${optsi}[ARG]"
      __INTERNAL_opts_short="${__INTERNAL_opts_short}${optsi}"
      LogMoreHigh -f "adding short option '$optsi'"
      case $type in
      m)
        __INTERNAL_opts_short="${__INTERNAL_opts_short}:"
        ;;
      o)
        __INTERNAL_opts_short="${__INTERNAL_opts_short}::"
        ;;
      esac
    fi
  done
  optsCode="${optsCode}
  ${opts:1})
    optsPresent=\"\${optsPresent}$var_name \""
  LogMoreHigh -f "adding code for processing option '${opts:1}'"
  __INTERNAL_opts_init_var="$__INTERNAL_opts_init_var
${__INTERNAL_opts_local}$var_name=()"
  __INTERNAL_opts_default="$__INTERNAL_opts_default
[[ \"\$optsPresent\" =~ \$(echo \"\<${var_name}\>\") ]] || ${__INTERNAL_opts_local}$var_name='$default'"
  case $type in
  f)
    [[ -z "$2" || -n "$var_name_set" ]] && {
      local val=1
      [[ -n "$default" ]] && val=''
      optsCode="$optsCode
    $var_name+=( '$val' )"
    }
    __INTERNAL_opts_help="${__INTERNAL_opts_help}
  ${opts:1}"
    ;;
  o|m)
    optsCode="$optsCode
    shift"
    [[ -z "$2" || -n "$var_name_set"  ]] && optsCode="$optsCode
    $var_name+=( \"\$1\" )"
    if [[ "$type" == "o" ]]; then
      __INTERNAL_opts_help="${__INTERNAL_opts_help}
  ${opts_help:1}"
    else
      __INTERNAL_opts_help="${__INTERNAL_opts_help}
  ${opts:1} ARG"
    fi
    ;;
  esac
  [[ -n "$2" ]] && {
  optsCode="$optsCode
    $2"
  }
  optsCode="$optsCode
    ;;"

  __INTERNAL_opts_help="${__INTERNAL_opts_help}${help:+
      $help
}"
  LogMoreMed -f "end"
}; # end of optsAdd }}}


# optsBegin ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
optsBegin() {
  LogMoreMed -f "begin '$*'"
  optsCode=''
  optsPresent=' '
  __INTERNAL_opts_short='.'
  __INTERNAL_opts_long='help'
  __INTERNAL_opts_help=''
  __INTERNAL_opts_local=''
  __INTERNAL_opts_default=''
  __INTERNAL_opts_init_var=''
  [[ "${FUNCNAME[1]}" != "main" ]] && __INTERNAL_opts_local='local '
  while [[ -n "$1" ]]; do
    case $1 in
    --)
      shift; break
      ;;
    -h|--help)
      shift
      __INTERNAL_opts_help="$1"
      ;;
    *)
      echo "unknown option '$1'"
      return 1
      ;;
    esac
    shift;
  done
  LogMoreMed -f "end"
}; # end of optsBegin }}}


# optsDone ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
optsDone() {
  LogMoreMed -f "begin '$*'"
  optsCode="${__INTERNAL_opts_local}GETOPT=\$(getopt -o ${__INTERNAL_opts_short} -l ${__INTERNAL_opts_long} -- \"\$@\")
[[ \$? -ne 0 ]] && {
  echo 'Exiting'
  return 1 >& /dev/null
  exit 1
}
eval set -- \"\$GETOPT\"
${__INTERNAL_opts_init_var:1}
while [[ -n \"\$1\" ]]; do
  case \$1 in
  --)
    shift; break
    ;;
${optsCode}

  --help)
    echo \"\$__INTERNAL_opts_help\"
    return >& /dev/null
    exit
    ;;
  *)
    echo \"unknown option '\$1'\"
    return 1 >& /dev/null
    exit 1
  ;;
  esac
  shift
done
${__INTERNAL_opts_default:1}
unset optsCode __INTERNAL_opts_help __INTERNAL_opts_short __INTERNAL_opts_long __INTERNAL_opts_default __INTERNAL_opts_init_var __INTERNAL_opts_local
"
  if ! echo "$optsCode" | grep -q -- '--help$'; then
    __INTERNAL_opts_help="$__INTERNAL_opts_help
  --help
      Show this help."
  fi
  LogMoreHigh -f "optsCode:\n$optsCode"
  LogMoreMed -f "end"
}; # end of optsDone }}}


# optsSelfCheck ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
optsSelfCheck() {
  optsBegin -h "Usage: $0 [options]

  options:
"
#  optsAdd 'help' -f 'echo help'
  optsAdd 'flag' -f 'echo f'
  optsAdd 'optional|o' -o "echo opt \$1"
  optsAdd 'Optional|O' -o "echo opt \$1" --long
  optsAdd 'mandatory|m' -m "echo man \$1"
  optsDone
  
  echo "${optsCode}"
  
  echo ...
  
  eval "${optsCode}"
  
  echo ...
  
  fce() {
    optsBegin -h "Usage: $0 [options]

  options:
"
  #  optsAdd 'help' -f 'echo help'
    optsAdd 'flag' -f
    optsAdd 'optional|o' -o "echo opt \$1"
    optsAdd 'Optional|O' -o "echo opt \$1" --long
    optsAdd 'mandatory|m' -m "echo man \$1"
    optsDone
    echo "${optsCode}"
    
    echo ...
    
    eval "${optsCode}"
    
    echo ...
  }
  
  echo -e 'test for opts in function\n========================='
  fce --help
}; # end of optsSelfCheck }}}


# optsLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
optsLibraryLoaded() {
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

