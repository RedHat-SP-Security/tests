#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Regression/bz1878892-unattended-reboots
#   Description: Stress test to test unattended reboots with clevis.
#   Author: Sergio Correia <scorreia@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2020, 2021 Red Hat, Inc.
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

TEMPLATE=ks.cfg.template

export PREFIX=bz1878892
export BASEDIR="/var/tmp/${PREFIX}"
export VM=clevis
export NAME="${PREFIX}"-vm
export SWAPFILE="${BASEDIR}/${PREFIX}"-swapfile
export DISK="${BASEDIR}/${PREFIX}".qcow2
export ARCH="$(uname -m)"

get_compose() {
    if [ -n "${COMPOSE}" ]; then
        rlLogInfo "(get_compose) COMPOSE=${COMPOSE}"
        echo "${COMPOSE}"
        return 0
    fi

    for _f in /root/original-ks.cfg /root/anaconda-ks.cfg; do
        [ -r "${_f}" ] || continue

        if rlIsRHEL '>=8'; then
            _compose=BaseOS
            if _COMPOSE="$(grep "${_compose}" "${_f}" \
                            | sed -e "s@.*\(http:.*${_compose}.*os\).*\$@\1@" \
                            | grep ^http \
                            | sort -u \
                            | tee "${BASEDIR}/composes.log" \
                            | sed -n 1p)" && [ -n "${_COMPOSE}" ]; then
                rlLogInfo "(get_compose) COMPOSE selected was ${_COMPOSE}"
                rlFileSubmit "${BASEDIR}/composes.log"
                echo "${_COMPOSE}"
                return 0
            fi
        fi
    done

    rlLogWarning "(get_compose) unable to select a COMPOSE from initial kickstart files"
    echo ""
    return 1
}

install_virt() {
    if rlIsRHEL '>=8'; then
        if rlIsRHEL '8'; then
            rlRun "dnf -y install virt-install" || return 1
            rlRun "dnf -y module install virt" || return 1
            return 0
        elif rlIsRHEL '9'; then
            rlRun "dnf -y install qemu-kvm libvirt virt-install" || return 1
            return 0
        fi
    fi

    rlLogWarning "(install_virt) Unsupported system: $(cat /etc/os-release)"
    return 1
}

preserve_vm() {
    [ -n "${PRESERVE_VM}" ] && return 0
    rlLogInfo "(preserve_vm) PRESERVE_VM set to 1"
    export PRESERVE_VM=1
}

cmd() {
    [ -z "${1}" ] && return 0
    ssh "${VM}" "${@}"
}

is_unlocked() {
    dev=${1:-}
    [ -z "${dev}" ] && echo "ERROR" && return 0
    luks_uuid="$(cmd cryptsetup luksUUID "${dev}" | sed -e 's/-//g')"
    if cmd test -b /dev/disk/by-id/dm-uuid-*"${luks_uuid}"*; then
        echo "YES"
        return 0
    fi
    echo "NO"
}

wait_for_vm() {
    local _timeout=${1:-120}
    echo "[$(date)] Waiting up to ${_timeout} seconds for VM to respond..." >&2
    rlLogInfo "(wait_for_vm) [$(date)] Waiting up to ${_timeout} seconds for VM to respond..."

    local _start _elapsed
    _start=${SECONDS}
    while /bin/true; do
        cmd ls 2>/dev/null >/dev/null && break
        _elapsed=$((SECONDS - _start))
        [ "${_elapsed}" -gt "${_timeout}" ] && echo "[$(date)] TIMEOUT reached" >&2 && return 1

        sleep 0.1
    done
    _elapsed=$((SECONDS - _start))
    echo "[$(date)] VM is up in ${_elapsed} seconds!" >&2
    rlLogInfo "(wait_for_vm) [$(date)] VM is up in ${_elapsed} seconds!"
    return 0
}

virt_cleanup() {
    if [ -n "${PRESERVE_VM}" ]; then
        rlLogInfo "(virt_cleanup) not destroying VM (PRESERVE_VM=${PRESERVE_VM})"
        return 0
    fi

    virsh destroy "${NAME}" ||:
    virsh undefine "${NAME}" || virsh undefine --nvram "${NAME}" ||:
    [ -e "${DISK}" ] && rlRun "rm -f ${DISK}"
}

