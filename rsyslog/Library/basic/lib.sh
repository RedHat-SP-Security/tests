#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/rsyslog/Library/basic
#   Description: What the test does
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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
#   library-prefix = rsyslog
#   library-version = 53
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_rsyslog_LIB_NAME="rsyslog/basic"
__INTERNAL_rsyslog_LIB_VERSION=53

: <<'=cut'
=pod

=head1 NAME

rsyslog/basic - Basic functions to support rsyslog

=head1 DESCRIPTION

This library covers rsyslog checks for dual components like rsyslog and rsyslog7.


=head1 FUNCTIONS

=cut

echo -n "loading library $__INTERNAL_rsyslog_LIB_NAME v$__INTERNAL_rsyslog_LIB_VERSION... "


__INTERNAL_rsyslog_LIB_PATH="$( dirname "$( readlink -e "${BASH_SOURCE[0]}" )" )"
__INTERNAL_rsyslog_STORE=/var/tmp/rsyslog-lib


__INTERNAL_rsyslogGetInstalled() {
  LogMore -f "begin $*"
  rpm -qa --qf "%{name} '%{distribution} %{vendor}'\n" | grep ^rsyslog | grep -v '(none) (none)' | grep -Po '^\S+'
  LogMore -f "end"
}


__INTERNAL_rsyslogGetSuffixes() {
  LogMore -f "begin $*"
   echo "$1" | sed 's/^rsyslog[^-]*//'
  LogMore -f "end"
}


__INTERNAL_rsyslog_get_pattern() {
  echo "#### RSYSLOG-LIB $1 $2 ####"
}; # end of __INTERNAL_rsyslog_test_version


__INTERNAL_rsyslog_import() {
  [[ -r $__INTERNAL_rsyslog_STORE ]] && . $__INTERNAL_rsyslog_STORE
}


__INTERNAL_rsyslog_export() {
  declare -p $1 | sed -r 's/^declare\s+-a\s+/eval /;s/^declare\s+\S+\s+//' >> $__INTERNAL_rsyslog_STORE
}


true <<'=cut'
=pod

=head2 rsyslogVersion

Check whether we have rsyslog installed.
With given number of version as parameter returns 0 if the particular
rsyslog version is running. Multiple arguments can be passed separated
with space as well as any particular release (5.1 5.2 5.3).
Each version can have a prefix consisting of '<', '<=', '=', '>=', '>',
matching whenever the currently installed version is lesser, lesser or equal,
equal, equal or greater, greater than the version specified as argument.
Note that ie. '=5' (unlike just '5') matches exactly 5 (5.0),
not 5.N, where N > 0.

    rsyslogVersion

Returns 0 if we have rsyslog installed.

    rsyslogVersion 7.4 6

Returns 0 if we have rsyslog 7.6 or any rsyslog 6 installed.

