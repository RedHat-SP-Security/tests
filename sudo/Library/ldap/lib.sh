#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/sudo/Library/ldap
#   Description: Basic library for manipulation with sudoers entries in ldap via sudo-ldap or sssd.
#   Author: David Spurek <dspurek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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
#   library-prefix = sudoldap
#   library-version = 10
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

sudo/ldap - Basic library for manipulation with sudoers entries in ldap via sudo-ldap or sssd.

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

        @echo "RhtsRequires:    library(sudo/ldap)" >> $(METADATA)
        @echo "Requires:        sudo" >> $(METADATA)

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

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

=over

=item sudoldap_ldap_sudoers_dn

Sudoers entries are stored under this DN.

=item sudoldap_ldap_server

FQDN or IP address of ldap server with sudoers entries.

=item sudoldap_ldap_user

Ldap user used to authorization during communication with ldap server.

=item sudoldap_ldap_user_pass

Password for ldap user used to authorization during communication with ldap server.

=back

=cut

# currently set sudoers provider in nsswitch, by default it is empty
__INTERNAL_sudoldap_current_sudoers_provider=''
# booleans for setupped sudo providers, they are used to propper backup of files
# Default value is 0.
# 0 - provider setup isn't caled
# 1 - provider setup called
__INTERNAL_sudoldap_ldap_boolean=0
__INTERNAL_sudoldap_sss_boolean=0

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

