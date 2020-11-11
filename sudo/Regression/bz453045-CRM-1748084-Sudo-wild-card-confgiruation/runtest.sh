#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Regression/bz453045-CRM-1748084-Sudo-wild-card-confgiruation
#   Description: Test for bz453045 (CRM# 1748084 Sudo wild card confgiruation..)
#   Author: Zbysek MRAZ <zmraz@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

# Include rhts environment
. /usr/bin/rhts-environment.sh || :
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="sudo"
SUDOUSER="dalimil"
SUDOUSERPASSWD='p@ssw0rd'
USERS="dalimil adminuser1 adminuser2 adminuser3 adminuser4 adminuser5"
HOST=$(hostname)

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlRun 'rlFileBackup /etc/sudoers'
        for USER in $USERS; do
            id $USER && rlRun "userdel -fr $USER"
            rlRun "useradd $USER" 0 "Adding sudo user"
        done
        rlRun "echo $SUDOUSERPASSWD | passwd --stdin $SUDOUSER" 0 "Adding password for sudo user"
        rlRun "TmpDir=\`mktemp -d\`" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        cat > /etc/sudoers << EOC
Defaults    !authenticate

Cmnd_Alias      DISABLEDADMINS = !/*/*/* *adminuser1*, !/*/*/* *adminuser2*, !/*/*/* *adminuser3*, !/*/*/* *adminuser4*, !/*/*/* *adminuser5* 
Cmnd_Alias      DISABLEDROOT = !/*/*/* *root*, !/*/* *root, !/* *root 
Cmnd_Alias      ENABLEDSTUFF = /usr/bin/passwd [a-zA-z0-9]*, !/usr/bin/passwd root 

User_Alias      RSUDOUSER = $SUDOUSER

RSUDOUSER $HOST = ENABLEDSTUFF, DISABLEDROOT, DISABLEDADMINS 
EOC
        rlAssert0 "Creating sudoers file" $?
        rlRun "su $SUDOUSER -c \"mkdir -p ~/pwtest/bin\""
        rlRun "su $SUDOUSER -c \"ln -s /usr/bin/passwd ~/pwtest/bin/passwd\""
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "su $SUDOUSER -c \"sudo -l\"" 0 "User should ba allowed to use sudo"
        rlRun "su $SUDOUSER -c \"echo $SUDOUSERPASSWD | sudo passwd --stdin root\"" 1-255
        rlRun "su $SUDOUSER -c \"echo $SUDOUSERPASSWD | sudo passwd --stdin adminuser1\"" 1-255
        rlRun "su $SUDOUSER -c \"echo $SUDOUSERPASSWD | sudo passwd --stdin adminuser3\"" 1-255
        rlRun "su $SUDOUSER -c \"cd /home/$SUDOUSER/pwtest/bin && echo $SUDOUSERPASSWD | sudo ./passwd --stdin root\"" 1-255
        rlRun "su $SUDOUSER -c \"cd /home/$SUDOUSER/pwtest/bin && echo $SUDOUSERPASSWD | sudo ./passwd --stdin adminuser2\"" 1-255
        rlRun "su $SUDOUSER -c \"cd /home/$SUDOUSER/pwtest/bin && echo $SUDOUSERPASSWD | sudo ./passwd --stdin adminuser4\"" 1-255
        rlRun "su $SUDOUSER -c \"echo $SUDOUSERPASSWD | sudo /home/$SUDOUSER/pwtest/bin/passwd --stdin root\"" 1-255
        rlRun "su $SUDOUSER -c \"echo $SUDOUSERPASSWD | sudo /home/$SUDOUSER/pwtest/bin/passwd --stdin adminuser5\"" 1-255
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
        rlRun "rlFileRestore"
        for USER in $USERS; do
            rlRun "userdel -fr $USER"
        done
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
