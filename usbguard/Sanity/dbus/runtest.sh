#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /usbguard/Sanity/dbus
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
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

USBGUARD_POLKIT_PATH=/etc/polkit-1/rules.d/60-usbguard.rules

rlRunAs() {
  local user="$1" command="$2"
  shift 2
  rlRun -s "su - $user -c '$command'" "$@"
}

declare -A commands=(
  [setParameter]="/org/usbguard1 org.usbguard1.setParameter"
  [getParameter]="/org/usbguard1 org.usbguard1.getParameter"
  [listRules]="/org/usbguard1/Policy org.usbguard.Policy1.listRules"
  [appendRule]="/org/usbguard1/Policy org.usbguard.Policy1.appendRule"
  [removeRule]="/org/usbguard1/Policy org.usbguard.Policy1.removeRule"
  [applyDevicePolicy]="/org/usbguard1/Devices org.usbguard.Devices1.applyDevicePolicy"
  [listDevices]="/org/usbguard1/Devices org.usbguard.Devices1.listDevices"
)

# Execute usbguard-dbus command($2) with arguments($3) as user($1) and expect return value of $4
# Wait a few seconds after certain actions to take place
dbusSendAs() {
  local user="$1" command="${commands[$2]}" arguments="$3" rc="$4"
  exe="dbus-send --system --print-reply --dest=org.usbguard1 $command $arguments"
  rlRunAs "$user" "$exe" "$rc"

  needWaitCommands=(
    "appendRule" "removeRule" "applyDevicePolicy" "setParameter"
  )
  if [[ " ${needWaitCommands[*]} " =~ " ${2} " ]]; then
    sleep 2
  fi
}

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /etc/usbguard"
    CleanupRegister 'rlRun "rlServiceRestore usbguard"'
    CleanupRegister 'rlRun "rlServiceRestore usbguard-dbus"'
    CleanupRegister 'rlRun "rlServiceStop dbus; rlServiceRestore dbus"'
    CleanupRegister "rlRun 'testUserCleanup'"
    CleanupRegister "rlRun 'rm -rf $rlRun_LOG'"
    rlRun "testUserSetup --fast 5"
    rlRun "usermod -aG ${testUserGroup[1]} ${testUser[4]}"
    rlRun "rlServiceStart 'dbus'"
    rlRun "rlServiceStart 'usbguard'"
    rlRun "rlServiceStart 'usbguard-dbus'"
    sleep 2
    rlRun "rlServiceStatus 'usbguard'"
    rlRun "rlServiceStatus 'usbguard-dbus'"
    rlRun -s "usbguard list-devices | wc -l"
    rlAssertGreaterOrEqual "Device list should be greater or equal to 1" "$(cat $rlRun_LOG)" "1" || rlDie

    # Group[1] can getParameter
    # user[2] can add/remove rule
    # user[3] can apply policy and list devices
    cat >> $USBGUARD_POLKIT_PATH << EOF
