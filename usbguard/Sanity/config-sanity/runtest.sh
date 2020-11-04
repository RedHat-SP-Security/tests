#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/config-sanity
#   Description: tries out valid and invalid config file keywords
#   Author: Jiri Jaburek <jjaburek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="usbguard"

sl() {
    rlLog "sleep $1"
    sleep $1
}
stop_usbguard() {
    rlRun "systemctl stop usbguard" 0-255
}
restart_usbguard() {
    rlRun "systemctl reset-failed usbguard" 0-255
    rlRun "systemctl restart usbguard" ${1:-0}
}
set_time_since() {
    since=$(date +"%F %T")
    sl 1
}
journal_find_since() {
    sl 2  # unfortunately, journalctl --since has only 1-sec resolution
    rlRun "journalctl --flush"
    sl 1
    # use system log so the test works both on rhel7 and rhel8
    # please update it if/once the destination is changed in rhel8
    #journalctl -u usbguard -o cat --since "$since" | grep "$@"
    rlRun -s "journalctl -u usbguard -l --since '$since' --no-pager"
    [[ -n "$1" ]] && rlAssertGrep "$1" $rlRun_LOG -Eq
    [[ -n "$2" ]] && rlAssertNotGrep "$2" $rlRun_LOG -Eq
    rlAssertNotGrep "code=dumped" $rlRun_LOG
    rlAssertNotGrep "core-dump" $rlRun_LOG
    rm -f $rlRun_LOG
}


