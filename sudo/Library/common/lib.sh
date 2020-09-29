#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/sudo/Library/common
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
#   library-prefix = sudo
#   library-version = 11
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

library(sudo/common) - A library for manipulation with sudoers entries locally and in ldap via sudo-ldap or sssd.

=head1 DESCRIPTION

This is a sudo library that should make easier to manipulate with sudoers
entries in ldap. It provides functions for creating,modifying
and deleting sudoers entries. When you use sudoers in ldap then it setups
necesary client,nsswitch.conf and pam.

Library backups files in dependence of used sudo providers (ldap,sss).

If you want to use suders in ldap then you have to install sssd or
nss-pam-ldapd package as a client for access to ldap in sudoers,
openldap-clients for manipulation with ldap entries and set ldap
variables with necessary information. SSSD sudoers entries can be used
only with ldap users. Combination of sudoers in ldap and users in local
machine doesn't work.

Function uses sudoers rules only from currently setupped sudo provider.
E.g. use case when you want use rules from local sudoers and from ldap
isn't supported.

Example test which uses this library is:

/CoreOS/sudo/Sanity/example-test-with-sudo-library

=head1 USAGE

To use this functionality you need to import library sudo/ldap and
add following line to Makefile.

        @echo "RhtsRequires:    library(sudo/common)" >> $(METADATA)

And in the code to include rlImport openldap/basic or just
I<rlImport --all> to import all libraries specified in Makelife.
You should always run sudoldap_cleanup () function in Cleanup phase.
It restores files,services and selinux booleans in dependence of
called sudoldap_switch_sudoers_provider functions parameter.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables.

=over

=item sudoersProfiver

Current sudoers provider.

=back

=cut

# currently set sudoers provider in nsswitch, by default it is empty
sudoersProvider=''

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 FUNCTIONS

=pod

=head2 sudoAddSudoRule

Function adds sudorule with name received as parameter

    sudoAddSudoRule [--nowait] sudoRuleName

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoRuleName

Name for the newly created sudo rule.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoAddSudoRule () {
  local res=0
  rlLogDebug "$FUNCNAME(): begin $*"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_add_sudorule "$@" || let res++
      ;;
    files)
      rlLogDebug "$FUNCNAME(): preparing local rule $1"
      [[ "$1" == '--nowait' ]] && { local nowait=1; shift; }
      rlLogDebug "$FUNCNAME(): creating '$__INTERNAL_sudoERS_LOCATION/$1'"
      mkdir -p $__INTERNAL_sudoERS_LOCATION/$1 || let res++
      ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


: <<'=cut'
=pod

=head2 sudoDelDudoRule

Function deletes sudorule with name received as parameter

    sudoDelDudoRule [--nowait] sudoRuleName

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoRuleName

Name for the deleted sudo rule.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoDelSudoRule () {
  local res=0
  rlLogDebug "$FUNCNAME(): begin $*"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_del_sudorule "$@" || let res++
      ;;
    files)
      rlLogDebug "$FUNCNAME(): removing local rule $1"
      [[ "$1" == '--nowait' ]] && { local nowait=1; shift; }
      rlLogDebug "$FUNCNAME(): removing '$__INTERNAL_sudoERS_LOCATION/$1'"
      rm -rf $__INTERNAL_sudoERS_LOCATION/$1 || let res++
      ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


true <<'=cut'
=pod

=head2 sudoldap_add_option_sudorule

Function adds specified option with value to given sudorule

    sudoldap_add_option_sudorule [--nowait] sudoRuleName sudoRuleOptionName sudoRuleOptionValue

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoldapRuleName

Name for the modified sudo rule.

=item sudoldapRuleOptionName

Sudo rule option which will be added

=item sudoldapRuleOptionValue

Value for sudo rule option

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