polkit.addRule(function(action, subject) {
    if (action.id == "org.usbguard1.getParameter" &&
        subject.isInGroup("${testUserGroup[1]}") ) {
        return polkit.Result.YES;
    }
    if ((action.id == "org.usbguard.Policy1.listRules"
        || action.id == "org.usbguard.Policy1.appendRule"
        || action.id == "org.usbguard.Policy1.removeRule" ) &&
        subject.user=="${testUser[2]}" ) {
        return polkit.Result.YES;
    }
    if ((action.id == "org.usbguard.Devices1.applyDevicePolicy"
        || action.id == "org.usbguard.Devices1.listDevices" ) &&
        subject.user=="${testUser[3]}" ) {
        return polkit.Result.YES;
    }
});
EOF
    rlRun "cat $USBGUARD_POLKIT_PATH" 0 "polkit configuration"
  rlPhaseEnd; }

  rlPhaseStartTest "Check for the presence of PolicyKit actions" && {
    actions=(
      org.usbguard.Devices1.listDevices
      org.usbguard.Devices1.applyDevicePolicy
      org.usbguard.Policy1.appendRule
      org.usbguard.Policy1.listRules
      org.usbguard.Policy1.removeRule
      org.usbguard1.getParameter
      org.usbguard1.setParameter
    )
    for action in "${actions[@]}"; do
      rlRun "pkaction -v -a ${action}"
    done
  rlPhaseEnd; }

  rlGetTestState && {
    rlPhaseStartTest "getParameter and setParameter" && {

      # Root can change ImplicitPolicyTarget
      dbusSendAs "root" "setParameter" "string:ImplicitPolicyTarget string:allow"
      dbusSendAs "root" "getParameter" "string:ImplicitPolicyTarget"
      rlAssertGrep 'string "allow"' $rlRun_LOG
      dbusSendAs "root" "setParameter" "string:ImplicitPolicyTarget string:block"
      dbusSendAs "root" "getParameter" "string:ImplicitPolicyTarget"
      rlAssertGrep 'string "block"' $rlRun_LOG

      # Root can change InsertedDevicePolicy
      dbusSendAs "root" "setParameter" "string:InsertedDevicePolicy string:apply-policy"
      dbusSendAs "root" "getParameter" "string:InsertedDevicePolicy"
      rlAssertGrep 'string "apply-policy"' $rlRun_LOG
      dbusSendAs "root" "setParameter" "string:InsertedDevicePolicy string:block"
      dbusSendAs "root" "getParameter" "string:InsertedDevicePolicy"
      rlAssertGrep 'string "block"' $rlRun_LOG

      # Regular user can not change parameters
      dbusSendAs "${testUser[0]}" "setParameter" "string:ImplicitPolicyTarget string:block" "1-255"
      rlAssertGrep "Not authorized" $rlRun_LOG
      dbusSendAs "${testUser[0]}" "setParameter" "string:InsertedDevicePolicy string:block" "1-255"
      rlAssertGrep "Not authorized" $rlRun_LOG

      dbusSendAs "${testUser[0]}" "getParameter" "string:ImplicitPolicyTarget" "1-255"
      dbusSendAs "${testUser[0]}" "getParameter" "string:InsertedDevicePolicy" "1-255"

      # allow access via primary group
      dbusSendAs "${testUser[1]}" "getParameter" "string:ImplicitPolicyTarget"
      rlAssertNotGrep "Not authorized" $rlRun_LOG

      # allow access via secondary group
      dbusSendAs "${testUser[4]}" "getParameter" "string:ImplicitPolicyTarget"
      rlAssertNotGrep "Not authorized" $rlRun_LOG

    rlPhaseEnd; }

    rlPhaseStartTest "listRules, appendRule and removeRule" && {

      # Append a rule to the end of the ruleset as root
      dbusSendAs "root" "listRules" 'string:""'
      dbusSendAs "root" "appendRule" "string:block uint32:4294967293 boolean:false"
      id=$(tail -1 $rlRun_LOG | awk '{print $NF}')
      dbusSendAs "root" "listRules" 'string:""'
      rlAssertGrep "block" $rlRun_LOG -E

      # Remove a rule from the end of the ruleset as root
      dbusSendAs "root" "removeRule" "uint32:$id"
      dbusSendAs "root" "listRules" 'string:""'
      rlAssertNotGrep "block" $rlRun_LOG -E

      # Append a rule to the end of the ruleset as a regular user
      dbusSendAs "${testUser[0]}" "appendRule" "string:block uint32:4294967293 boolean:false" "1-255"
      rlAssertGrep "Not authorized" $rlRun_LOG

      # Remove a rule from the end of the ruleset as a regualar user
      dbusSendAs "${testUser[0]}" "removeRule" "uint32:$id" "1-255"
      rlAssertGrep "Not authorized" $rlRun_LOG

      dbusSendAs "${testUser[2]}" "appendRule" "string:block uint32:4294967293 boolean:false"
      id=$(tail -1 $rlRun_LOG | awk '{print $NF}')
      rlAssertNotGrep "Not authorized" $rlRun_LOG

      dbusSendAs "${testUser[2]}" "listRules" 'string:""'
      rlAssertNotGrep "Not authorized" $rlRun_LOG

      # Remove a rule from the end of the ruleset as a regualar user
      dbusSendAs "${testUser[2]}" "removeRule" "uint32:$id"
      rlAssertNotGrep "Not authorized" $rlRun_LOG

    rlPhaseEnd; }

    rlPhaseStartTest "listDevices and applyDevicePolicy" && {

      # Block, then allow the first device from the list as root
      dbusSendAs "root" "listDevices" 'string:"match"'
      id=$(grep -P -m 1 'uint32 [0-9]+' $rlRun_LOG | awk '{print $NF}')
      dbusSendAs "root" "applyDevicePolicy" "uint32:$id uint32:1 boolean:false"
      dbusSendAs "root" "applyDevicePolicy" "uint32:$id uint32:0 boolean:false"

      # Block, then allow the first device from the list as a regular user
      dbusSendAs "${testUser[0]}" "applyDevicePolicy" "uint32:$id uint32:1 boolean:false" "1-255"
      dbusSendAs "${testUser[0]}" "applyDevicePolicy" "uint32:$id uint32:0 boolean:false" "1-255"
      rlAssertGrep "Not authorized" $rlRun_LOG

      # Block, then allow the first device from the list as a priviledged user
      dbusSendAs "${testUser[3]}" "listDevices" 'string:"match"'
      rlAssertNotGrep "Not authorized" $rlRun_LOG
      id=$(grep -P -m 1 'uint32 [0-9]+' $rlRun_LOG | awk '{print $NF}')
      dbusSendAs "${testUser[3]}" "applyDevicePolicy" "uint32:$id uint32:1 boolean:false"
      rlAssertNotGrep "Not authorized" $rlRun_LOG
      dbusSendAs "${testUser[3]}" "applyDevicePolicy" "uint32:$id uint32:0 boolean:false"
      rlAssertNotGrep "Not authorized" $rlRun_LOG

    rlPhaseEnd; }
  }

  rlPhaseStartCleanup && {
    CleanupDo
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