__INTERNAL_sudoldap_cache_refresh() {
  [ "$__INTERNAL_sudoldap_current_sudoers_provider" = "sss" ] && {
    echo 'waiting 1.25s for cache refresh'
    rm -rf /var/lib/sss/db/*; sleep 1.25s
  }
  return 0
}


true <<'=cut'
=pod

=head1 FUNCTIONS

=pod

=head2 sudoldap_add_sudorule

Function adds sudorule with name received as parameter

    sudoldap_add_sudorule [--nowait] sudoRuleName

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoRuleName

Name for the newly created sudo rule.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoldap_add_sudorule () {
	local sudoldapRuleName
	local nowait
	[[ "$1" == '--nowait' ]] && { nowait=1; shift; }
	if [ -z ${1+x} ]; then
		echo "parameter sudoldapRuleName is missing"
		return 1
	fi
	sudoldapRuleName="$1"
	cat >add.ldif<<EOF
dn: cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn
objectClass: top
objectClass: sudoRole
cn: $sudoldapRuleName
EOF
	[[ -n "$DEBUG" ]] && cat add.ldif
	#rlRun "ldapadd -x -f add.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass" 0
	ldapadd -x -f add.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass
	local res=$?
	[[ $res -ne 0 ]] && rlLogError "ldap update failed"
	rm -f add.ldif
	[[ -z "$nowait" ]] && __INTERNAL_sudoldap_cache_refresh
	return $res
}

true <<'=cut'
=pod

=head2 sudoldap_del_sudorule

Function deletes sudorule with name received as parameter

    sudoldap_del_sudorule [--nowait] sudoRuleName

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoldapRuleName

Name for the deleted sudo rule.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoldap_del_sudorule () {
	local sudoldapRuleName
	local nowait
	[[ "$1" == '--nowait' ]] && { nowait=1; shift; }
	if [ -z ${1+x} ]; then
		echo "parameter sudoldapRuleName is missing"
		return 1
	fi
	sudoldapRuleName="$1"
	#rlRun "ldapdelete -x -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass \"cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn\"" 0
	ldapdelete -x -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass "cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn"
	local res=$?
	[[ $res -ne 0 ]] && rlLogError "ldap update failed"
	[[ -z "$nowait" ]] && __INTERNAL_sudoldap_cache_refresh
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

function sudoldap_add_option_sudorule () {
	local sudosudoldapRuleName
	local sudoldapRuleOptionName
	local sudoldapRuleOptionValue
	local nowait
	[[ "$1" == '--nowait' ]] && { nowait=1; shift; }
	if [ -z ${1+x} ]; then
		echo "parameter sudoldapRuleName is missing"
		return 1
	fi
	if [ -z ${2+x} ]; then
		echo "parameter sudoldapRuleOptionName is missing"
		return 2
	fi
	if [ -z ${3+x} ]; then
		echo "parameter sudoldapRuleOptionValue is missing"
		return 3
	fi
	sudoldapRuleName="$1"
	sudoldapRuleOptionName="$2"
	sudoldapRuleOptionValue="$3"
        cat >modify.ldif<<EOF
dn: cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn
changetype: modify
add: $sudoldapRuleOptionName
$sudoldapRuleOptionName: $sudoldapRuleOptionValue
EOF
        [[ -n "$DEBUG" ]] && cat modify.ldif
        #rlRun "ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass" 0
        ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass
	local res=$?
	[[ $res -ne 0 ]] && rlLogError "ldap update failed"
        rm -f modify.ldif
	[[ -z "$nowait" ]] && __INTERNAL_sudoldap_cache_refresh
	return $res
}

true <<'=cut'
=pod

=head2 sudoldap_del_option_sudorule

Function deletes specified option from given sudorule

    sudoldap_del_option_sudorule [--nowait] sudoldapRuleName sudoldapRuleOptionName sudoldapRuleOptionValue

=over

=item --nowait

Skip all sleeps implemented due to chache refresh.

=item sudoldapRuleName

Name for the modified sudo rule.

=item sudoldapRuleOptionName

Sudo rule option which will be deleted

=item sudoldapRuleOptionValue

Value of sudo rule option which will be deleted. This parameter is optional but it
is useful when rule has more options with the same name but different value.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoldap_del_option_sudorule () {
	local sudoldapRuleName
	local sudoldapRuleOptionName
	local sudoldapRuleOptionValue
	local nowait
	[[ "$1" == '--nowait' ]] && { nowait=1; shift; }
	if [ -z ${1+x} ]; then
		echo "parameter sudoldapRuleName is missing"
		return 1
	fi
	if [ -z ${2+x} ]; then
		echo "parameter sudoldapRuleOptionName is missing"
		return 2
	fi
	sudoldapRuleName="$1"
	sudoldapRuleOptionName="$2"
	sudoldapRuleOptionValue="$3"
        cat >modify.ldif<<EOF
dn: cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn
changetype: modify
delete: $sudoldapRuleOptionName
EOF
        if [ -n "$3" ];then
                echo "$sudoldapRuleOptionName: $3" >> modify.ldif
        fi
        [[ -n "$DEBUG" ]] && cat modify.ldif
        #rlRun "ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass" 0
        ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass
	local res=$?
	[[ $res -ne 0 ]] && rlLogError "ldap update failed"
        rm -f modify.ldif
	[[ -z "$nowait" ]] && __INTERNAL_sudoldap_cache_refresh
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

function sudoldap_modify_option_sudorule () {
	local sudoldapRuleName
	local sudoldapRuleOptionName
	local sudoldapRuleOptionValueOld
	local sudoldapRuleOptionValueNew
	local nowait
	[[ "$1" == '--nowait' ]] && { nowait=1; shift; }
	if [ -z ${1+x} ]; then
		echo "parameter sudoldapRuleName is missing"
		return 1
	fi
	if [ -z ${2+x} ]; then
		echo "parameter sudoldapRuleOptionName is missing"
		return 2
	fi
	if [ -z ${3+x} ]; then
		echo "parameter sudoldapRuleOptionValueOld is missing"
		return 3
	fi
	if [ -z ${4+x} ]; then
		echo "parameter sudoldapRuleOptionValueNew is missing"
		return 4
	fi
	sudoldapRuleName="$1"
	sudoldapRuleOptionName="$2"
	sudoldapRuleOptionValueOld="$3"
	sudoldapRuleOptionValueNew="$4"
        cat >modify.ldif<<EOF
dn: cn=$sudoldapRuleName,$sudoldap_ldap_sudoers_dn
changetype: modify
delete: $sudoldapRuleOptionName
$sudoldapRuleOptionName: $sudoldapRuleOptionValueOld
-
add: $sudoldapRuleOptionName
$sudoldapRuleOptionName: $sudoldapRuleOptionValueNew
EOF
        [[ -n "$DEBUG" ]] && cat modify.ldif
        #rlRun "ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass" 0
        ldapmodify -x -f modify.ldif -H ldap://$sudoldap_ldap_server -D $sudoldap_ldap_user -w $sudoldap_ldap_user_pass
	local res=$?
	[[ $res -ne 0 ]] && rlLogError "ldap update failed"
        rm -f modify.ldif
	[[ -z "$nowait" ]] && __INTERNAL_sudoldap_cache_refresh
	return $res
}

# internal function for check if all necessary variables are set
function __INTERNAL_sudoldap_check_ldap_variables () {
	if [ -z ${sudoldap_ldap_sudoers_dn+x} ]; then
		echo "variable sudoldap_ldap_sudoers_dn isn't set"
		return 1
	fi
	if [ -z ${sudoldap_ldap_server+x} ]; then
		echo "variable sudoldap_ldap_server isn't set"
		return 2
	fi
	if [ -z ${sudoldap_ldap_user+x} ]; then
		echo "variable sudoldap_ldap_user isn't set"
		return 3
	fi
	if [ -z ${sudoldap_ldap_user_pass+x} ]; then
		echo "variable sudoldap_ldap_sudoers_dn isn't set"
		return 4
	fi
	return 0
}

# internal function for nsswitch configuration
function __INTERNAL_sudoldap_nsswitch_conf() {
  grep -q "^services:" /etc/nsswitch.conf || echo "services:" >> /etc/nsswitch.conf
  grep -q "^netgroup:" /etc/nsswitch.conf || echo "netgroup:" >> /etc/nsswitch.conf
  grep -q "^sudoers:" /etc/nsswitch.conf || echo "sudoers:" >> /etc/nsswitch.conf
  [[ "$__INTERNAL_sudoldap_current_sudoers_provider" == "files" ]] && {
    sed -r -i "s/(services:.*)files/\1/g" /etc/nsswitch.conf
    sed -r -i "s/(netgroup:.*)files/\1/g" /etc/nsswitch.conf
  }
  sed -r -i "s/(services:.*)ldap/\1/g;s/(services:.*)sss/\1/g;s/services:/\0 $__INTERNAL_sudoldap_current_sudoers_provider /" /etc/nsswitch.conf
  sed -r -i "s/(netgroup:.*)ldap/\1/g;s/(netgroup:.*)sss/\1/g;s/netgroup:/\0 $__INTERNAL_sudoldap_current_sudoers_provider /" /etc/nsswitch.conf
  sed -r -i "s/(sudoers:).*/\1 $__INTERNAL_sudoldap_current_sudoers_provider/" /etc/nsswitch.conf
  return 0
}

# internal function for check if necessary packages are installed
function __INTERNAL_sudoldap_check_installed_packages () {
	PACKAGES="openldap-clients authconfig"
	if [ $__INTERNAL_sudoldap_current_sudoers_provider == 'ldap' ];then
                if rlIsRHEL '>=6'; then
                    PACKAGES=( ${PACKAGES[@]} "nss-pam-ldapd" )
                else
                    PACKAGES=( ${PACKAGES[@]} "nss_ldap" )
                fi
	fi
	if [ $__INTERNAL_sudoldap_current_sudoers_provider == 'sss' ];then
		PACKAGES=( ${PACKAGES[@]} "sssd" )
		if rlIsRHEL '<=6.5'; then
		    PACKAGES=( ${PACKAGES[@]} "libsss_sudo" )
		else
		    PACKAGES=( ${PACKAGES[@]} "sssd-common" )
		fi

	fi
        rlCheckRequirements "${PACKAGES[@]}" || {
          rlRun "yum install -y ${PACKAGES[*]}" 0-255
          rlRun "rlCheckRequirements ${PACKAGES[*]}"
        }
}

# internal function for backup files that can be modified
function __INTERNAL_sudoldap_backup () {
	# other files that can be modified are backed up by authconfig_setup
	# authconfig_setup backup files that can be modified by authconfig
	# call it only once, e.g. if ldap or sss setup is firstly run
	if [ $__INTERNAL_sudoldap_ldap_boolean -eq 0 ] && [ $__INTERNAL_sudoldap_sss_boolean -eq 0 ] ; then
		rlLog 'sudoldap_backup called'
		# disable nscd cache
		rpm -q nscd && rlServiceStop nscd
		# path to sudo logfile
		rlFileBackup --namespace sudoldap --clean /var/log/sudo.log && rm -f /var/log/sudo.log
		# path to sudo-io logging
		rlFileBackup --namespace sudoldap --clean /var/log/sudo-io/ && rm -rf /var/log/sudo-io
		rlFileBackup --namespace sudoldap --clean /var/db/sudo/

		rlRun "authconfig_setup"
	fi

	if [ $__INTERNAL_sudoldap_current_sudoers_provider == 'ldap' ];then
		if [ $__INTERNAL_sudoldap_ldap_boolean -eq 0 ]; then
			rlFileBackup --namespace sudoldap --clean /etc/sudo-ldap.conf
		fi
	fi

	# set boolens to mark that specific backup was run
	if [ $__INTERNAL_sudoldap_current_sudoers_provider == 'ldap' ];then
		if [ $__INTERNAL_sudoldap_ldap_boolean -eq 0 ]; then
			__INTERNAL_sudoldap_ldap_boolean=1
		fi
	elif [ $__INTERNAL_sudoldap_current_sudoers_provider == 'sss' ];then
		if [ $__INTERNAL_sudoldap_sss_boolean -eq 0 ]; then
			__INTERNAL_sudoldap_sss_boolean=1
		fi
	fi
}

true <<'=cut'
=pod

=head2 sudoldap_cleanup

Function restores files,services and selinux booleans in dependence of
called sudo_switch_sudoers_provider functions parameter
('files' is default).

    sudoldap_cleanup

=cut

function sudoldap_cleanup () {
	if [ $__INTERNAL_sudoldap_ldap_boolean -eq 1 ]; then
	        rlIsRHEL '>=6' && rlRun "rlServiceStop nslcd"
	fi
	if [ $__INTERNAL_sudoldap_sss_boolean -eq 1 ]; then
		rlRun "rlServiceStop sssd"
	fi
	rlRun "authconfig_cleanup"
        rlFileRestore --namespace sudoldap
	if [ $__INTERNAL_sudoldap_ldap_boolean -eq 1 ]; then
	        rlIsRHEL '>=6' && rlRun "rlServiceRestore nslcd"
	fi
	if [ $__INTERNAL_sudoldap_sss_boolean -eq 1 ]; then
	        rlRun "rlServiceRestore sssd"
	fi
        rpm -q nscd && rlServiceRestore nscd
        :
}

true <<'=cut'
=pod

=head2 sudoldap_switch_sudoers_provider

Function sets given sudoers provider in nsswitch.
If ldap or sss is required then sssd on nss-pam-ldapd+sudo-ldap is set.

    sudoldap_switch_sudoers_provider sudoldapSudoersProvider

=over

=item sudoldapSudoersProvider

Name for the sudoers provider which will be set. Possible values are
files, ldap or sss.

=back

Returns 0 when the rule is successfully created, non-zero otherwise.

=cut

function sudoldap_switch_sudoers_provider () {
        local sudoldapSudoersProvider
        local res=0
        if [ -z ${1+x} ]; then
                echo "parameter sudoldapSudoersProvider is missing"
                return 1
        fi
        sudoldapSudoersProvider="$1"
        [[ $sudoldapSudoersProvider =~ 'sss' ]] && sudoldapSudoersProvider='sss'

        if [ $sudoldapSudoersProvider == 'sss' ] || [ $sudoldapSudoersProvider == 'ldap' ]; then
                # change global variable indicates current sudo provider
                __INTERNAL_sudoldap_current_sudoers_provider=$sudoldapSudoersProvider
                # backup necessary files
                __INTERNAL_sudoldap_backup
                if [ $sudoldapSudoersProvider == 'ldap' ]; then
                        __INTERNAL_sudoldap_check_ldap_variables
                        if [ "$?" -gt "0" ]; then
                                rlLogError "Necessary ldap variables aren't set"
                                let res++
                        fi
                        # check if needed packages are installed
                        __INTERNAL_sudoldap_check_installed_packages
                        local sudo_ldap=`sudo -V | grep 'ldap.conf path' | cut -d : -f 2`
                        rlLogInfo "using $sudo_ldap for sudo ldap configuration"

                        # else branch is also applied in Fedora
                        if rlIsRHEL '<6'; then
                                # enable ldap pam auth
                                rlRun "authconfig --disablesssdauth --enableldapauth --update" 0
                                # get ldap base dn from sudoers dn
                                ldap_base_dn=`echo $sudoldap_ldap_sudoers_dn | awk -F 'dc=' '{print "dc="$2"dc="$3}'`
                                cat <<EOF > $sudo_ldap
host $sudoldap_ldap_server
BASE $ldap_base_dn
SUDOERS_BASE $sudoldap_ldap_sudoers_dn
URI ldap://$sudoldap_ldap_server/
ldap_version 3
bind_timelimit 5
bind_policy soft
ssl no
SUDOERS_TIMED true
EOF
                        else
                                # enable ldap pam auth
                                #rlRun "authconfig --disablesssdauth --enableldapauth --enableforcelegacy --update" 0
                                rlRun "acSwitchUserAuth ldap --ldapURI=ldap://$sudoldap_ldap_server"
                                cat <<EOF > $sudo_ldap
host $sudoldap_ldap_server
uri ldap://$sudoldap_ldap_server/
sudoers_base   $sudoldap_ldap_sudoers_dn
#sudoers_debug 2
# enable timed entries for sudoNotBefore and sudoNotAfter testing
SUDOERS_TIMED true
EOF

                                cat <<EOF >/etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://$sudoldap_ldap_server
timelimit 120
bind_timelimit 120
idle_timelimit 3600
ssl no
EOF
                                rlRun "rlServiceStart nslcd && sleep 2" 0
                        fi
                        __INTERNAL_sudoldap_nsswitch_conf
                        # stop sssd service
                        rpm -q sssd && rlServiceStop sssd
                        rpm -q nscd && rlServiceStop nscd
                elif [ $sudoldapSudoersProvider == 'sss' ]; then
                        if rlIsRHEL 5;then
                                rlLogWarning "sudoers in ldap via sssd aren't supported in rhel5"
                        else
                                __INTERNAL_sudoldap_check_ldap_variables
                                if [ "$?" -gt "0" ]; then
                                        rlLogError "Necessary ldap variables aren't set"
                                        let res++
                                fi
                                # check if needed packages are installed
                                __INTERNAL_sudoldap_check_installed_packages

                                # enable sssd pam auth
                                #rlIsRHEL 5 && rlRun "authconfig --disableldapauth --update"
                                #rlRun "authconfig --enablesssdauth --update" 0
                                rlRun "acSwitchUserAuth sss --ldapURI=ldap://$sudoldap_ldap_server"
                                __INTERNAL_sudoldap_nsswitch_conf
                                # configure sssd with sudo
                                cat >/etc/sssd/sssd.conf<<EOF
[sssd]
config_file_version = 2
domains             = LDAP
services            = nss, pam, sudo
#debug_level         = 0xFFFF

[nss]
filter_groups       = root
filter_users        = root
#debug_level         = 0xFFFF

[pam]
#debug_level         = 0xFFFF

[sudo]
#debug_level         = 0xFFFF
sudo_timed          = TRUE

[domain/LDAP]
cache_credentials   = False
id_provider         = ldap
auth_provider       = ldap
sudo_provider       = ldap
#debug_level         = 0xFFFF
ldap_uri            = ldap://$sudoldap_ldap_server

entry_cache_nowait_percentage       = 0
entry_cache_timeout                 = 1
ldap_sudo_smart_refresh_interval    = 0
ldap_sudo_full_refresh_interval     = 1
EOF
                                local NVR=$(rpm -q --qf '%{name}-%{version}-%{release}' sssd)
                                # this should be covered by the config above already
                                #if rlTestVersion "$NVR" '>' "sssd-1.12.4-47.el6" && rlTestVersion "$NVR" '<=' "sssd-1.13.3-17.el6"; then
                                #  rlLog "applying workaround due to bz1312062"
                                #  sed -i '/ldap_sudo_smart_refresh_interval/d;/ldap_sudo_full_refresh_interval/d' /etc/sssd/sssd.conf
                                #  sed -i 's/\[domain\/LDAP\]/\0\nldap_sudo_smart_refresh_interval    = 0\nldap_sudo_full_refresh_interval     = 2/' /etc/sssd/sssd.conf
                                #fi
                                chmod 0600 /etc/sssd/sssd.conf
                                # clear sssd cache
                                rm -rf /var/lib/sss/db/*
                                rlRun "rlServiceStart sssd"
                                # stop nss-pam-ldapd service
                                rlIsRHEL '>=6' && rpm -q nss-pam-ldapd && rlServiceStop nslcd
                                rpm -q nscd && rlServiceStop nscd
                                :
                        fi
                fi
        else
                echo "Unsupported sudo provider passed"
                return 10
        fi
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

sudoldapLibraryLoaded() {
    if rpm=$(rpm -q sudo); then
        rlLogDebug "Library sudo/ldap running with $rpm"
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

David Spurek <dspurek@redhat.com>

=back

=cut