__INTERNAL_sudoersRuleEval() {
  local res=0 nl=$'\n'
  local ruleName="$1"
  local ruleNameUp="${ruleName^^}"
  local rule=""
  local ruleOptionName
  rlLogDebug "$FUNCNAME(): ruleName: $ruleName"
  for ruleOptionName in sudoHost sudoUser sudoCommand sudoRunAsUser sudoRunAsGroup sudoNotAfter sudoNotBefore; do
    eval "local $ruleOptionName=''"
    [[ -r "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOptionName" ]] && {
      eval "local ${ruleOptionName}Present=1"
      eval "$ruleOptionName=\$(cat $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOptionName | tr '\n' ',' | sed 's/,$//')"
    }
    rlLogDebug "$FUNCNAME(): ruleOptionName $ruleOptionName='${!ruleOptionName}'"
  done
  for ruleOptionName in sudoOption; do
    eval "local $ruleOptionName=''"
    [[ -r "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOptionName" ]] && {
      eval "local ${ruleOptionName}Present=1"
      eval "$ruleOptionName=\$(cat $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOptionName)"
    }
    rlLogDebug "$FUNCNAME(): ruleOptionName $ruleOptionName='${!ruleOptionName}'"
  done
  if [[ "$ruleName" == "defaults" && -n "$sudoOption" ]]; then
    local option
    while read -r option; do
      [[ "$option" =~ = && ! "$option" =~ $(echo '=\s*"') && "$option" =~ \  ]] && option="$(echo "$option" | sed -r 's/(.*=)(.*)/\1"\2"/')"
      rule="${rule}Defaults $option${nl}"
    done <<< "$sudoOption"
  elif [[ -n "$sudoUser" && -n "$sudoHost" && -n "$sudoCommand" ]]; then
    local runas="$sudoRunAsUser"
    [[ -n "$sudoRunAsGroup" ]] && {
      sudoRunAsUserPresent='1'
      runas="$runas : $sudoRunAsGroup"
    }
    local option options='' exclam='!'
    [[ -n "$sudoOption" ]] && {
      while read -r option; do
        case $option in
        authenticate)             options="$options PASSWD:"       ;;
        ${exclam}authenticate)    options="$options NOPASSWD:"     ;;
        noexec)                   options="$options NOEXEC:"       ;;
        ${exclam}noexec)          options="$options EXEC:"         ;;
        sudoedit_follow)          options="$options FOLLOW:"       ;;
        ${exclam}sudoedit_follow) options="$options NOFOLLOW:"     ;;
        log_input)                options="$options LOG_INPUT:"    ;;
        ${exclam}log_input)       options="$options NOLOG_INPUT:"  ;;
        log_output)               options="$options LOG_OUTPUT:"   ;;
        ${exclam}log_output)      options="$options NOLOG_OUTPUT:" ;;
        mail_all_cmnds)           options="$options MAIL:"         ;;
        ${exclam}mail_all_cmnds)  options="$options NOMAIL:"       ;;
        setenv)                   options="$options SETENV:"       ;;
        ${exclam}setenv)          options="$options NOSETENV:"     ;;
        type=*)
          [[ "$option" =~ type=(.*) ]] && {
                                  options="$options TYPE=${BASH_REMATCH[1]}" \\
          } || {
            rlLogError "could not parse the option '$option'"
            let res++
          }
          ;;
        role=*)
          [[ "$option" =~ role=(.*) ]] && {
                                  options="$options ROLE=${BASH_REMATCH[1]}" \\
          } || {
            rlLogError "could not parse the option '$option'"
            let res++
          }
          ;;
        *)
          rlLogError "unsupported rule specific option '$option'"
          let res++
          ;;
        esac
      done <<< "$sudoOption"
    }
    [[ -n "$sudoNotAfterPresent" ]] && {
      options+=" NOTAFTER=$sudoNotAfter"
    }
    [[ -n "$sudoNotBeforePresent" ]] && {
      options+=" NOTBEFORE=$sudoNotBefore"
    }
    #if [[ "$sudoUser" =~ , ]]; then
    #  rule="${rule}${nl}User_Alias USER_${ruleNameUp} = ${sudoUser}${nl}${nl}USER_${ruleNameUp}"
    #else
    #  rule="${rule}${nl}$sudoUser"
    #fi
    #rule="${rule} $sudoHost = ${sudoRunAsUserPresent:+"($runas) "}${options:+"$options "}$sudoCommand"
    rule="$sudoUser $sudoHost = ${sudoRunAsUserPresent:+"($runas) "}${options:+"$options "}$sudoCommand${nl}"
  else
    rlLogDebug "$FUNCNAME(): there's not enough data to construct valid sudoers rule"
  fi
  echo -n "$rule"
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}