usbguardVersion(){
    local name pkg res whole major arg op pattern dots test
    name=usbguard

    rlLogDebug "$FUNCNAME(): querying rpmdb"
    pkg=$(rpm -q "$name" | grep "^usbguard-[0-9][0-9]*" | head -n 1)
    if [[ -z "$pkg" ]]; then
      rlLogError "got no rsyslog package from rpm"
      return 2;
    fi
    rlLogDebug "$FUNCNAME(): got '$pkg' from rpm"

    whole=$(rpm -q $pkg --queryformat '%{version}-%{release}\n')
    major=$(echo $whole |  cut -d '.' -f 1)

    rlLogDebug "$FUNCNAME(): detected $name version '$whole'"

  [[ -z "$1" ]] && {
    rlLogDebug "$FUNCNAME(): no argument provided, returning 0"
    return 0
  }

  rlLogDebug "$FUNCNAME(): processing arguments '$*'"
  for arg in "$@"
  do
    rlLogDebug "$FUNCNAME(): processing argument '$arg'"
    # sanity check - version needs to consist of numbers/dots/<=>
    pattern='^([\<=\>]*)([0-9].*)$'
    [[ "$arg" =~ $pattern ]] || {
      rlLogDebug "$FUNCNAME(): argument '$arg' is not in expected format '$pattern', returning 1"
      return 3
    }

    op="${BASH_REMATCH[1]}"
    arg="${BASH_REMATCH[2]}"
    rlLogDebug "$FUNCNAME(): operator '$op', argument '$arg'"
    if [[ -z "$op" ]]; then
      dots=${arg//[^.]}
      [[ "$whole" =~ [^.]+(.[^.-]+){${#dots}} ]]
      test=${BASH_REMATCH[0]}
      rlLogDebug "$FUNCNAME(): matching '$arg' against '$major' or '$whole' or '$test'"
      if [[ "$arg" == "$major" || "$arg" == "$whole" || "$arg" == "$test" ]]
      then
        rlLogDebug "$FUNCNAME(): match found, returning 0"
        return 0
      fi
    else
      if [[ "$arg" =~ \. ]]; then
        rlLogDebug "$FUNCNAME(): doing comparism of '$whole' '$op' '$arg'"
        rlTestVersion "$whole" "$op" "$arg"
      else
        rlLogDebug "$FUNCNAME(): doing comparism of '$major' '$op' '$arg'"
        rlTestVersion "$major" "$op" "$arg"
      fi
      res=$?
      rlLogDebug "$FUNCNAME(): returning $res"
      return $res
    fi
  done
  rlLogDebug "$FUNCNAME(): no match found, returning 1"
  return 1
}; # end of usbguardVersion()


conf=/etc/usbguard/usbguard-daemon.conf

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport --all" || rlDie 'cannot continue'
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
        rlRun "cp -r ./configs $TmpDir/"
        CleanupRegister 'rlRun "popd"'
        rlRun "pushd $TmpDir"
        CleanupRegister 'rlRun "rlFileRestore"'
        rlRun "rlFileBackup --clean /etc/usbguard/"
        CleanupRegister 'rlRun "rlServiceRestore usbguard"'
        rlRun "rlServiceStart usbguard"
    rlPhaseEnd

    rlPhaseStartTest "default config check" && {
      find_path() {
        local distro ver p
        distro="$(. /etc/os-release; echo "$ID")"
        ver=($(. /etc/os-release; echo "$VERSION_ID" | grep -o '[0-9]\+'))
        rlLogDebug "$FUNCNAME(): distro=$distro, ver=( ${ver[*]} )"
        while :; do
          p="configs/$distro${ver[0]}${ver[1]:+.${ver[1]}}"
          rlLogDebug "$FUNCNAME(): trying path $p"
          [[ -d "$p" ]] && {
            echo "$p"
            return 0
          }
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
      if path=$(find_path); then
        ( cd $path; find . -type f | sed 's/^.//' | sort ) > flist
      else
        rlFail "no version to match against"
      fi

      rlRpmDownload `rpm -q --qf '%{name} %{version} %{release} %{arch}' usbguard` || ( rm -f *.rpm && yumdownloader -y usbguard )
      rlRun "rpm2cpio *.rpm | cpio -idmv"

      rlRun "rpm -qc usbguard | sort | diff -u flist -"
      while read f ; do
        rlRun "diff -Bbwu <(sed -r '/^\s*#/d;/^\s*$/d' ${path}${f}) <(sed -r '/^\s*#/d;/^\s*$/d' .${f}) | sed -r '/^(\+\+\+|---)/d'; (exit \$PIPESTATUS)" 0 "check file ${f}"
      done < flist
    rlPhaseEnd; }

    set_directive() {
      local name="$1" val="$2"
      sed "/^${name}=/d" -i "$conf"
      [ "$val" = "%del%" ] || echo -e "\n${name}=${val}" >> "$conf"
      echo "# grep -n -v -e '^\s*#' -e '^\s*$' \"$conf\""
      grep -n -v -e '^\s*#' -e '^\s*$' "$conf"
      echo "---"
    }

    test_one_directive() {
        local name="$1" val="$2" rc="$3" logstr="$4"
        rlPhaseStartTest "$phase_prefix: $name=$val" && {
            rlLogInfo "trying $name=$val, expecting $rc and journal $logstr"
            stop_usbguard
            set_time_since
            set_directive "${name}" "${val}"
            restart_usbguard "$rc"
            [[ -n "$logstr" ]] && journal_find_since "$logstr"
            rlFileRestore
        rlPhaseEnd; }
    }

    phase_prefix="invalid conf directive name"

    test_one_directive SomeNonexistentDirective 12345 1 \
        "\(E\) Error: parsed key is not in key set: 'SomeNonexistentDirective'"

    phase_prefix="invalid directive value"
    test_one_directive RuleFile /some/nonexistent/file 1 \
        "\(E\) (Configuration|Check permissions): /some/nonexistent/file"
    test_one_directive RuleFile %del% 0 \
        "\(W\) RuleFile not set;"
    test_one_directive ImplicitPolicyTarget non-existent-policy 1 \
        "\(E\) Invalid rule target string"
    test_one_directive PresentDevicePolicy invalid-policy 1 \
        "\(E\) DevicePolicyMethod: invalid-policy: invalid policy method string"
    test_one_directive PresentControllerPolicy invalid-policy 1 \
        "\(E\) DevicePolicyMethod: invalid-policy: invalid policy method string"
    test_one_directive InsertedDevicePolicy invalid-policy 1 \
        "\(E\) DevicePolicyMethod: invalid-policy: invalid policy method string"
    test_one_directive RestoreControllerDeviceState invalidbool 1 \
        "\(E\) Configuration: RestoreControllerDeviceState: Invalid value"
    test_one_directive DeviceManagerBackend invalidend 1 \
        "\(E\) DeviceManager: backend: requested backend is not available"
    test_one_directive IPCAllowedUsers nonexistentusr 0
    test_one_directive IPCAllowedGroups nonexistentgrp 0
    test_one_directive IPCAccessControlFiles /some/nonexistent/dir 1 \
        "\(E\) (loadFiles|getConfigsFromDir: opendir): /some/nonexistent/dir: No such file or directory"
    test_one_directive DeviceRulesWithPort invalidbool 1 \
        "\(E\) Configuration: DeviceRulesWithPort: Invalid value"
    test_one_directive AuditFilePath /some/inaccessible/path/for/new/file 1 \
        "\(E\) AuditFileSink: /some/inaccessible/path/for/new/file: failed to open"
    usbguardVersion ">=0.7.8-7" && \
      test_one_directive AuthorizedDefault wired 1 \
        "\(E\) AuthorizedDefaultType: wired: invalid authorized default type string"


    usbguardVersion ">=1.0.0" && {
      rlPhaseStartSetup "setup rules"
        rlRun "echo 'allow id 1111:*' > /etc/usbguard/rules.conf"
        rlRun "mkdir -p /etc/usbguard/rules.d"
        rlRun "echo 'allow id 2222:*' > /etc/usbguard/rules.d/01-rules.conf"
        rlRun "echo 'allow id 3333:*' > /etc/usbguard/rules.d/00-rules.conf"
        rlRun "chmod 0600 /etc/usbguard/rules.conf /etc/usbguard/rules.d/*"
      rlPhaseEnd

      rlPhaseStartTest "RuleFile only" && {
        stop_usbguard
        set_directive RuleFolder %del% > /dev/null
        set_directive RuleFile /etc/usbguard/rules.conf
        set_time_since
        restart_usbguard
        journal_find_since
        rlRun -s "usbguard list-rules"
        rlAssertGrep '1111:\*' $rlRun_LOG
        rlAssertNotGrep '2222:\*' $rlRun_LOG
        rm -f $rlRun_LOG
      rlPhaseEnd; }

      rlPhaseStartTest "RuleFolder only" && {
        stop_usbguard
        set_directive RuleFolder /etc/usbguard/rules.d > /dev/null
        set_directive RuleFile %del%
        set_time_since
        restart_usbguard
        journal_find_since
        rlRun -s "usbguard list-rules"
        rlAssertNotGrep '1111:\*' $rlRun_LOG
        rlAssertGrep '3333:\*' $rlRun_LOG -Eq
        rlAssertGrep '2222:\*' $rlRun_LOG -Eq
        rm -f $rlRun_LOG
      rlPhaseEnd; }

      rlPhaseStartTest "both RuleFile and RuleFolder - sorting" && {
        stop_usbguard
        set_directive RuleFolder /etc/usbguard/rules.d > /dev/null
        set_directive RuleFile /etc/usbguard/rules.conf
        set_time_since
        restart_usbguard
        journal_find_since
        rlRun -s "usbguard list-rules"
        rlAssertGrep '^1: .*1111:\*' $rlRun_LOG -Eq
        rlAssertGrep '^2: .*3333:\*' $rlRun_LOG -Eq
        rlAssertGrep '^3: .*2222:\*' $rlRun_LOG -Eq
        rm -f $rlRun_LOG
      rlPhaseEnd; }

      rlPhaseStartTest "empty RuleFile only" && {
        stop_usbguard
        set_directive RuleFolder %del% > /dev/null
        set_directive RuleFile /etc/usbguard/rules.conf
        rlRun "echo > /etc/usbguard/rules.conf"
        set_time_since
        restart_usbguard
        journal_find_since
        rlRun -s "usbguard list-rules"
        rlAssertNotGrep '1111:\*' $rlRun_LOG
        rlAssertNotGrep '2222:\*' $rlRun_LOG
        rm -f $rlRun_LOG
      rlPhaseEnd; }

      rlPhaseStartTest "empty RuleFolder only" && {
        stop_usbguard
        set_directive RuleFolder /etc/usbguard/rules.d > /dev/null
        set_directive RuleFile %del%
        rlRun "rm -f /etc/usbguard/rules.d/*"
        set_time_since
        restart_usbguard
        journal_find_since
        rlRun -s "usbguard list-rules"
        rlAssertNotGrep '1111:\*' $rlRun_LOG
        rlAssertNotGrep '2222:\*' $rlRun_LOG
        rlAssertNotGrep '3333:\*' $rlRun_LOG
        rm -f $rlRun_LOG
      rlPhaseEnd; }

    }

    rlPhaseStartCleanup
        CleanupDo
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