=cut
rsyslogVersion(){
    local name pkg res whole major arg op pattern dots test
    name=rsyslog

    pkg=$(rpm -qa "$name*" | grep "^rsyslog[0-9]*-[0-9][0-9]*" | head -n 1)
    if [[ -z "$pkg" ]]; then
      LogError "got no rsyslog package from rpm"
      return 2;
    fi
    LogDebug -f "got '$pkg' from rpm"

    whole=$(rpm -q $pkg --queryformat '%{version}-%{release}\n')
    major=$(echo $whole |  cut -d '.' -f 1)

    LogMore -f "detected rsyslog version '$whole'"

  [[ -z "$1" ]] && {
    LogDebug -f "no argument provided, returning 0"
    return 0
  }

  LogDebug -f "processing arguments '$*'"
  for arg in "$@"
  do
    LogMore -f "processing argument '$arg'"
    # sanity check - version needs to consist of numbers/dots/<=>
    pattern='^([\<=\>]*)([0-9].*)$'
    [[ "$arg" =~ $pattern ]] || {
      LogDebug -f "argument '$arg' is not in expected format '$pattern', returning 1"
      return 3
    }

    op="${BASH_REMATCH[1]}"
    arg="${BASH_REMATCH[2]}"
    LogMore -f "operator '$op', argument '$arg'"
    if [[ -z "$op" ]]; then
      dots=${arg//[^.]}
      [[ "$whole" =~ [^.]+(.[^.-]+){${#dots}} ]]
      test=${BASH_REMATCH[0]}
      LogMore -f "matching '$arg' against '$major' or '$whole' or '$test'"
      if [[ "$arg" == "$major" || "$arg" == "$whole" || "$arg" == "$test" ]]
      then
        LogDebug -f "match found, returning 0"
        return 0
      fi
    else
      if [[ "$arg" =~ \. ]]; then
        LogDebug -f "doing comparism of '$whole' '$op' '$arg'"
        rlTestVersion "$whole" "$op" "$arg"
      else
        LogDebug -f "doing comparism of '$major' '$op' '$arg'"
        rlTestVersion "$major" "$op" "$arg"
      fi
      res=$?
      LogDebug -f "returning $res"
      return $res
    fi
  done
  LogDebug -f "no match found, returning 1"
  return 1
}; # end of rsyslogVersion()


rsyslogCheckInstalled() {
  LogMore -f "begin $*"
  local pkgs=$(rpm -qa --qf "%{name}\n" | grep -P "^($(echo "$1" | tr ' ' '|'))\$")
  Log "installed packages: $pkgs"
  local res=$(( $(echo "$1" | wc -w) - $(echo "$pkgs" | wc -w) ))
  LogMore -f "end, res=$res"
  return $res
}


rsyslogCheckNotInstalled() {
  LogMore -f "begin $*"
  rsyslogCheckInstalled "$@"
  [[ $? -eq $(echo "$1" | wc -w) ]]
  local res=$?
  LogMore -f "end"
  return $res
}


rsyslogSwapVersion() {
  local res=0
  LogMore -f "begin $*"
  local pkgs_old='' pkgs_new=''
  while read pkg; do
    pkgs_old="$pkgs_old ${pkg}"
    pkgs_new="$pkgs_new rsyslog${1}$(__INTERNAL_rsyslogGetSuffixes "${pkg}")"
  done < <(__INTERNAL_rsyslogGetInstalled)
  pkgs_old="${pkgs_old:1}"
  pkgs_new="${pkgs_new:1}"
  if [[ "$pkgs_old" == "$pkgs_new" ]]; then
    Log "Nothing to do, the required set is already installed."
  else
    Log "swapping rsyslog versions"
    Log "old versions are $pkgs_old"
    rlRun "rpm -e --nodeps $pkgs_old" 0 "remove old packages set" || let res++
    rlRun "rsyslogCheckNotInstalled '$pkgs_old'" 0 "check old packages set is removed" || let res++
    Log "new versions will be $pkgs_new"
    rlRun "yum install -y $pkgs_new" 0 "install new packages set" || let res++
    rlRun "rsyslogCheckInstalled '$pkgs_new'" 0 "check new packages set is installed" || let res++
  fi
  rsyslogSuffix=$1
  __INTERNAL_rsyslog_export rsyslogSuffix
  LogMore -f "end"
  return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigIsNewSyntax
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigIsNewSyntax

Return true if rsyslogSyntax is set to [Nn][Ee][Ww].

=over

=item -p print

Print output.

=back

=cut

rsyslogConfigIsNewSyntax()
{
  if [[ $rsyslogSyntax =~ [Nn][Ee][Ww] ]]; then
    if [[ $1 == "-p" ]]; then
      LogInfo "New Syntax is set."
    fi
    return 0
  else
    if [[ $1 == "-p" ]]; then
      LogInfo "Old Syntax is set."
    fi
    return 1
  fi
}

# make sure we have default config faile in place
__INTERNAL_rsyslogConfRepair() {
  local cache_file="/var/tmp/library_rsyslog_basic_orig_config"
  local config_file="/etc/rsyslog.conf"
  local rsyslog_package=$(rpm -qf "$config_file")
  local rsyslog_package_file
  local res=0
  if rpm -V $rsyslog_package | grep -q -- "$config_file"; then
    LogInfo "config file is modified"
    if [[ -r "$cache_file" ]]; then
      LogInfo " ..replacing by the default one from cache"
      cat "$cache_file" > "$config_file" || let res++
    else
      LogInfo " ..replacing by the default one from the package"
      rm -f $config_file || let res++
      rsyslog_package_file=$(rlRpmDownload $rsyslog_package) || let res++
      rpm -Uvh --force ${rsyslog_package_file} || let res++
      LogInfo "saving current unchanged config to cache"
      cat "$config_file" > "$cache_file" || let res++
    fi
  else
    LogInfo "saving current unchanged config to cache"
    cat "$config_file" > "$cache_file" || let res++
  fi
  return $res
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogPrepareConf
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogPrepareConf

Patch or copy rsyslog.conf to /etc/rsyslog.conf according to set rsyslogSyntax and RHEL version.

=over

=back

=cut


__INTERNAL_rsyslogConfigPatchSelection() {
  local distro ver p
  distro="$(. /etc/os-release; echo "$ID")"
  [[ "$distro" == "centos" ]] && distro="rhel"
  ver=($(. /etc/os-release; echo "$VERSION_ID" | grep -o '[0-9]\+'))
  rlLogInfo "distro=$distro, ver=( ${ver[*]} )"
  [[ -z "${ver[1]}" ]] && ver[1]=12
  while :; do
    for ext in conf patch; do
      p="$1/$distro${ver[0]}${ver[1]:+.${ver[1]}}.$ext"
      rlLogDebug "$FUNCNAME(): trying path $p"
      [[ -f "$p" ]] && {
        rlLogInfo "found path $p"
        echo "$p"
        return 0
      }
    done
    [[ -z "${ver[0]}" ]] && {
      break
    }
    [[ -z "${ver[1]}" ]] && {
      ver[1]=12
      let ver[0]--
      [[ ${ver[0]} -eq -1 ]] && {
        ver[0]=''
        ver[1]=''
      }
      continue
    }
    [[ ${ver[1]} -eq 0 ]] && {
      ver[1]=''
      continue
    }
    let ver[1]--
  done
  return 1
}


rsyslogPrepareConf(){
  LogMore -f "begin $*"

  local output=/etc/rsyslog.conf
  local inputPath=$__INTERNAL_rsyslog_LIB_PATH
  local patch_path
  local res=0
  __INTERNAL_rsyslogConfRepair || res=1
  if rsyslogConfigIsNewSyntax -p; then
    inputPath+=/configs/new_syntax
  else
    inputPath+=/configs/old_syntax
  fi
  if patch_path=$(__INTERNAL_rsyslogConfigPatchSelection $inputPath); then
    if [[ "$patch_path" == *.patch ]]; then
      LogInfo "patching rsyslog.conf with $patch_path"
      patch --ignore-whitespace -N "$output" < "$patch_path" || res=$?
    else
      LogInfo "replacing rsyslog.conf with $patch_path"
      cat "$patch_path" > "$output" || res=$?
    fi
  else
    LogFail "unhandled distro version"
    res=1
  fi

  LogMore -f "end, res='$res'"
  return $res
}; #end of rsyslogPrepareConf

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigCreateSection
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigCreateSection

Print named (tagged) section to stdout.

    rsyslogConfigCreateSection section content

=item section

Config section name to be created.

=item content

Data to add specified as file or <<EOF
data
EOF

=over

=back

=cut

rsyslogConfigCreateSection(){
  if [[ "$1" == "" ]]; then
    rlFail "Missing first argument (what to look for)" >&2
    return 1
  fi

  local BEGIN="$(__INTERNAL_rsyslog_get_pattern BEGIN "$1")"
  local END="$(__INTERNAL_rsyslog_get_pattern END "$1")"

  if [[ "$2" == "" ]]; then
    local TMP=$(mktemp)
    if test -t 0; then
      echo "$BEGIN"
      echo "$END"
    else
      echo "$BEGIN"
      cat -
      echo "$END"
    fi
  elif [[ -f $2 ]]; then
    echo "$BEGIN"
    cat $2
    echo "$END"
  else
    rlFail "Entered filename is not a file" >&2
    return 1
  fi
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigGetSection
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigGetSection

Get section from file.

=item pattern

Pattern used to search section from begin to end.

=item filename

Filename of file we want to change

=over

=back

=cut

rsyslogConfigGetSection(){
  if [[ "$1" == "" ]]; then
    rlFail "Missing first argument (what to look for)"
    return 1
  fi

  local FILE="${2:-/etc/rsyslog.conf}"

 sed -n "/$(__INTERNAL_rsyslog_get_pattern BEGIN "$1")/,/$(__INTERNAL_rsyslog_get_pattern BEGIN "$1")/p" $FILE | head -n -1 | tail -n +2
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigReplace
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigReplace

Replace specified directives in specified rsyslog.conf files.
    rsyslogConfigReplace pattern file replacement
=over

=item pattern

Pattern used to search where to replace.

=item filename

Filename of file we want to change

=item replacement

Data to add specified as file or <<EOF
data
EOF

=back

=cut

rsyslogConfigReplace(){
  LogMore -f "begin $*"

  local SECTION="$1"
  local FILE="${2:-/etc/rsyslog.conf}"
  local REPLACEMENT=""
  local BEGIN="$(__INTERNAL_rsyslog_get_pattern BEGIN "$1")"
  local END="$(__INTERNAL_rsyslog_get_pattern END "$1")"

  if [[ "$SECTION" == "" ]]; then
    rlFail "Missing first argument (what to look for)"
    return 1
  fi

  REPLACEMENT=$(mktemp)
  if [[ "$3" == "" ]]; then
    if test -t 0; then
      (
        echo "$BEGIN"
        echo "$END"
      ) > $REPLACEMENT
    else
      (
        echo "$BEGIN"
        cat -
        echo "$END"
      ) > $REPLACEMENT
    fi
  elif [[ -f $3 ]]; then
    (
      echo "$BEGIN"
      cat $3
      echo "$END"
    ) > $REPLACEMENT
  else
    rlFail "Entered filename is not a file"
    return 1
  fi

  grep -q "$BEGIN" $FILE || rlFail  "Not found BEGIN of entered pattern $SECTION"
  grep -q "$END" $FILE || rlFail "Not found END of entered pattern $SECTION"

  sed -i -e "/$END/r $REPLACEMENT" -e "/$BEGIN/,/$END/d" $FILE

  rm -f $REPLACEMENT
  LogMore -f "end"
}; #end of rsyslogConfigReplace


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigAppend
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigAppend

Append specified directives after searched pattern in specified rsyslog.conf files.
    rsyslogConfigReplace --begin/--end pattern file addition

=over

=item [--begin/--end]

Append after begin or end of searched pattern.
Default is --end.

=item pattern

Pattern used to search where to replace.

=item file

File to edit.

=item addition

Data to add specified as file or <<EOF
data
EOF

=back

=cut

rsyslogConfigAppend(){
  LogMore -f "begin $*"
  local SEARCH=""
  local REPLACEMENT=""
  local SECTION="$1"

  if [[ "$1" =~ --[Bb][Ee][Gg][Ii][Nn] ]]; then
    shift
    SECTION="$1"
    SEARCH="$(__INTERNAL_rsyslog_get_pattern BEGIN "$SECTION")"
    LogMore_ -f "appending after begin"
  elif [[ "$1" =~ --[Ee][Nn][Dd] ]]; then
    shift
    SECTION="$1"
    SEARCH="$(__INTERNAL_rsyslog_get_pattern END "$SECTION")"
    LogMore_ -f "appending after end"
  else
    SEARCH="$(__INTERNAL_rsyslog_get_pattern END "$SECTION")"
    LogMore_ -f "appending after begin"
  fi

  local FILE="${2:-/etc/rsyslog.conf}"

  REPLACEMENT=$(mktemp)
  if [[ "$3" == "" ]]; then
    if test -t 0; then
      echo "" > $REPLACEMENT
    else
      cat > $REPLACEMENT
    fi
  elif [[ -f $3 ]]; then
    cat $3 > $REPLACEMENT
  else
    rlFail "Entered filename is not a file"
    return 1
  fi

  grep -q "$SEARCH" $FILE || rlFail  "Not found entered pattern $SECTION"

  sed -i -e "/$SEARCH/r $REPLACEMENT" $FILE

  rm -f $REPLACEMENT
  LogMore -f "end"
}; #end of rsyslogConfigAppend


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigPrepend
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigPrepend

Prepend specified directives before searched pattern in specified rsyslog.conf files.
    rsyslogConfigReplace --begin/--end pattern file addition
=over

=item [--begin/--end]

Prepend before begin or end of searched pattern.
Default is --begin.

=item pattern

Pattern used to search where to replace.

=item file

File to edit.

=item addition

Data to add specified as file or <<EOF
data
EOF

=back

=cut

rsyslogConfigPrepend()
{
  LogMore -f "begin $*"
  local SEARCH=""
  local REPLACEMENT=""
  local SECTION="$1"

  if [[ "$1" =~ --[Bb][Ee][Gg][Ii][Nn] ]]; then
    shift
    SECTION="$1"
    SEARCH="$(__INTERNAL_rsyslog_get_pattern BEGIN "$SECTION")"
    LogMore_ -f "prepending before begin"
  elif [[ "$1" =~ --[Ee][Nn][Dd] ]]; then
    shift
    SECTION="$1"
    SEARCH="$(__INTERNAL_rsyslog_get_pattern END "$SECTION")"
    LogMore_ -f "prepending before end"
  else
    SEARCH="$(__INTERNAL_rsyslog_get_pattern BEGIN "$SECTION")"
    LogMore_ -f "prepending before begin"
  fi

  local FILE="${2:-/etc/rsyslog.conf}"

  REPLACEMENT=$(mktemp)
  if [[ "$3" == "" ]]; then
    if test -t 0; then
      echo "$SEARCH" > $REPLACEMENT
    else
      (
        cat -
        echo "$SEARCH"
      ) > $REPLACEMENT
    fi
  elif [[ -f $3 ]]; then
    (
      cat $3
      echo "$SEARCH"
    ) > $REPLACEMENT
  else
    rlFail "Entered filename is not a file"
    return 1
  fi

  LogMore_ -f "searching for '$SEARCH'"
  grep -q "$SEARCH" $FILE || rlFail "Not found entered pattern $SECTION"
  sed -i "/$SEARCH/{
r $REPLACEMENT
d
}" $FILE
  rm -f $REPLACEMENT
  LogMore -f "end"
}; #end of rsyslogConfigPrepend


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rsyslogConfigAddTo
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
true <<'=cut'
=pod

=head2 rsyslogConfigAddTo

Add peac of configuration to the specific section of config file.

    rsyslogConfigAddTo [--begin] section file addition

=over

=item --begin

Add the config at the beginning of the section instead of the end.

=item section

Configuration section name.

=item file

File to edit.

=item addition

Data to add specified as file or <<EOF
data
EOF

=back

=cut

rsyslogConfigAddTo(){
  LogMore -f "begin $*"
  local SEARCH=""
  local REPLACEMENT=""

  if [[ "$1" == "--begin" ]]; then
    shift
    rsyslogConfigAppend --begin "$@"
  else
    rsyslogConfigPrepend --end "$@"
  fi
}; #end of rsyslogConfigAddTo


rsyslogSysconfig() {
  local res=0 key val
  while [[ -n "$1" ]]; do
    key="${1%%=*}"
    val="${1#*=}"
    if [[ "$1" =~ = ]]; then
      # set
      if grep -qP "^$key=" /etc/sysconfig/rsyslog; then
        Log "changing '$key' to '$val'"
        sed -ri "s/^$key=.*\$/$key=$val/" /etc/sysconfig/rsyslog
        let res=res + $?
      else
        Log "setting '$key' to '$val'"
        echo "$key=$val" >> /etc/sysconfig/rsyslog
      fi
    else
      # delete
      Log "removing '$key'"
      sed -ri "/^$key=/d" /etc/sysconfig/rsyslog
      let res=res + $?
    fi
    shift
  done
  return $res
}


rsyslogTranslate() {
  LogMore -f "begin $*"

  [[ ! $rsyslogSuffix && ${rsyslogSuffix-unset} ]] && {
    Log 'rsyslogTranslate(): rsyslogSuffix not set, trying to import it'
    [[ ! $rsyslogSuffix && ${rsyslogSuffix-unset} ]] && {
      rsyslogSuffix=''
      Log 'rsyslogTranslate(): rsyslogSuffix still not set'
      rsyslogSuffix=$(__INTERNAL_rsyslogGetInstalled | grep -Pom1 '^rsyslog[0-9]*[^-]' | grep -o '[0-9]*')
      #RHEL 5 is probably buged becaous command "bla1 | grep -o [0-9]*" outputs empty string but it should output "1"
      rlIsRHEL 5 && rsyslogSuffix=$(__INTERNAL_rsyslogGetInstalled | grep -Pom1 '^rsyslog[0-9]*[^-]' | grep -o '[0-9]')
    }
    Log "rsyslogTranslate(): rsyslogSuffix='$rsyslogSuffix'"
  }
  LogMore -f "rsyslogSuffix='$rsyslogSuffix'"
  echo "$1" | sed -r "s/rsyslog( |$|-)/rsyslog${rsyslogSuffix}\1/g"
  LogMore -f "end"
}


rsyslogSetup() {
  local res=0
  LogMore -f "begin $*"
  if [[ -z "$rsyslogSyntax" ]]; then
    LogInfo "rsyslogSyntax not set"
    if rlIsRHEL '<8'; then
      rsyslogSyntax='old'
      LogInfo "setting rsyslogSyntax old as default for rhel<8"
    else
      rsyslogSyntax='new'
      LogInfo "setting rsyslogSyntax new as default for rhel>=8"
    fi
  fi
  rsyslogConfigIsNewSyntax -p
  local reqs="$(rlGetMakefileRequires | grep -oE '\S*rsyslog\S*' | tr '\n' ' ')"
  reqs="$(rsyslogTranslate "$reqs")"
  rlRun "rlCheckRequirements $reqs" || {
    let res++
    Log "maybe you want to execute also: export rsyslogSuffix='installed'"
  }
  rlRun "rlFileBackup --clean --namespace rsyslog-lib /etc/rsyslog.conf /etc/rsyslog.d /etc/rsyslogd.d" 0-255
  rsyslogPrepareConf
  rsyslogPrintEffectiveConfig -n
  rsyslogServiceStart || let res++
  LogMore -f "end"
  return $res
}


rsyslogCleanup() {
  rlRun "rlFileRestore --namespace rsyslog-lib" 0-255
  rsyslogServiceRestore
  rm -f "${rsyslogOut[@]}" "${rsyslogServerOut[@]}"

}


rsyslogServerSetup() {
  rsyslogConf='/etc/rsyslog.conf'
  rsyslogServerConf='/etc/rsyslog-server.conf'
  rsyslogPidFile='/var/run/rsyslogd.pid'
  rlIsRHEL '<8' && rsyslogPidFile='/var/run/syslogd.pid'
  rsyslogServerPidFile='/var/run/rsyslogd-server.pid'
  rsyslogServerWorkDir='/var/lib/rsyslog-server'
  rsyslogServerLogDir='/var/log/server'
  rlRun "rlFileBackup --namespace rsyslog-lib-server --clean $rsyslogServerConf $rsyslogServerWorkDir $rsyslogServerLogDir $rsyslogServerPidFile"
  # prepare server side
  cat > $rsyslogServerConf <<EOF
################################ RSYSLOG-LIB ###################################
#### MODULES ####

##################### RSYSLOG-LIB BEGIN MODULES ################################

##################### RSYSLOG-LIB BEGIN MODLOAD IMUXSOCK #######################
##################### RSYSLOG-LIB END MODLOAD IMUXSOCK #########################

##################### RSYSLOG-LIB BEGIN MODLOAD IMJOURNAL ######################
##################### RSYSLOG-LIB END MODLOAD IMJOURNAL ########################

##################### RSYSLOG-LIB BEGIN MODLOAD IMKLOG #########################
##################### RSYSLOG-LIB END MODLOAD IMKLOG ###########################

##################### RSYSLOG-LIB BEGIN MODLOAD IMMARK #########################
##################### RSYSLOG-LIB END MODLOAD IMMARK ###########################

##################### RSYSLOG-LIB BEGIN MODLOAD IMUDP ##########################
##################### RSYSLOG-LIB END MODLOAD IMUDP ############################

##################### RSYSLOG-LIB BEGIN MODLOAD IMTCP ##########################
##################### RSYSLOG-LIB END MODLOAD IMTCP ############################

##################### RSYSLOG-LIB END MODULES ##################################

#### GLOBAL DIRECTIVES ####

##################### RSYSLOG-LIB BEGIN GLOBALS ########

##################### RSYSLOG-LIB BEGIN WOKRDIRECTORY ##########################
global(workDirectory="$rsyslogServerWorkDir")
##################### RSYSLOG-LIB END WOKRDIRECTORY ############################

##################### RSYSLOG-LIB BEGIN MODLOAD OMFILE DEFAULT TEMPLATE ########
module(load="builtin:omfile" template="RSYSLOG_TraditionalFileFormat")
##################### RSYSLOG-LIB END OMFILE DEFAULT TEMPLATE ##################

##################### RSYSLOG-LIB BEGIN INCLUDECONFIG ##########################
##################### RSYSLOG-LIB END INCLUDECONFIG ############################

##################### RSYSLOG-LIB END GLOBALS ########

#### RULES ####

##################### RSYSLOG-LIB BEGIN RULES ##################################

# Log all kernel messages to the console.
# Logging much else clutters up the screen.

# Log anything (except mail) of level info or higher.
# Don\t log private authentication messages!
*.info;mail.none;authpriv.none;cron.none                action(type="omfile" file="$rsyslogServerLogDir/messages")

# The authpriv file has restricted access.
authpriv.*                                              action(type="omfile" file="$rsyslogServerLogDir/secure")

# Log all the mail messages in one place.
mail.*                                                  action(type="omfile" file="$rsyslogServerLogDir/maillog")


# Log cron stuff
cron.*                                                  action(type="omfile" file="$rsyslogServerLogDir/cron")

# Save news errors of level crit and higher in a special file.
uucp,news.crit                                          action(type="omfile" file="$rsyslogServerLogDir/spooler")

# Save boot messages also to boot.log

local7.*                                                action(type="omfile" file="$rsyslogServerLogDir/boot.log")
##################### RSYSLOG-LIB END RULES #####################################
EOF
  rlRun "rm -rf $rsyslogServerWorkDir $rsyslogServerLogDir $rsyslogServerPidFile"
  rlRun "mkdir -p $rsyslogServerWorkDir $rsyslogServerLogDir"
  rlRun "semanage import <<< 'fcontext -a -e /etc/rsyslog.conf $rsyslogServerConf
fcontext -a -e /var/lib/rsyslog $rsyslogServerWorkDir
fcontext -a -e /var/log $rsyslogServerLogDir
fcontext -a -e $rsyslogPidFile $rsyslogServerPidFile'" 0 "set selinux equivalence"
  rlRun "restorecon -vF $rsyslogServerConf $rsyslogServerWorkDir $rsyslogServerLogDir"

  # create server config manipulation functions clones
  local i
  for i in PrintEffectiveConfig ConfigGetSection ConfigReplace ConfigAppend ConfigPrepend ConfigAddTo; do
    eval "rsyslogServer$i() { rsyslog$i \"\$@\" \$rsyslogServerConf; }"
  done
  rsyslogServerPrintEffectiveConfig -n
}



rsyslogServerCleanup() {
  rsyslogServerStop
  rlRun "semanage import <<< 'fcontext -d -e /etc/rsyslog.conf $rsyslogServerConf
fcontext -d -e /var/lib/rsyslog $rsyslogServerWorkDir
fcontext -d -e /var/log $rsyslogServerLogDir
fcontext -d -e $rsyslogPidFile $rsyslogServerPidFile'" 0 "celanup selinux"
  rlRun "rlFileRestore --namespace rsyslog-lib-server"
}

rsyslogServerStart() {
  local res=0
  rsyslogServerStop || let res++
  if [[ "$1" == "--valgrind" ]]; then
    rsyslogServerOut=( $(mktemp) "${rsyslogServerOut[@]}" )
    __INTERNAL_PrintText "starting rsyslog server via valgrind" "LOG"
    valgrind --leak-check=full rsyslogd -n -d -i $rsyslogServerPidFile -f $rsyslogServerConf > $rsyslogServerOut 2>&1 &
    [[ -n ""$DEBUG ]] && tail -f $rsyslogServerOut &
    local i
    for ((i=180; i>0; i--)); do
      grep -Eq 'RSYSLOGD INITIALIZED|rsyslogd: initialization completed' $rsyslogServerOut && {
        echo
        [[ -n ""$DEBUG ]] && kill $!
        kill -USR1 $(cat $rsyslogServerPidFile)
        return 0
      }
      echo -n .
      sleep 1
    done
    [[ -n ""$DEBUG ]] && kill $!
    return 1
  else
    __INTERNAL_PrintText "starting rsyslog server" "LOG"
    rsyslogd -i $rsyslogServerPidFile -f $rsyslogServerConf || let res++
    sleep 1s
    return $res
  fi
}


rsyslogServerStop() {
  local res=0
  if [[ -s $rsyslogServerPidFile ]]; then
    __INTERNAL_PrintText "stopping rsyslog server" "LOG"
    kill $(cat $rsyslogServerPidFile) || let res++
  fi
  if [[ "$1" == "--valgrind" ]]; then
    local i
    for ((i=180; i>0; i--)); do
      grep -q '== ERROR SUMMARY' $rsyslogServerOut && {
        echo
        return 0
      }
      echo -n .
      sleep 1
    done
    return 1
  fi
  return $res
}


rsyslogServerStatus() {
  local res=0
  rlRun "journalctl -n 10 --no-pager _PID=$(cat $rsyslogServerPidFile)"
  kill -0 $(cat $rsyslogServerPidFile)
  return $res
}


__INTERNAL_rsyslog_pattern='########### rsyslog hack ###########'
rsyslogBeakerlibHack() {
  local res=0
  LogMore -f "begin $*"
  grep -q '########### rsyslog hack ###########' /usr/share/beakerlib/rpms.sh && {
    rlRun "rsyslogBeakerlibUnhack" || let res++
  }
  if [[ -n "$rsyslogSuffix" ]]; then
    Log "hack beakerlib to assert rsyslog$rsyslogSuffix instead of rsyslog"
    local phase=main
    local LF='
'
    local new_file="$__INTERNAL_rsyslog_pattern
__INTERNAL_rsyslogLib_translate() {
  local name=\"\$1\"
  rlLogDebug \"requested rpm \$name, checking '\$name' =~ rsyslog && ! '\$name' =~ rsyslog${rsyslogSuffix}\"
  [[ \"\$name\" =~ rsyslog && ! \"\$name\" =~ rsyslog${rsyslogSuffix} ]] && {
    local name2=\"\$(echo \"\$name\" | sed -r \"s/rsyslog(\$|-)/rsyslog${rsyslogSuffix}\1/\")\"
    rlLogWarning \"checking '\$name2' instead of '\$name'\"
    name=\"\$name2\"
  }
  echo \"\$name\"
}
$__INTERNAL_rsyslog_pattern"
    while IFS= read -r line; do
      case $phase in
      main)
        new_file="$new_file$LF$line"
        [[ "$line" == "__INTERNAL_RpmPresent() {" ]] && phase=__INTERNAL_RpmPresent
        [[ "$line" == "rlCheckRequirements() {" ]] && phase=rlCheckRequirements
        ;;
      __INTERNAL_RpmPresent)
        if [[ "$line" =~ local\ name= ]] ; then
          phase=main
          new_file="$new_file
${__INTERNAL_rsyslog_pattern} ${line}
$__INTERNAL_rsyslog_pattern
$(echo "$line" | sed -r 's/\=(.*)/=\$(__INTERNAL_rsyslogLib_translate \"\1\")/')
$__INTERNAL_rsyslog_pattern"
        else
          new_file="$new_file$LF$line"
        fi
        ;;
      rlCheckRequirements)
        if [[ "$line" =~ package= ]]; then
          phase=main
          new_file="$new_file
${__INTERNAL_rsyslog_pattern} ${line}
$__INTERNAL_rsyslog_pattern
$(echo "$line" | sed -r 's/(\$req)/\$(__INTERNAL_rsyslogLib_translate \"\1\")/')
$__INTERNAL_rsyslog_pattern"
        else
          new_file="$new_file$LF$line"
        fi
        ;;
      esac
    done < /usr/share/beakerlib/rpms.sh
    echo "${new_file}" > /usr/share/beakerlib/rpms.sh
  fi
  LogMore -f "end"
  return $res
}


rsyslogBeakerlibUnhack() {
  LogMore -f "begin $*"
  local a='' i=0
  local LF='
'
  while IFS= read -r line; do
    [[ "$line" == "$__INTERNAL_rsyslog_pattern" ]] && {
      let i=$i^1
      continue
    }
    if [[ $i -eq 0 ]]; then
      if [[ "$line" =~ $__INTERNAL_rsyslog_pattern\ (.*) ]]; then
        a="$a$LF${BASH_REMATCH[1]}"
      else
        a="$a$LF$line"
      fi
    fi
  done < /usr/share/beakerlib/rpms.sh
  echo "${a:1}" > /usr/share/beakerlib/rpms.sh
  LogMore -f "end"
}


rsyslogServiceStart() {
  local res=0
  rsyslogServiceStop || let res++
  if [[ "$1" == "--valgrind" ]]; then
    rsyslogOut=( $(mktemp) "${rsyslogOut[@]}" )
    __INTERNAL_PrintText "starting rsyslog via valgrind" "LOG"
    valgrind --leak-check=full rsyslogd -n -d -i $rsyslogPidFile -f $rsyslogConf > $rsyslogOut 2>&1 &
    [[ -n ""$DEBUG ]] && tail -f $rsyslogOut &
    local i
    for ((i=180; i>0; i--)); do
      grep -Eq 'RSYSLOGD INITIALIZED|rsyslogd: initialization completed' $rsyslogOut && {
        echo
        [[ -n ""$DEBUG ]] && kill $!
        kill -USR1 $(cat $rsyslogPidFile)
        return 0
      }
      echo -n .
      sleep 1
    done
    [[ -n ""$DEBUG ]] && kill $!
    return 1
  else
    __INTERNAL_PrintText "starting rsyslog" "LOG"
    rlServiceStart rsyslog || let res++
    sleep 1s
    return $res
  fi
}


rsyslogServiceStop() {
  local res=0
  if [[ "$1" == "--valgrind" ]]; then
    [[ -s $rsyslogPidFile ]] && {
      __INTERNAL_PrintText "stopping rsyslog" "LOG"
      kill $(cat $rsyslogPidFile)
    }
    local i
    for ((i=180; i>0; i--)); do
      grep -q '== ERROR SUMMARY' $rsyslogOut && {
        echo
        return 0
      }
      echo -n .
      sleep 1
    done
    return 1
  else
    rlIsRHEL 5 && {
    __INTERNAL_PrintText "stopping syslog" "LOG"
      rlServiceStop syslog || let res++
    }
    rlIsRHEL '<7' || {
    __INTERNAL_PrintText "stopping syslog.socket" "LOG"
      systemctl stop syslog.socket
    }
    __INTERNAL_PrintText "stopping rsyslog" "LOG"
    rlServiceStop rsyslog || let res++
    return $res
  fi
}


rsyslogServiceRestore() {
  local res=0
  rlIsRHEL '<7' || {
    __INTERNAL_PrintText "stopping syslog.socket" "LOG"
    systemctl stop syslog.socket
  }
  __INTERNAL_PrintText "restoring rsyslog" "LOG"
  rlServiceRestore rsyslog || let res++
  rlIsRHEL 5 && {
    __INTERNAL_PrintText "restoring syslog" "LOG"
    rlServiceRestore syslog || let res++
  }
  return $res
}


rsyslogServiceStatus() {
  if rlIsRHEL '<7'; then
    PAGER= service rsyslog status
  else
    PAGER= systemctl status -l rsyslog
  fi
}


rsyslogPrintEffectiveConfig() {
  local numbers=''
  [[ "$1" == '-n' ]] && {
    numbers=' -n'
    shift
  }
  local file="${1:-/etc/rsyslog.conf}"
  echo "# grep$numbers -v -e '^\s*#' -e '^\s*$' \"$file\""
  grep$numbers -v -e '^\s*#' -e '^\s*$' "$file"
  echo "---"
}


rsyslogConfigCheck() {
  local level="${1:-1}"
  shift
  local file="${1:+-f "$1"}"
  echo "# rsyslogd -N $level $file"
  rsyslogd -N $level $file
}


rsyslogResetLogFilePointer() {
  local file="$1"
  local var_name="file_${file//[^[:alnum:]]/_}_bytes"
  local bytes=0
  [[ -r "$1" ]] && bytes=$(stat -c '%s' $1)
  let $var_name=bytes+1
  export $var_name
}


rsyslogCatLogFileFromPointer() {
  local file="$1"
  local var_name="file_${file//[^[:alnum:]]/_}_bytes"
  local bytes=${!var_name}
  [[ -z "$bytes" ]] && bytes=0
  tail -c +$bytes "$1"
}

# wait until a file is growing or the pattern is found
# $1 - file to monitor
# $2 - pattern to search for, do not search for it if empty
# $3 - overall timeout for waiting
# $4 - interval in seconds for checking the file size has increased
# $5 - optional command, result 0 equals to pattern match
#
# returns:
# 0 - if pattern found
# 1 - file has stopped to grow
# 2 - waiting timed out
rsyslogWaitTillGrowing() {
  local file pattern fsize fsize_prev time_end timeout interval res=0 time_check_size init_size i command
  file="$1"
  local var_name="file_${file//[^[:alnum:]]/_}_bytes"
  pattern="$2"
  timeout="${3:-300}"
  interval="${4:-15}"
  command="$5"
  init_size=${!var_name}
  fsize_prev=0
  [[ -z "$init_size" ]] && init_size=0
  let time_end=$(date +%s)+$timeout
  let time_check_size=$(date +%s)+$interval
  rlLog "wait till file $file is growing, timeout $timeout sec."
  [[ -n "$pattern" ]] && {
    rlLog " or pattern '$pattern' is found"
  }
  [[ -n "$command" ]] && {
    rlLog " or '$command' returns 0"
  }
  progressHeader $timeout
  i=1
  while :; do
    progressDraw $((i++))
    let fsize=$(stat -c '%s' $file)+1
    [[ -n "$pattern" ]] && {
      LogMore "looking for pattern"
      tail -c +$init_size $file | grep -qE -- "$pattern" && {
        res=0
        LogDebug "pattern '$pattern' found, exitting the loop"
        break
      }
    }
    [[ -n "$command" ]] && {
      LogMore "executing command"
      eval "$command" && {
        res=0
        LogDebug "command execution finished with $res exit code, exitting the loop"
        break
      }
      LogMore "command execution finished with non-zero exit code, continuing"
    }
    [[ $(date +%s) -ge $time_check_size ]] && {
      LogDebug "checking if the file grows, comparing current size '$fsize' with the previous one '$fsize_prev'"
      [[ $fsize_prev -eq $fsize ]] && {
        res=1
        LogDebug "file did not grow, exitting the loop"
        break
      }
      let time_check_size=$(date +%s)+$interval
      LogDebug "file grew, will check in $interval seconds again"
    }
    [[ $(date +%s) -ge $time_end ]] && {
      res=2
      LogDebug "timed out"
      break
    }
    fsize_prev=$fsize
    sleep 1
  done
  progressFooter
  return $res
}


# check for delivered messages, report duplicate messages and missing messages
# the data are taken from the stdin as white-space separated values
#
# usage:
#     grep -Eo 'Hello from message number [0-9]+-' $TMPFILE | grep -Eo '[0-9]+' | rsyslogCheckDeliveredNumbers 2000
#
# $1 - max expected number
# $2 - min expected number, defaults to 1
#
# retruns:
# 00b _ all the messages are present exactly $1 times
# ||___ there are some duplicates
# \____ there are some missing messages
#
rsyslogCheckDelivered() {
  local res=0 count msgs missing duplicates min=${2:-1} max=$1 i j
  msgs=( $(cat - | sort -n) )
  LogMore "processing numbers '${msgs[*]}'"
  missing=()
  duplicates=()
  progressHeader $max $min
  j=0
  for ((i=min; i<max; i++)); do
    progressDraw $i
    count=0
    while [[ "$i" == "${msgs[j]}" ]]; do
      let j++
      let count++
    done
    [[ $count -eq 0 ]] && {
      missing+=("$i")
      res=$((res | 2))
    }
    [[ $count -gt 1 ]] && {
      duplicates+=("$i")
      res=$((res | 1))
    }
  done
  progressFooter
  rlLogInfo "number of delivered: ${#msgs[@]}"
  [[ ${#missing[@]} -gt 0 ]] && rlLogWarning "missing: $(echo "${missing[*]}" | sed 's/ /, /g')"
  [[ ${#duplicates[@]} -gt 0 ]] && rlLogWarning "duplicit: $(echo "${duplicates[*]}" | sed 's/ /, /g')"
  return $res
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

rsyslogLibraryLoaded() {
  echo -n "initiating library $__INTERNAL_rsyslog_LIB_NAME v$__INTERNAL_rsyslog_LIB_VERSION... "
  local YUM=dnf
  local i=''
  which $YUM &>/dev/null || YUM=yum
  which patch &>/dev/null || {
    rlLogInfo "patch not available, will try to install it"
    i+=" patch"
  }
  which semanage &>/dev/null || {
    rlLogInfo "semanage not available, will try to install it"
    i+=" /usr/sbin/semanage"
  }
  __INTERNAL_rsyslog_import
  rpm -q rsyslog${rsyslogSuffix} &>/dev/null || {
    rlLogInfo "rsyslog${rsyslogSuffix} not installed, will try to install it"
    i+=" rsyslog"
  }
  local res=0
  [[ -n "$i" ]] && {
    rlRun "$YUM -y install$i"
  }
  which patch &>/dev/null || {
    let res++
    rlFail "tool patch not available"
  }
  rpm -q rsyslog${rsyslogSuffix} &>/dev/null || {
    let res++
    rlFail "rsyslog package not installed"
  }
  echo "done."
  return $res
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo "done."