__INTERNAL_sudoersUpdate() {
  local ruleName="$1"
  local res=0
  local rule
  rule="$(__INTERNAL_sudoersRuleEval "$ruleName")" || let res++
  local line
  if [[ -n "$rule" ]]; then
    echo "$rule" > $__INTERNAL_sudoERS_LOCATION/$ruleName/result
  else
    rm -f $__INTERNAL_sudoERS_LOCATION/$ruleName/result
  fi
  #sort
  local rules=''
  local order filename rulename default_present=0
  while read -r rulename; do
    filename="$__INTERNAL_sudoERS_LOCATION/$rulename"
    [[ -r "$filename/result" ]] || continue
    rlLogDebug "$FUNCNAME(): rulename=$rulename"
    if [[ "$rulename" == "defaults" ]]; then
      order=-1
    elif [[ -r "$filename/ruleOptions/sudoOrder" ]]; then
      order="$(cat $filename/ruleOptions/sudoOrder)"
    else
      order=0
    fi
    rules+="$order $rulename"$'\n'
  done < <(ls -1 $__INTERNAL_sudoERS_LOCATION)
  # sort rules
  rlLogDebug "$FUNCNAME(): rules:\n${rules}___"
  rules=$(echo -n "$rules" | sort -n | cut -d ' ' -f 2)
  rlLogDebug "$FUNCNAME(): sorted rules:\n${rules}___"
  > /etc/sudoers
  while read -r rulename; do
    [[ -z "$rulename" ]] && continue
    echo "# rule $rulename:" >> /etc/sudoers
    cat $__INTERNAL_sudoERS_LOCATION/$rulename/result >> /etc/sudoers || let res++
    echo "" >> /etc/sudoers
  done <<< "$rules"
  rlLogDebug "$FUNCNAME(): /etc/sudoers\n$(cat /etc/sudoers)\n___"
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


function sudoAddOptionToSudoRule () {
  local res=0
  rlLogDebug "$FUNCNAME(): begin $*"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_add_option_sudorule "$@" || let res++
      ;;
    files)
      [[ "$1" == '--nowait' ]] && { local nowait=1; shift; }
      local ruleName="$1" ruleOption="$2" ruleOptionValue="$3"
      [[ -d "$__INTERNAL_sudoERS_LOCATION/$ruleName" ]] || {
        rlLogError "rule '$ruleName' not found"
        let res++
        return $res
      }
      rlLogDebug "$FUNCNAME(): create dir for rule options"
      mkdir -p $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions || let res++
      rlLogDebug "$FUNCNAME(): append value to ruleOption"
      echo "$ruleOptionValue" >> $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption || let res++
      __INTERNAL_sudoersUpdate "$ruleName" || let res++
      ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


: <<'=cut'
=pod

=head2 sudoDelOptionOfSudoRule

Function deletes specified option from given sudorule

    sudoDelOptionOfSudoRule [--nowait] sudoRuleName sudoRuleOptionName [sudoRuleOptionValue]

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoRuleName

Name for the modified sudo rule.

=item sudoRuleOptionName

Sudo rule option which will be deleted

=item sudoRuleOptionValue

Value of sudo rule option which will be deleted. This parameter is optional but it
is useful when rule has more options with the same name but different value.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoDelOptionOfSudoRule () {
  local res=0
  rlLogDebug "$FUNCNAME(): begin $*"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_del_option_sudorule "$@" || let res++
      ;;
    files)
      [[ "$1" == '--nowait' ]] && { local nowait=1; shift; }
      local ruleName="$1" ruleOption="$2" ruleOptionValue="$3"
      [[ -d "$__INTERNAL_sudoERS_LOCATION/$ruleName" ]] || {
        rlLogError "rule '$ruleName' not found"
        let res++
        return $res
      }
      [[ -d "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions" ]] || {
        rlLogError "rule '$ruleName' have not got any options"
        let res++
        return $res
      }
      [[ -r "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption" ]] || {
        rlLogError "specified rule option '$ruleOption' not found"
        let res++
        return $res
      }
      local tmp=''
      [[ -z "$ruleOptionValue" ]] || {
        local found=0
        while read -r line; do
          if [[ $found -eq 0 && "$line" == "$ruleOptionValue" ]]; then
            found=1
            continue
          fi
          tmp+="$line"$'\n'
        done < "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption"
        rlLogDebug "$FUNCNAME(): new options set:\n${tmp}___"
        [[ $found -eq 0 ]] && {
          rlLogError "specified option value '$ruleOptionValue' not found"
          let res++
          return $res
        }
      }
      [[ -n "$tmp" ]] && echo -n "$tmp" > $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption || rm -f $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption
      __INTERNAL_sudoersUpdate "$ruleName" || let res++
      ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}

