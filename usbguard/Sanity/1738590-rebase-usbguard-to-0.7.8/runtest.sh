#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/usbguard/Sanity/1738590-rebase-usbguard-to-0.7.8
#   Description: Test for BZ#1738590 (Rebase USBGUARD to the latest upstream version)
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020 Red Hat, Inc.
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
CONFIG="/etc/usbguard/usbguard-daemon.conf"
RULES="/etc/usbguard/rules.conf"
RULESD="/etc/usbguard/rules.d"
SERVICE_UNIT="/usr/lib/systemd/system/usbguard.service"
CUR_DIR=`pwd`
AUDIT=/var/log/usbguard/usbguard-audit.log

rlJournalStart

    setConfigOption() {
            key=$1
            value=$2
            rlLog "setting config option $key=$value"
            egrep -E "^$key=.*" $CONFIG
            if [ $? -eq 0 ]; then
                sed -i -r  "s|^($key)=.*|\1=$value|" $CONFIG
            else
                echo "$key=$value" >> $CONFIG
            fi
    }

    removeConfigOption() {
        key=$1
        rlLog "removing config option $key"
        sed -i -r "/^$key=/d" /etc/usbguard/usbguard-daemon.conf
    }

    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun "rlImport --all"
        rlAssertExists $CONFIG
        rlAssertExists $RULES
        rlRun "TmpFile=\$(mktemp)" 0 "Creating a temporary file"
        rlRun "rlFileBackup --clean /etc/usbguard $AUDIT"
        rlRun "rlSEBooleanOn usbguard_daemon_write_conf"
        rlRun "rlServiceStart usbguard"
        rlRun "sleep 3s"
    rlPhaseEnd

    # [P0] AC: freeze and unfreeze the daemon using SIGSTOP and SIGCONT does not cause daemon’s failure and exit
    rlPhaseStartTest "Freeze and unfreeze daemon using SIGSTOP+SIGCONT" && {
        DaemonPID=`pgrep usbguard-daemon`
        rlRun "kill -19 $DaemonPID" 0 "Send SIGSTOP(19) signal to usbguard-daemon"
        rlRun "sleep 10s"
        rlRun "kill -18 $DaemonPID" 0 "Send SIGCONT(18) signal to usbguard-daemon"
        rlRun "sleep 3s"
        rlRun "systemctl is-active usbguard.service" 0 "Checking whether usbguard-daemon survived SIGSTOP+SIGCONT"
    rlPhaseEnd; }

    # [P0] AC: the service unit file ReadWritePaths definition contains also path to /etc/usbguard so the daemon can modify the policy file
    rlPhaseStartTest "Service unit file ReadWritePaths definition contains /etc/usbguard/" && {
       rlAssertGrep '^(ReadWritePaths=).*-/etc/usbguard/' $SERVICE_UNIT -E
    rlPhaseEnd; }

    # Allow comments in $RULES file
    #    - [P0] AC: Lines beginning with '#' accepted
    #    - [P0] AC: The content after '#' is ignored
    rlPhaseStartTest "Allow comments in $RULES" && {
        rlRun -s 'usbguard-rule-parser "# Comment test"' 0 "Lines beginning with '#' are accepted by usbguard-rule-parser"
        rlAssertGrep '^OUTPUT: $' $rlRun_LOG -E
    rlPhaseEnd; }

    # rules.d feature
    #    - [P0] AC: daemon configuration accepts RuleFolder option
    #    - [P0] AC: all .conf files located in the directory are processed as it was append to the main rules.conf
    #    - [P1] AC: the naming convention and the order of processing is described in the man page TODO
    rlPhaseStartTest "Feature rules.d" && {
        # rlRun "sed -r -i 's/^RuleFolder=.*//' $CONFIG"
        # rlRun "sed -r -i 's|^(RuleFile)=.*|\1=$CUR_DIR\/rules.conf|' $CONFIG"
        removeConfigOption 'RuleFolder'
        setConfigOption 'RuleFile' "$RULES"
        rlRun "cat $CUR_DIR/rules.conf > $RULES"

        rlServiceStart usbguard
        rlRun "sleep 3s"
        rlRun "systemctl is-active usbguard.service"
        rlRun "usbguard list-rules > $TmpFile"
        # rlRun "sed -r -i 's|^(RuleFile)=.*|\1=$RULES|' $CONFIG"
        # rlRun "echo \"RuleFolder=$CUR_DIR/rules.d/\" >> $CONFIG"
        setConfigOption 'RuleFolder' "$RULESD"
        rlRun "rm -f $RULESD/*"
        rlRun "> $RULES"
        rlRun "cp $CUR_DIR/rules.d/* $RULESD/"
        rlRun "restorecon -Rv /etc/usbguard"
        rlRun "chmod 660 $RULESD/*"
        rlRun "ls -laZ $RULESD"
        t=$(date +"%F %T")
        rlRun "rlServiceStart usbguard" 1-255
        rlRun "sleep 1s"
        rlRun -s "journalctl -u usbguard -a --no-pager -S \"$t\""
        rlAssertGrep "Permissions for.*should be 0600" $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun "systemctl reset-failed usbguard"
        rlRun "chmod 600 $RULESD/*"
        rlRun "ls -laZ $RULESD"
        t=$(date +"%F %T")
        rlRun "rlServiceStart usbguard"
        rlRun "sleep 10s"
        rlRun -s "journalctl -u usbguard -a --no-pager -S \"$t\""
#        rlAssertGrep "Permissions for.*should be 0600" $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun -s "usbguard list-rules"
        rlAssertNotDiffer $TmpFile $rlRun_LOG
        rm -f $rlRun_LOG
        # rlRun "sed -r -i 's/^RuleFolder=.*//' $CONFIG"
        removeConfigOption 'RuleFolder'
        rlRun "rm -f $RULESD/*"
        rlServiceStart usbguard
        rlRun "sleep 3s"
    rlPhaseEnd; }

  #[[ -z "$BASEOS_CI" ]] && {
  true && {
    # [P1] AC: AuthorizedDefault is accepted in $CONFIG
    # [P2] AC: Accepted values are: keep, none, all, internal
    rlPhaseStartTest "AuthorizedDefault config option" && {
        since=$(date +"%F %T")
        setConfigOption 'AuthorizedDefault' 'all'
        rlServiceStart usbguard
        rlRun "sleep 2s"
        rlRun "systemctl -l --no-pager status usbguard"
        rlRun "usbguard list-devices"
        rlRun -s "journalctl -u usbguard -l --since '$since' --no-pager"
        rlAssertNotGrep "code=dumped" $rlRun_LOG
        rlAssertNotGrep "code=killed" $rlRun_LOG
        rm -f $rlRun_LOG

        since=$(date +"%F %T")
        setConfigOption 'AuthorizedDefault' 'none'
        rlServiceStart usbguard
        rlRun "sleep 2s"
        rlRun "systemctl -l --no-pager status usbguard"
        rlRun "usbguard list-devices"
        rlRun -s "journalctl -u usbguard -l --since '$since' --no-pager"
        rlAssertNotGrep "code=dumped" $rlRun_LOG
        rlAssertNotGrep "code=killed" $rlRun_LOG
        rm -f $rlRun_LOG

        since=$(date +"%F %T")
        setConfigOption 'AuthorizedDefault' 'keep'
        rlServiceStart usbguard
        rlRun "sleep 2s"
        rlRun "systemctl -l --no-pager status usbguard"
        rlRun "usbguard list-devices"
        rlRun -s "journalctl -u usbguard -l --since '$since' --no-pager"
        rlAssertNotGrep "code=dumped" $rlRun_LOG
        rlAssertNotGrep "code=killed" $rlRun_LOG
        rm -f $rlRun_LOG

        since=$(date +"%F %T")
        setConfigOption 'AuthorizedDefault' 'internal'
        rlServiceStart usbguard
        rlRun "sleep 2s"
        rlRun "systemctl -l --no-pager status usbguard"
        rlRun "usbguard list-devices"
        rlRun -s "journalctl -u usbguard -l --since '$since' --no-pager"
        rlAssertNotGrep "code=dumped" $rlRun_LOG
        rlAssertNotGrep "code=killed" $rlRun_LOG
        rm -f $rlRun_LOG

        removeConfigOption 'AuthorizedDefault'
        rlServiceStart usbguard
        rlRun "sleep 2s"
        cp $CONFIG /tmp/A
    rlPhaseEnd; }

    # {allow, block, reject}-device command can handle rule as a param and not only its ID
    #     [P2] AC: commands allow, block, and reject accept a rule as a input
    #     [P2] AC: all devices matching the rule are allowed, blocked, and rejected, respectively
    #     [P3] AC: if -p is used, rules for all the matching devices will be added to the policy file
    rlPhaseStartTest "{allow, block, reject}-device can handle rule as a parameter, bz1852568" && {
        rlRun "usbguard list-devices"
        echo -n '' > $RULES
        # Get first device rule of the list and remove via-port attribute
        # because it is not gonna be saved when using -p option
        # Method 1
        rule_unformatted="$(usbguard list-devices | grep -m1 "" | cut -d' ' -f3- | sed 's/[[:space:]]*via-port "[^"]*"//')"; # '
        # Escape " character, e.g. "usb-1" => \"usb-1\"
        rule="$(echo $rule_unformatted | sed -r 's/"/\\"/g')"

        rlRun "usbguard allow-device match $rule" 0 "Allowing(temporarily) the first device in the usbguard list-devices list"
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "allow" $rlRun_LOG
        rlRun "usbguard list-devices"

        rlRun "usbguard block-device allow $rule" 0 "Blocking(temporarily) the first device in the usbguard list-devices list"
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "block" $rlRun_LOG

        rlRun "usbguard allow-device -p block $rule" 0 "Allowing(permanently) the first device in the usbguard list-devices list"
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "allow" $rlRun_LOG
        rlAssertGrep "allow $rule_unformatted" $RULES
        rlRun "usbguard list-devices"

        echo -n '' > $RULES

        # Method 2
        rule='id *:*'
        rlRun "usbguard allow-device match $rule" 0 "Allowing(temporarily) every single device in the usbguard list-devices list"
        rlRun -s "usbguard list-devices"
        rlAssertGrep 'allow' $rlRun_LOG
        rlAssertNotGrep '(reject|block)' $rlRun_LOG

        rlRun "usbguard block-device allow $rule" 0 "Blocking(temporarily) every single device in the usbguard list-devices list"
        rlRun -s "usbguard list-devices"
        rlAssertGrep 'block' $rlRun_LOG
        rlAssertNotGrep '(allow|reject)' $rlRun_LOG

        rlRun "usbguard allow-device -p block $rule" 0 "Allowing(permanently) every single device in the usbguard list-devices list"
        rlAssertGreaterOrEqual "$RULES should contain the previously added rule" "`cat $RULES | wc -l`" 1

        echo -n '' > $RULES
    rlPhaseEnd; }

    rlPhaseStartTest "{allow, block, reject}-device can handle rule as one parameter" && {
        rlRun "usbguard list-devices"
        echo -n '' > $RULES
        # Get first device rule of the list and remove via-port attribute
        # because it is not gonna be saved when using -p option
        # Method 1
        rule="$(usbguard list-devices | grep -m1 "" | cut -d' ' -f3- | sed 's/[[:space:]]*via-port "[^"]*"//')"; # '

        rlWatchdog "rlRun \"usbguard allow-device 'match \$rule'\" 0 \"Allowing(temporarily) the first device in the usbguard list-devices list\"" 5
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "allow" $rlRun_LOG
        rlRun "usbguard list-devices"

        rlWatchdog "rlRun \"usbguard block-device 'allow \$rule'\" 0 \"Blocking(temporarily) the first device in the usbguard list-devices list\"" 5
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "block" $rlRun_LOG

        rlWatchdog "rlRun \"usbguard allow-device -p 'block \$rule'\" 0 \"Allowing(permanently) the first device in the usbguard list-devices list\"" 5
        rlRun -s "usbguard list-devices | grep -m1 ''"
        rlAssertGrep "allow" $rlRun_LOG
        rlAssertGrep "allow $rule_unformatted" $RULES
        rlRun "usbguard list-devices"

        echo -n '' > $RULES

        # Method 2
        rule='id *:*'
        rlWatchdog "rlRun \"usbguard allow-device 'match \$rule'\" 0 \"Allowing(temporarily) every single device in the usbguard list-devices list\"" 5
        rlRun -s "usbguard list-devices"
        rlAssertGrep 'allow' $rlRun_LOG
        rlAssertNotGrep '(reject|block)' $rlRun_LOG

        rlWatchdog "rlRun \"usbguard block-device 'allow \$rule'\" 0 \"Blocking(temporarily) every single device in the usbguard list-devices list\"" 5
        rlRun -s "usbguard list-devices"
        rlAssertGrep 'block' $rlRun_LOG
        rlAssertNotGrep '(allow|reject)' $rlRun_LOG

        rlWatchdog "rlRun \"usbguard allow-device -p 'block \$rule'\" 0 \"Allowing(permanently) every single device in the usbguard list-devices list\"" 5
        rlAssertGreaterOrEqual "$RULES should contain the previously added rule" "`cat $RULES | wc -l`" 1

        echo -n '' > $RULES
    rlPhaseEnd; }

    # [P2] AC: daemon config option ‘HidePII’ is recognized
    # [P2] AC: if not set, audit messages does contain s/n and device hash
    # [P2] AC: if false, audit messages does contain s/n and device hash
    # [P2] AC: if true, audit messages does not contain s/n and device hash
    rlPhaseStartTest "HidePII config option" && {
        echo '' > $AUDIT
        rlRun "sed -r -i 's/^HidePII=.*//' $CONFIG" 0 "Remove HidePII option from $CONFIG, if it's there"
        rlServiceStart usbguard
        rlRun "sleep 3s"
        rlRun "grep serial $AUDIT | grep hash | grep parent-hash" 0 "$AUDIT should contain serial, hash, parent-hash attributes"
        echo '' > $AUDIT

        rlRun "echo \"HidePII=false\" >> $CONFIG" 0 "Add HidePII=false option to $CONFIG"
        rlServiceStart usbguard
        rlRun "sleep 3s"
        rlRun "grep serial $AUDIT | grep hash | grep parent-hash" 0 "$AUDIT should contain serial, hash, parent-hash attributes"
        echo '' > $AUDIT

        rlRun "sed -r -i 's|^(HidePII)=.*|\1=true|' $CONFIG"
        rlServiceStart usbguard
        rlRun "sleep 3s"
        rlAssertNotGrep "serial" $AUDIT
        rlAssertNotGrep "hash" $AUDIT
        rlAssertNotGrep "parent-hash" $AUDIT
    rlPhaseEnd; }

    # Added support for portX/connect_type attribute
    #   [P2] AC: rule keyword `with-connect-type` is accepted
    #   [P2] AC: following values are accepted: "hardwired", "hotplug", "not used", "unknown", ""
    rlPhaseStartTest "New rule attribute: with-connect-type" && {
        regex='\"[^\"]*\"'
        rlRun -s "usbguard generate-policy | egrep -o \"with-connect-type $regex\" | cut -d' ' -f2-" 0 "Create a list of attributes consisting of only with-connect-type"
        while IFS='' read -r line; do
            regex='^"(hotplug|hardwired|not used|unknown)?"$'
            rlRun "echo $line | egrep $regex" 0 "$line should be match $regex"
        done < $rlRun_LOG
    rlPhaseEnd; }

    # Added temporary option to append-rule
    #   [P2] AC: if `-t` is used the rule is not written to the rules policy file but it is held only in memory so it can be listed
    rlPhaseStartTest "Append rules temporarily: append-rule -t <rule>" && {
        rule='allow with-interface { 08:00:00 07:06:00 }'
        rlRun "cp $RULES $TmpFile" 0 "Saving rules to a temporary file for further processing"
        rlRun "rule_id=`usbguard append-rule -t \"$rule\"`" 0 "Create new temporary rule, which is not going to be stored in $RULES"
        rlAssertNotDiffer $RULES $TmpFile # It means that the new rule was not added to $RULES

        rlRun -s "usbguard list-rules"
        rlAssertGrep "$rule" $rlRun_LOG # It means that the new rule is available in memory
        rlRun "usbguard remove-rule $rule_id" 0 "Removing temporary rule from memory"
    rlPhaseEnd; }

    # [P3] AC: daemon’s output ‘Ignoring unknown UEvent action:.*action={,un}bind’ is printed only in debug mode
    rlPhaseStartTest "Daemon's output is printed only in debug mode" && {
        # TODO
    rlPhaseEnd; }

    # Added devpath option to generate-policy
    # [P3] AC: `usbguard generate-policy -d devices/pci0000:00/0000:00:14.0/usb1`
    #   generates policy only for that specific device, `find /sys/devices | grep 'usb[0-9]\+$'`
    rlPhaseStartTest "New option for: usbguard generate-policy -d" && {
        device_path=`find /sys/devices | grep 'usb[0-9]\+$' | grep -m1 ""`
        device=`echo $device_path | sed 's/\/sys\///'`
        device_name=`cat $device_path/product`
        device_serial=`cat $device_path/serial`
        rlRun -s "usbguard generate-policy -d $device" 0 "Generating policy for a specific device: $device"
        rlAssertGrep "$device_name" "$rlRun_LOG"
        rlAssertGrep "$device_serial" "$rlRun_LOG"
    rlPhaseEnd; }

    # the D-Bus messages contain also with-connect-type attribute
    rlPhaseStartTest "D-BUS messages contain with-connect-type rule attribute" && {
        # TODO
    rlPhaseEnd; }
  }

    rlPhaseStartCleanup
        rlRun "rlServiceRestore usbguard"
        rlRun "rlSEBooleanRestore"
        rlRun "rlFileRestore"
        rlRun "rm -f $TmpFile $rlRun_LOG"
    rlPhaseEnd
    rlJournalPrintText
rlJournalEnd