create_vm() {
    if ! COMPOSE=$(get_compose) || [ -z "${COMPOSE}" ]; then
        rlDie "No compose; exiting."
    fi

    rlLogInfo "(create_vm) COMPOSE=${COMPOSE}"

    BASEOS="${COMPOSE}"
    APPSTREAM="${COMPOSE/BaseOS/AppStream}"

    KS=ks.cfg

    IFACE="$(nmcli | grep connected | cut -d':' -f1 | grep -vE 'virbr|vnet')"
    IP=$(ip addr show dev "${IFACE}" | grep 'inet ' \
         | awk '{ print $2 }' | cut -d '/' -f 1)
    TANG=$(printf 'http://%s' "${IP}")

    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ssh-keygen -q -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa <<<y 2>&1 >/dev/null
    rm -f ~/.ssh/known_hosts

    cat << EOF > ~/.ssh/config
host clevis
        user root
        hostname 192.168.122.100
        StrictHostKeyChecking no
        ConnectTimeout 20
        PasswordAuthentication no
        PreferredAuthentications publickey
        GSSAPIAuthentication no
EOF
    chmod 600 ~/.ssh/config
    PUBKEY="$(< ~/.ssh/id_rsa.pub)"

    # Updating template.
    CDL=
    PREP_BOOT_PART=
    [ "${ARCH}" = "s390x" ] && CDL='--cdl'
    [ "${ARCH}" = "ppc64le" ] && PREP_BOOT_PART='part prepboot --fstype="PPC PReP Boot" --size=10'

    cat "${TEMPLATE}" \
        | sed -e "s#@CDL@#${CDL}#" \
        | sed -e "s#@PREP_BOOT_PART@#${PREP_BOOT_PART}#" \
        | sed -e "s#@APPSTREAM@#${APPSTREAM}#" \
        | sed -e "s#@BASEOS@#${BASEOS}#" \
        | sed -e "s#@TANGADDR@#${TANG}#" \
        | sed -e "s#@SSHKEY@#${PUBKEY}#" \
        | sed -e "s#@REPOFILES@#${EXTRA_REPOS}#" \
        | sed -e "s#@PREFIX@#${PREFIX}#" \
        > "${KS}"

    rlFileSubmit "${KS}"

    virt_cleanup

    mkdir -p "${BASEDIR}"
    chown qemu.qemu "${BASEDIR}"
    chmod 770 "${BASEDIR}"

    if [ ! -e "${SWAPFILE}" ]; then
        fallocate -l3G "${SWAPFILE}"
        chmod 600 "${SWAPFILE}"
        mkswap "${SWAPFILE}"
        swapon "${SWAPFILE}"
    fi

    console="console=tty0 console=ttyS0,115200n8"
    additional_args=
    extra_args=

    # Network.
    addr="192.168.122.100"
    mask="255.255.255.0"
    gw="192.168.122.1"
    dns="192.168.122.1"
    iface="eth0"

    ip="ip=${addr}::${gw}:${mask}::${iface}:none:${dns}"

    case "${ARCH}" in
    ppc64le)
        console="console=hvc0"
        machine="$(virsh -r capabilities | grep 'machine canonical' \
                   | sort -u | sed -n 1p | cut -d"'" -f2)"
        additional_args="--controller type=scsi,model=virtio-scsi --machine=${machine}"
        extra_args="xive=off"
        ;;
    esac

    rlLogInfo "(create_vm) ip=${ip}"
    rlLogInfo "(create_vm) console=${console}"
    rlLogInfo "(create_vm) additional_args=${additional_args}"
    rlLogInfo "(create_vm) extra_args=${extra_args}"

    virt-install --name="${NAME}" \
        --ram=2560 \
        --boot=uefi ${additional_args} \
        --os-variant=generic \
        --os-type=linux \
        --vcpus=1 \
        --graphics=none \
        --disk=path="${DISK}",size=10,bus=virtio,cache=none,format=qcow2 \
        --location="${BASEOS}" \
        --initrd-inject="${KS}" \
        --extra-args="${console} ${extra_args} ${ip} inst.ks=file:/ks.cfg inst.repo=${BASEOS} net.ifnames=0 biosdevname=0 xrhgb quiet" \
        --serial=pty \
        --console=pty,target_type=virtio \
        --noreboot
}

rlJournalStart
    rlPhaseStartSetup
        export PRESERVE_VM=${PRESERVE_VM:-}
        export EXTRA_REPOS=${EXTRA_REPOS:-}
        export RUNS=${RUNS:-1}

        rlLogInfo "ARCH=${ARCH}"
        rlLogInfo "COMPOSE=${COMPOSE}"
        rlLogInfo "EXTRA_REPOS=${EXTRA_REPOS}"
        rlLogInfo "PRESERVE_VM=${PRESERVE_VM}"
        rlLogInfo "RUNS=${RUNS}"
        rlLogInfo "BASEDIR=${BASEDIR}"

        rlRun -s "env"
        rlFileSubmit "${rlRun_LOG}" "env.txt"

        install_virt || rlDie "Unable to install virtualization; arch is ${ARCH}"
        rlServiceStart libvirtd

        rlRun "yum -y install rng-tools"
        rlServiceStart rngd

        rlRun "yum -y install tang"
        rlServiceStart tangd.socket

        create_vm
        rlRun "virsh start ${NAME}" 0 "Start VM"
    rlPhaseEnd

    i=0
    FAILURES=0
    while [ "${i}" -lt "${RUNS}" ]; do
        i=$((i+1))
        rlPhaseStartTest "Reboot test - #${i}"
            rlRun "virsh reboot ${NAME}" 0 "Reboot - #${i}"
            if ! wait_for_vm 120; then
                FAILURES=$((FAILURES+1))
                rlRun "echo Reboot test #${i} FAILED" 1 "FAILED TEST - #${i}"
                rlLogWarning "Reboot test #${i} (total of ${RUNS} runs) FAILED"
                preserve_vm
            fi
        rlPhaseEnd
    done
    OK=$((RUNS-FAILURES))

    rlPhaseStartCleanup
        rlLogInfo "RUNS: ${RUNS}, PASS: ${OK}, FAIL: ${FAILURES}"
        rlAssertEquals "Check that all ${RUNS} reboot unlocking attempts worked" "${OK}" "${RUNS}"

        rlRun "virt_cleanup"
        if [ -e "${SWAPFILE}" ]; then
            rlRun "swapoff ${SWAPFILE}"
            rlRun "rm -f ${SWAPFILE}"
        fi
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
