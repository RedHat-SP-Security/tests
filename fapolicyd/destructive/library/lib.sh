#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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
#   library-prefix = destructive
#   library-version = 1
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_destructive_LIB_VERSION=1

echo -n "loading library destructive v$__INTERNAL_destructive_LIB_VERSION... "

# --id - sessionID to use, otherwise use the default one
destructiveSetup() {
  while [[ -n "$1" ]]; do
    case $1 in
      --id)
        sessionID=$2
        shift
      ;;
      --)
        shift
        break
    esac
    shift
  done
  local sessionRunTIMEOUT=180 sessionExpectTIMEOUT=600 res=0
  CR=$'\r'
  destructiveVMName=destructiveVM
  if ! virsh list --all | grep -q "$destructiveVMName"; then
    while :; do
      vmRepos=$(vmGetCurrentRepos)
      base=$(echo "$vmRepos" | grep '1$' | grep -im1 'baseos')
      others=$(echo "$vmRepos" | grep -vF "$base" | grep -vF "beaker.engineering.redhat.com" )
      vmRepos="$base"$'\n'"$others"
      vmPrepareKs $destructiveVMName || { let res++; break; }
      vmInstall $destructiveVMName $destructiveVMName.ks || { let res++; break; }

      vmStart $destructiveVMName || { let res++; break; }
      sessionRun true || { let res++; break; }
      sessionSend "virsh console $destructiveVMName --force$CR" || { let res++; break; }
      sessionExpect -nocase "login:" || { let res++; break; }
      sessionSend "root$CR" || { let res++; break; }
      sessionExpect -nocase "password" || { let res++; break; }
      sessionSend "redhat$CR" || { let res++; break; }
      sessionRun 'yum install -y fapolicyd' || { let res++; break; }
      sessionSend "shutdown now$CR" || { let res++; break; }
      sessionWaitAPrompt || { let res++; break; }
      for (( i=0; i<60; i++)); do
        virsh domstate $destructiveVMName | grep -q "shut off" && break
        sleep 1
      done
      vmSnapshotCreate "$destructiveVMName" "snapshot0" || { let res++; break; }
      break
    done
  fi
  while :; do
    vmDestroy $destructiveVMName
    vmSnapshotRevert $destructiveVMName snapshot0 || { let res++; break; }
    vmStart $destructiveVMName || { let res++; break; }
    sessionRun true || { let res++; break; }
    sessionSend "virsh console $destructiveVMName --force$CR" || { let res++; break; }
    sessionExpect -nocase "login:" || { let res++; break; }
    sessionSend "root$CR" || { let res++; break; }
    sessionExpect -nocase "password" || { let res++; break; }
    sessionSend "redhat$CR" || { let res++; break; }
    sessionRun true || { let res++; break; }
    break
  done
  return $res
}


destructiveCleanup() {
  vmDestroy $destructiveVMName
}


destructiveWipe() {
  vmDestroy $destructiveVMName
  vmRemove $destructiveVMName
}


destructiveLibraryLoaded() {
  return 0
}

echo "done."