true <<'=cut'
=pod

=head2 sudoldap_modify_option_sudorule

Function modifies specified option in sudorule.
To modify one value of a multi valued attribute with the ldapmodify command,
you have to perform two operations -delete and then add.

    sudoldap_modify_option_sudorule [--nowait] sudoldapRuleName sudoldapRuleOptionName sudoldapRuleOptionValueOld sudoldapRuleOptionValueNew

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoldapRuleName

Name for the modified sudo rule.

=item sudoldapRuleOptionName

Sudo rule option which will be deleted

=item sudoldapRuleOptionValueOld

Old value of sudo rule option which will be replaced.

=item sudoldapRuleOptionValueNew

New value of sudo rule option which will be replaced.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoModifyOptionOfSudoRule () {
  local res=0
  rlLogDebug "$FUNCNAME(): begin $*"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_modify_option_sudorule "$@" || let res++
      ;;
    files)
      [[ "$1" == '--nowait' ]] && { local nowait=1; shift; }
      local ruleName="$1" ruleOption="$2" ruleOptionOldValue="$3" ruleOptionNewValue="$4"
      [[ -d "$__INTERNAL_sudoERS_LOCATION/$ruleName" ]] || {
        rlLogError "rule '$ruleName' not found"
        let res++
        return $res
      }
      [[ -d "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions" ]] || {
        rlLogError "rule '$ruleName' have not got any options"
        let res++
        return $res
      }
      [[ -r "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption" ]] || {
        rlLogError "specified rule option '$ruleOption' not found"
        let res++
        return $res
      }
      local tmp=""
      local found=0
      while read -r line; do
        if [[ $found -eq 0 && "$line" == "$ruleOptionOldValue" ]]; then
          found=1
          continue
        fi
        tmp+="$line"$'\n'
      done < "$__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption"
      tmp+="$ruleOptionNewValue"$'\n'
      rlLogDebug "$FUNCNAME(): new options set:\n${tmp}___"
      [[ $found -eq 0 ]] && {
        rlLogError "specified option value '$ruleOptionOldValue' not found"
        let res++
        return $res
      }
      echo -n "$tmp" > $__INTERNAL_sudoERS_LOCATION/$ruleName/ruleOptions/$ruleOption
      __INTERNAL_sudoersUpdate "$ruleName" || let res++
      ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


: <<'=cut'
=pod

=head2 sudoSetup

Backup all relevant files, services, etc.

    sudoSetup

=cut

