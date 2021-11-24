#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/fapolicyd/Sanity/ipa-integration
#   Description: ipa-integration
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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

PACKAGE="fapolicyd"

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport fapolicyd/common" 0 "Import libraries" || rlDie "cannot continue"
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    if rlIsRHEL '8'; then
      CleanupRegister 'rlRun "RpmSnapshotRevert"; rlRun "RpmSnapshotDiscard"'
      CleanupRegister 'rlRun "dnf -y module reset idm"'
      rlRun "dnf -y module reset idm"
      rlRun "RpmSnapshotCreate"
      rlRun "dnf -y module remove idm:client"
      rlRun "dnf -y module install idm:DL1/dns"
    fi
    tcfRun "rlCheckMakefileRequires" || rlDie "cannot continue"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "check trustdb" && {
      rlRun "fapServiceStart"
      rlRun "fapServiceStop"
      rlRun -s "fapolicyd-cli -D | grep /usr/share | grep '\.jar'"
      #rlAssertGrep "" $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
    rlPhaseStartTest "check ipa-server-install" && {
      CleanupRegister --mark 'rlRun "fapCleanup"'
      rlRun "fapSetup"
      CleanupRegister 'rlRun "fapStop"'
      rlRun "fapStart" > /dev/null
      fapServiceOut -b -f
      CleanupRegister "kill $!"
      h=( $(hostname -A) )
      IPA_MACHINE_HOSTNAME=`hostname`
      IPA_MACHINE_HOSTNAME="${h[0]}"
      DOMAIN_NAME=`hostname -d`
      DOMAIN_NAME="$(echo "${h[0]}" | sed 's/^[^.]*\.//')"
      REALM_NAME="TESTREALM.COM"
      DM_PASSWORD="Secret123"
      MASTER_PASSWORD="Secret123"
      ADMIN_PASSWORD="Secret123"
      IP_ADDRESS=`hostname -I | cut -d ' ' -f 1`
      CleanupRegister 'rlRun "ipa-server-install --uninstall --unattended"'
      if rlTestVersion "$(rpm -q ipa-server)" '<' "ipa-server-4.5"; then
        rlRun "ipa-server-install --hostname=$IPA_MACHINE_HOSTNAME -r $REALM_NAME -n $DOMAIN_NAME -p $DM_PASSWORD -P $MASTER_PASSWORD -a $ADMIN_PASSWORD --unattended --ip-address $IP_ADDRESS" 0
      else
        rlRun "ipa-server-install --hostname=$IPA_MACHINE_HOSTNAME -r $REALM_NAME -n $DOMAIN_NAME -p $DM_PASSWORD -a $ADMIN_PASSWORD --unattended --ip-address $IP_ADDRESS" 0
      fi
      CleanupDo --mark
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
