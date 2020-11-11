#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/sudo/Sanity/sudoers-options-sanity-test
#   Description: This sanity test checks pre-defined (some are commented) options (examples) in sudoers file.
#   Author: Ales Marecek <amarecek@redhat.com>
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

# Include Beaker environment
. /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfTry "Setup phase" && {
      tcfRun "rlCheckMakefileRequires"
      rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
      CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
      CleanupRegister 'rlRun "popd"'
      rlRun "pushd $TmpDir"
      CleanupRegister 'rlRun "rlFileRestore"'
      rlRun "rlFileBackup --clean /etc/sudoers"
      rpm -V sudo | grep /etc/sudoers && {
        # we need clean config file that is shipped with package
        rlRun "rm -rf /etc/sudoers"
        rlRun "rlRpmDownload `rpm -q --qf '%{name} %{version} %{release} %{arch}' sudo`"
        rlRun "yum -y reinstall ./sudo*"
      }; :
      CleanupRegister 'rlRun "testUserCleanup"'
      rlRun "testUserSetup 2"
    tcfFin; }
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest "Active options test - active sudo settings" && {
      _OPTIONS=( "env_reset" )
      if rlIsRHEL; then
        _OPTIONS+=("always_set_home" "!visiblepw")
        if ( rlIsRHEL 6 && rlIsRHEL '<6.8' ) || ( rlIsRHEL 7 && rlIsRHEL '<7.3' ); then
          _OPTIONS+=("requiretty")
        fi
      elif rlIsFedora 20; then
        _OPTIONS+=("requiretty")
      else
        _OPTIONS=("!visiblepw")
      fi

      for _OPTION in ${_OPTIONS[@]}; do
        rlRun "grep -E '^Defaults\>.*\s${_OPTION}' /etc/sudoers" 0 "Test: '${_OPTION}' check"
      done
    rlPhaseEnd; }

    rlPhaseStartTest "Active options test - Evironment" && {
        for _OPTION in DISPLAY HOSTNAME USERNAME LC_COLLATE LC_MESSAGES LC_TIME LC_ALL XAUTHORITY; do
                rlRun "cat /etc/sudoers | grep '^Defaults\s\+env_keep' | grep '${_OPTION}'" 0 "Test: '${_OPTION}' check"
        done
        rlRun "grep '^Defaults\s\+secure_path' /etc/sudoers"
        rlRun "grep '^Defaults\s\+secure_path\s\+=\s\+/sbin:/bin:/usr/sbin:/usr/bin' /etc/sudoers" 0 "Test: 'secure_path' check"
    rlPhaseEnd; }

    rlPhaseStartTest "Commented options test - examples" && {
        for _OPTION in "Host_Alias" "Cmnd_Alias" "User_Alias"; do
                rlRun "grep \"^#.*${_OPTION}.*\" /etc/sudoers" 0 "Test: '${_OPTION}' check"
        done
    rlPhaseEnd; }

    rlPhaseStartTest "pam_service and pam_login_service bz1247231, bz1247230" && {
        CleanupRegister --mark 'rlRun "rlFileRestore --namespace bz1247231"'
        rlRun "rlFileBackup --namespace bz1247231 --clean /etc/pam.d/ /etc/sudoers"
        rlRun "cat /etc/pam.d/sudo > /etc/pam.d/sudo2"
        rlRun "sed -r 's/include.*sudo$/\02/' /etc/pam.d/sudo-i > /etc/pam.d/sudo2-i"
        rlRun "sed -i '/session.*pam_echo/d' /etc/pam.d/sudo"
        rlRun "sed -i '/session.*pam_echo/d' /etc/pam.d/sudo-i"
        rlRun "echo -e 'session\toptional\tpam_echo.so %%sudo pam_service' >> /etc/pam.d/sudo"
        rlRun "echo -e 'session\toptional\tpam_echo.so %%sudo-i pam_login_service' >> /etc/pam.d/sudo-i"
        rlRun "echo -e 'session\toptional\tpam_echo.so %%sudo2 pam_service' >> /etc/pam.d/sudo2"
        rlRun "echo -e 'session\toptional\tpam_echo.so %%sudo2-i pam_login_service' >> /etc/pam.d/sudo2-i"
        sudoers_file="$(cat /etc/sudoers)"
        rlRun -s "unbuffer sudo -s id"
        rlAssertGrep '^%sudo pam_service' $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun -s "unbuffer sudo -i id"
        rlAssertGrep '^%sudo-i pam_login_service' $rlRun_LOG
        rm -f $rlRun_LOG
        tcfChk "change pam service name" && {
          rlRun 'echo "Defaults pam_service=sudo2" > /etc/sudoers'
          rlRun 'echo "Defaults pam_login_service=sudo2-i" >> /etc/sudoers'
          echo "$sudoers_file" >> /etc/sudoers
        tcfFin; }
        rlRun -s "unbuffer sudo -s id"
        rlRun "cat $rlRun_LOG"
        rlAssertGrep '^%sudo2 pam_service' $rlRun_LOG
        rm -f $rlRun_LOG
        rlRun -s "unbuffer sudo -i id"
        rlRun "cat $rlRun_LOG"
        rlAssertGrep '^%sudo2-i pam_login_service' $rlRun_LOG
        rm -f $rlRun_LOG
        CleanupDo --mark
    rlPhaseEnd; }

    rlPhaseStartTest "User and Group settings" && {
        rlRun "grep '^root\s\+ALL=(ALL)\s\+ALL' /etc/sudoers" 0 "Test: 'root' user check"
        # specific "%wheel" command in RHEL-7 - allowing "wheel" group for super-trooper admin-needs by Anaconda
        rlIsRHEL 4 5 6
        [ $? -eq 0 ] && rlRun "grep '^#.*%wheel\s\+ALL=(ALL)\s\+ALL' /etc/sudoers" 0 "Test: 'wheel' (commented) group check" || rlRun "grep '^%wheel\s\+ALL=(ALL)\s\+ALL' /etc/sudoers" 0 "Test: 'wheel' group check"
        rlRun "grep '^#.*%sys' /etc/sudoers" 0 "Test: 'sys' (commented) group check"
    rlPhaseEnd; }

    ! rlIsRHEL '<6' && rlPhaseStartTest 'env_check' && {
      tcfChk "env_check" && {
        tcfChk "setup phase" && {
          rlRun "cat /etc/sudoers > sudoers"
          CleanupRegister "
            rlRun 'cat sudoers > /etc/sudoers'
            rlRun \"export TZ='${TZ}'\"
          "
          clean_sudoers=$CleanupRegisterID
          rlRun "echo 'Defaults env_check += \"TZ\"' >> /etc/sudoers"
          rlRun "echo 'Defaults env_keep += \"TZ\"' >> /etc/sudoers"
          rlRun "echo 'Defaults !authenticate' >> /etc/sudoers"
          rlRun "sed -ri 's/(Defaults\s+)(requiretty)/\1!\2/' /etc/sudoers"
          rlRun "cat -n /etc/sudoers | tr '\t' ' ' | grep -Pv '^ +[0-9]+ +(#|$)'"
        tcfFin; }
        tcfTry "test" && {
          tcfChk "test allowed values" && {
            for TZ in AB America/New_York /usr/share/zoneinfo/America/New_York; do
              rlRun "export TZ='$TZ'"
              rlRun -s "env"
              rlAssertGrep "^TZ=$TZ" $rlRun_LOG
              rm -f $rlRun_LOG
              rlRun -s "sudo env"
              rlAssertGrep "^TZ=$TZ" $rlRun_LOG
              rm -f $rlRun_LOG
            done
          tcfFin; }
          tcfChk "test wrong values" && {
            for TZ in "A B" \
                      /etc/hosts \
                      /usr/share/zoneinfo/../zoneinfo/America/New_York \
                      1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 \
                      ; do
              rlRun "export TZ='$TZ'"
              rlRun -s "env"
              rlAssertGrep "^TZ=$TZ" $rlRun_LOG
              rm -f $rlRun_LOG
              rlRun -s "sudo env"
              rlAssertNotGrep "^TZ=$TZ" $rlRun_LOG
              rm -f $rlRun_LOG
            done
          tcfFin; }
        tcfFin; }
        tcfChk "cleanup phase" && {
          CleanupDo $clean_sudoers
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "test, requiretty" && {
      tcfChk && {
        tcfChk "setup" && {
          CleanupRegister --mark 'rlRun "rlFileRestore --namespace requiretty"'
          rlRun "rlFileBackup --clean --namespace requiretty /etc/sudoers"
          rlRun "echo '$testUser ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
        tcfFin; }

        tcfTry && {
          tcfChk "test, requiretty" && {
            rlRun "sed -i '/requiretty/d' /etc/sudoers"
            rlRun "echo 'Defaults    requiretty' >> /etc/sudoers"
            rlRun -s "nohup su -l -c 'sudo id' $testUser > /dev/stdout" 1
            rlAssertGrep 'you must have a tty' $rlRun_LOG
            rm -f $rlRun_LOG
          tcfFin; }

          tcfChk "test, !requiretty" && {
            rlRun "sed -i '/requiretty/d' /etc/sudoers"
            rlRun "echo 'Defaults    !requiretty' >> /etc/sudoers"
            rlRun "nohup su -l -c 'sudo id' $testUser > /dev/stdout"
          tcfFin; }
        tcfFin; }

        tcfChk "cleanup" && {
          CleanupDo --mark
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

   if ! rlIsRHEL '<7.4'; then
    rlPhaseStartTest "test, iolog, bz1389735" && {
      tcfChk && {
        iolog_config() {
          rlLog "create config"
          cat > /etc/sudoers.d/iolog <<EOF
Defaults     !requiretty, iolog_dir=/var/log/sudo-io/%{user}
Defaults     log_output
$1
$testUser    ALL = (ALL) NOPASSWD: LOG_INPUT: LOG_OUTPUT: ALL
EOF
          rlRun "cat /etc/sudoers.d/iolog"
        }
        tcfChk "setup" && {
          CleanupRegister --mark 'rlRun "rlFileRestore --namespace iolog"'
          rlRun "rlFileBackup --clean --namespace iolog /etc/sudoers.d/iolog /etc/sudoers"
          rlRun "rm -rf /var/log/sudo-io"
        tcfFin; }

        tcfTry "test" && {
          tcfChk "test, basic test" && {
            rlRun "rm -rf /var/log/sudo-io"
            iolog_config
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            rlRun -s "ls -laR /var/log/sudo-io"
            rlAssertGrep "drwx------.+root root\s+.*$testUser" $rlRun_LOG -Eq
            rm -f $rlRun_LOG
          tcfFin; }

          tcfChk "test, user test" && {
            rlRun "rm -rf /var/log/sudo-io"
            iolog_config "Defaults iolog_user=$testUser"
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            rlRun -s "ls -laR /var/log/sudo-io"
            if rlIsRHEL 6; then
                rlAssertGrep "drwx------.+$testUser root\s+.*$testUser" $rlRun_LOG -Eq
            else
                # according to man page the owning group should be the default user's group
                # changed/fixed in 7.6 and rhel8
                rlAssertGrep "drwx------.+$testUser $testUserGroup\s+.*$testUser" $rlRun_LOG -Eq
            fi
            rm -f $rlRun_LOG
          tcfFin; }

          tcfChk "test, group test" && {
            rlRun "rm -rf /var/log/sudo-io"
            iolog_config "Defaults iolog_group=$testUserGroup"
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            rlRun -s "ls -laR /var/log/sudo-io"
            rlAssertGrep "drwx------.+root $testUserGroup\s+.*$testUser" $rlRun_LOG -Eq
            rm -f $rlRun_LOG
          tcfFin; }

          tcfChk "test, user+group test" && {
            rlRun "rm -rf /var/log/sudo-io"
            iolog_config "Defaults iolog_group=${testUserGroup[1]}, iolog_user=$testUser"
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            rlRun -s "ls -laR /var/log/sudo-io"
            rlAssertGrep "drwx------.+$testUser ${testUserGroup[1]}\s+.*$testUser" $rlRun_LOG -Eq
            rm -f $rlRun_LOG
          tcfFin; }

          tcfChk "test, mode test" && {
            rlRun "rm -rf /var/log/sudo-io"
            iolog_config "Defaults iolog_mode=770"
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            rlRun -s "ls -laR /var/log/sudo-io"
            rlAssertGrep "drwxrwx---.+root root\s+.*$testUser" $rlRun_LOG -Eq
            rm -f $rlRun_LOG
          tcfFin; }
        tcfFin; }

        tcfChk "cleanup" && {
          CleanupDo --mark
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

    false && rlPhaseStartTest "test, MAIL, NOMAIL, bz1308789" && {
      tcfChk && {
        create_config() {
          rlLog "create config"
          cat > /etc/sudoers.d/test <<EOF
Defaults !requiretty, mailto=emailto@domain.com
${1:+"Defaults $1"}
$testUser    ALL = (ALL) NOPASSWD: $2 ALL
${testUser[1]}    ALL = (ALL) NOPASSWD: ALL
EOF
        }
        clean_mail_queue() {
          which postsuper >& /dev/null && {
            postsuper -d ALL
          }
          [[ -e /var/spool/mqueue/ ]] && [[ -n "$(ls -1 /var/spool/mqueue/)" ]] && {
            rm -rf /var/spool/mqueue/*
          }
        }
        get_last_mail_log() {
          sleep 1
          tail -n +$(($last_line_num + 1)) /var/log/maillog | grep -iv 'connection timed out' > last_mail.log
          mailq >> last_mail.log
          rlRun "cat last_mail.log" 0-255
          clean_mail_queue
          last_line_num=`cat /var/log/maillog | wc -l`
        }
        tcfChk "setup" && {
          CleanupRegister --mark 'rlRun "rlFileRestore --namespace MAIL"'
          rlRun "rlFileBackup --clean --namespace MAIL /etc/sudoers.d/test"
          clean_mail_queue
          get_last_mail_log
        tcfFin; }

        tcfTry "test" && {

          tcfChk "test, mail_always test" && {
            create_config mail_always
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            get_last_mail_log
            rlAssertGrep 'emailto@domain.com' last_mail.log -iq
          tcfFin; }

          tcfChk "test, NOMAIL test" && {
            create_config mail_always NOMAIL:
            last_line_num=`cat /var/log/maillog | wc -l`
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            get_last_mail_log
            rlAssertNotGrep 'emailto@domain.com' last_mail.log -iq
            rlRun "su -c 'sudo /bin/ls /' - ${testUser[1]}" 0
            get_last_mail_log
            rlAssertGrep 'emailto@domain.com' last_mail.log -iq
          tcfFin; }

          tcfChk "test, MAIL test" && {
            create_config '' MAIL:
            last_line_num=`cat /var/log/maillog | wc -l`
            rlRun "su -c 'sudo /bin/ls /' - $testUser" 0
            get_last_mail_log
            rlAssertGrep 'emailto@domain.com' last_mail.log -iq
            rlRun "su -c 'sudo /bin/ls /' - ${testUser[1]}" 0
            get_last_mail_log
            rlAssertNotGrep 'emailto@domain.com' last_mail.log -iq
          tcfFin; }

        tcfFin; }

        tcfChk "cleanup" && {
          CleanupDo --mark
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

    rlPhaseStartTest "test mute unknown defaults, bz1413160" && {
      CleanupRegister --mark 'rlRun "rlFileRestore --namespace bz1413160"'
      rlRun "rlFileBackup --clean --namespace bz1413160 /etc/sudoers.d/test"
      cat > /etc/sudoers.d/test <<EOF
Defaults     blahblah
$testUser    ALL = (ALL) NOPASSWD: ALL
EOF
      rlRun -s "su -c 'sudo id' - $testUser" 0
      rlAssertGrep 'uid=0(root)' $rlRun_LOG
      rlAssertGrep 'unknown defaults entry.*blahblah' $rlRun_LOG
      rm -f $rlRun_LOG
      cat > /etc/sudoers.d/test <<EOF
Defaults     blahblah
Defaults     ignore_unknown_defaults
$testUser    ALL = (ALL) NOPASSWD: ALL
EOF
      rlRun -s "su -c 'sudo id' - $testUser" 0
      rlAssertGrep 'uid=0(root)' $rlRun_LOG
      rlAssertNotGrep 'unknown' $rlRun_LOG
      rm -f $rlRun_LOG
      CleanupDo --mark
    rlPhaseEnd; }
  fi

    ! rlIsRHEL '<8.2' && rlPhaseStartTest 'runas_check_shell, bz1796518' && {
      tcfChk "runas_check_shell" && {
        tcfChk "setup phase" && {
          CleanupRegister --mark "rlRun 'rlFileRestore --namespace runas_check_shell'"
          rlRun 'rlFileBackup --namespace runas_check_shell --clean /etc/sudoers /etc/passwd'
          rlRun "echo 'Defaults !authenticate' >> /etc/sudoers"
          rlRun "echo 'Defaults !requiretty' >> /etc/sudoers"
          rlRun "echo '$testUser ALL=(ALL) ALL' >> /etc/sudoers"
          rlRun "cat -n /etc/sudoers | tr '\t' ' ' | grep -Pv '^ +[0-9]+ +(#|$)'"
          rlRun "usermod --shell '/bin/false' ${testUser[1]}"
          rlRun "sed -r -i '/Defaults.*runas_check_shell/d' /etc/sudoers"
        tcfFin; }
        tcfTry "test" && {
          tcfChk "test default" && {
            rlRun -s "su - $testUser -c 'sudo -u ${testUser[1]} id'"
            rlAssertGrep "uid=[0-9]\+(${testUser[1]})" $rlRun_LOG
            rlAssertNotGrep 'invalid shell' $rlRun_LOG
            rm -f $rlRun_LOG
          tcfFin; }
          tcfChk "test on" && {
            rlRun "sed -r -i 's/^$testUser/Defaults runas_check_shell\n$testUser/' /etc/sudoers"
            rlRun -s "su - $testUser -c 'sudo -u ${testUser[1]} id'" 1-255
            rlAssertNotGrep "uid=[0-9]\+(${testUser[1]})" $rlRun_LOG
            rlAssertGrep 'invalid shell' $rlRun_LOG
            rm -f $rlRun_LOG
          tcfFin; }
          tcfChk "test off" && {
            rlRun "sed -r -i 's/runas_check_shell/!runas_check_shell/' /etc/sudoers"
            rlRun -s "su - $testUser -c 'sudo -u ${testUser[1]} id'"
            rlAssertGrep "uid=[0-9]\+(${testUser[1]})" $rlRun_LOG
            rlAssertNotGrep 'invalid shell' $rlRun_LOG
            rm -f $rlRun_LOG
          tcfFin; }
        tcfFin; }
        tcfChk "cleanup phase" && {
          CleanupDo --mark
        tcfFin; }
      tcfFin; }
    rlPhaseEnd; }

  tcfFin; }

  rlPhaseStartCleanup && {
    tcfChk "Cleanup phase" && {
      CleanupDo
    tcfFin; }
    tcfCheckFinal
  rlPhaseEnd; }

  rlJournalPrintText
rlJournalEnd; }