function sudoSetup () {
  local res=0
  rlLog "Backup files..."
  rlFileBackup --clean --namespace sudoCommon /etc/nsswitch.conf /etc/sudo.conf /etc/sudoers /etc/sudoers.d/ || let res++
  if rlIsRHEL '<7'; then
    rlFileBackup --clean "/etc/ldap.conf"
  else
    rlFileBackup --clean /etc/sudo-ldap.conf
  fi
  __INTERNAL_sudoERS_LOCATION="$BEAKERLIB_DIR/sudoers"
  mkdir -p $__INTERNAL_sudoERS_LOCATION || let res++
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


: <<'=cut'
=pod

=head2 sudoCleanup

Restore all relevant files, services, etc.

    sudoCleanup

=cut

function sudoCleanup () {
  local res=0
  rlLog "Restore files..."
  rlFileRestore --namespace sudoCommon || let res++
  [[ -n "$__INTERNAL_sudoSwitchProvider_used" ]] && {
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_cleanup || let res++
  }
  rm -rf "$__INTERNAL_sudoERS_LOCATION" || let res++
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


: <<'=cut'
=pod

=head2 sudoSwitchProvider

Function sets given sudoers provider in nsswitch.
If ldap or sss is required then sssd on nss-pam-ldapd+sudo-ldap is set.

    sudoSwitchProvider sudoersProvider

=over

=item sudoersProvider

Name for the sudoers provider which will be set. Possible values are
files, ldap or sss(d).

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoSwitchProvider () {
  local res=0
  sudoersProvider="$1"
  rlLogDebug "$FUNCNAME(): switching sudoers provider to '$sudoersProvider'"
  case $sudoersProvider in
    ldap|sss*)
      rlLogDebug "$FUNCNAME(): handing control over to sudo/ldap library"
      sudoldap_switch_sudoers_provider $sudoersProvider || let res++
      __INTERNAL_sudoSwitchProvider_used=1
    ;;
    files)
      rlLogDebug "$FUNCNAME(): "
      rlLogDebug "$FUNCNAME(): setting nsswitch.conf"
      sed -i '/^sudoers:/d' /etc/nsswitch.conf
      echo "sudoers:    files" >> /etc/nsswitch.conf
      > /etc/sudoers
      rm -f '/etc/sudoers.d/*'
    ;;
    *)
      rlLogError "$FUNCNAME: unsupported provider '$sudoersProvider'"
      let res++
    ;;
  esac
  rlLogDebug "$FUNCNAME(): returning with res=$res"
  return $res
}


# $1 - user
# $2 - password, if empty the password prompt will not be expected
#                (!authenticate is expected)
# $3 - sudo parameters including the command
# $4 - expect part after the command is executed
#      and passowrd is provides eventually
: <<'=cut'
=pod

=head2 sudoRunAsUser

Run a command as user USER using expect script. This also creates a tty.

    sudoRunAsUser USER PASS CMD EXP

=over

=item USER

A user under which the command CMD is executed

=item PASS

A user password to use if the command asks for it.
If empty, no password is expected (means !authenticate must be in place).

=item CMD

Whole command to be executed (including sudo).

=item EXP

An inside of expect after the command is executed.
Might be used to handle password prompt in conjunction of empty PASS.

=back

Returns an exit code of the commad.

=cut
sudoRunAsUser() {
  expect <<EOE
set user {$1}
set pass {$2}
set comm {$3}
set timeout 10
spawn bash
expect_after {
  timeout {puts TIMEOUT; exit 2}
  eof {puts EOF; exit 3}
}
expect {#} {send "su - \$user\r" }
expect {\\\$} {send "\$comm\r" }
if { "\$pass" != "" } {
  expect assword { send -- "\$pass\r" }
}
expect {
  $4
  {\\\$} { send "exit \\\$?\r" }
}
expect {#} { send "exit \\\$?\r" }
expect eof
catch wait result
if { [lindex \$result 2] != 0 } {
  puts "error no. [lindex \$result 3]"
  exit 255
}
exit [lindex \$result 3]
EOE
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

sudoLibraryLoaded() {
    if rpm=$(rpm -q sudo); then
        rlLogDebug "Library sudo/common running with $rpm"
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
