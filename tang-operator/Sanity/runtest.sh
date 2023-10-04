#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang-operator/Sanity
#   Description: Basic functionality tests of the tang operator
#   Author: Martin Zeleny <mzeleny@redhat.com>
#   Author: Sergio Arroutbi <sarroutb@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
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

TO_BUNDLE="15m"
TEST_NAMESPACE_PATH="reg_test/all_test_namespace"
TEST_NAMESPACE_FILE_NAME="daemons_v1alpha1_namespace.yaml"
TEST_NAMESPACE_FILE="${TEST_NAMESPACE_PATH}/${TEST_NAMESPACE_FILE_NAME}"
TEST_NAMESPACE=$(grep -i 'name:' "${TEST_NAMESPACE_FILE}" | awk -F ':' '{print $2}' | tr -d ' ')
TEST_PVSC_PATH="reg_test/all_test_namespace"
TEST_PV_FILE_NAME="daemons_v1alpha1_pv.yaml"
TEST_PV_FILE="${TEST_PVSC_PATH}/${TEST_PV_FILE_NAME}"
TEST_SC_FILE_NAME="daemons_v1alpha1_storageclass.yaml"
TEST_SC_FILE="${TEST_PVSC_PATH}/${TEST_SC_FILE_NAME}"
EXECUTION_MODE=
TO_POD_START=120 #seconds
TO_POD_SCALEIN_WAIT=120 #seconds
TO_LEGACY_POD_RUNNING=120 #seconds
TO_DAST_POD_COMPLETED=240 #seconds (DAST lasts around 120 seconds)
TO_POD_STOP=5 #seconds
TO_POD_TERMINATE=120 #seconds
TO_POD_CONTROLLER_TERMINATE=180 #seconds (for controller to end must wait longer)
TO_SERVICE_START=120 #seconds
TO_SERVICE_STOP=120 #seconds
TO_EXTERNAL_IP=120 #seconds
TO_WGET_CONNECTION=10 #seconds
TO_ALL_POD_CONTROLLER_TERMINATE=120 #seconds
TO_KEY_ROTATION=1 #seconds
TO_ACTIVE_KEYS=60 #seconds
TO_HIDDEN_KEYS=60 #seconds
TO_SERVICE_UP=180 #seconds
ADV_PATH="adv"
QUAY_PATH="quay_secret"
QUAY_FILE_NAME_TO_FILL="daemons_v1alpha1_tangserver_secret_registry_redhat_io.yaml"
QUAY_FILE_NAME_PATH="${QUAY_PATH}/${QUAY_FILE_NAME_TO_FILL}"
QUAY_FILE_NAME_TO_FILL_UNFILLED_MD5="db099cc0b92220feb7a38783b02df897"
OC_DEFAULT_CLIENT="kubectl"
TOP_SECRET_WORDS="top secret"
DELETE_TMP_DIR="YES"

test -z "${VERSION}" && VERSION="latest"
test -z "${DISABLE_BUNDLE_INSTALL_TESTS}" && DISABLE_BUNDLE_INSTALL_TESTS=0
test -z "${IMAGE_VERSION}" && IMAGE_VERSION="quay.io/sec-eng-special/tang-operator-bundle:${VERSION}"
test -n "${DOWNSTREAM_IMAGE_VERSION}" && {
    test -z "${OPERATOR_NAMESPACE}" && OPERATOR_NAMESPACE="openshift-operators"
}
test -z "${OPERATOR_NAMESPACE}" && OPERATOR_NAMESPACE="default"
test -z "${CONTAINER_MGR}" && CONTAINER_MGR="podman"

dumpVerbose() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        rlLog "${1}"
    fi
}

commandVerbose() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        $*
    fi
}

dumpDate() {
    rlLog "DATE:$(date)"
}

dumpInfo() {
    rlLog "HOSTNAME:$(hostname)"
    rlLog "RELEASE:$(cat /etc/redhat-release)"
    test -n "${DOWNSTREAM_IMAGE_VERSION}" && {
        rlLog "DOWNSTREAM_IMAGE_VERSION:${DOWNSTREAM_IMAGE_VERSION}"
    } || rlLog "IMAGE_VERSION:${IMAGE_VERSION}"
    rlLog "OPERATOR NAMESPACE:${OPERATOR_NAMESPACE}"
    rlLog "DISABLE_BUNDLE_INSTALL_TESTS:${DISABLE_BUNDLE_INSTALL_TESTS}"
    rlLog "OC_CLIENT:${OC_CLIENT}"
    rlLog "RUN_BUNDLE_PARAMS:${RUN_BUNDLE_PARAMS}"
    rlLog "EXECUTION_MODE:${EXECUTION_MODE}"
    rlLog "vvvvvvvvv IP vvvvvvvvvv"
    ip a | grep 'inet '
    rlLog "^^^^^^^^^ IP ^^^^^^^^^^"
    #rlLog "vvvvvvvvv IP TABLES vvvvvvvvvv"
    #sudo iptables -L
    #rlLog "Flushing iptables"
    #sudo iptables -F
    #sudo iptables -L
    #rlLog "^^^^^^^^^ IP TABLES ^^^^^^^^^^"
}

minikubeInfo() {
    rlLog "MINIKUBE IP:$(minikube ip)"
    rlLog "vvvvvvvvvvvv MINIKUBE STATUS vvvvvvvvvvvv"
    minikube status
    rlLog "^^^^^^^^^^^^ MINIKUBE STATUS ^^^^^^^^^^^^"
    rlLog "vvvvvvvvvvvv MINIKUBE SERVICE LIST vvvvvvvvvvvv"
    minikube service list
    rlLog "^^^^^^^^^^^^ MINIKUBE SERVICE LIST ^^^^^^^^^^^^"
}

parseAndDumpClient() {
    if [ -z "${TEST_OC_CLIENT}" ];
    then
        OC_CLIENT="${OC_DEFAULT_CLIENT}"
    else
        OC_CLIENT="${TEST_OC_CLIENT}"
    fi
    rlLog "USING CLIENT:${OC_CLIENT}"
}

parseAndDumpMode() {
    if [ -z "${TEST_EXTERNAL_CLUSTER_MODE}" ];
    then
        if [ -n "${TEST_CRC_MODE}" ];
        then
            EXECUTION_MODE="CRC"
        else
            EXECUTION_MODE="MINIKUBE"
        fi
    else
        EXECUTION_MODE="CLUSTER"
    fi
    rlLog "EXECUTION MODE: ${EXECUTION_MODE}"
}

checkClusterStatus() {
    if [ "${EXECUTION_MODE}" == "CRC" ];
    then
        rlRun "crc status | grep OpenShift | awk -F ':' '{print $2}' | awk '{print $1}' | grep -i Running" 0 "Checking Code Ready Containers up and running"
    elif [ "${EXECUTION_MODE}" == "MINIKUBE" ];
    then
        rlRun "minikube status" 0 "Checking Minikube status"
    else
        if [ "${OC_CLIENT}" != "oc" ];
        then
            return 0
        fi
        rlRun "${OC_CLIENT} status" 0 "Checking cluster status"
    fi
    return $?
}

checkPodAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        POD_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" -c)
        dumpVerbose "POD AMOUNT:${POD_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${POD_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

checkPodKilled() {
    local pod_name=$1
    local namespace=$2
    local iterations=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
            "${OC_CLIENT}" -n "${namespace}" get pod "${pod_name}"
        else
            "${OC_CLIENT}" -n "${namespace}" get pod "${pod_name}" 2>/dev/null 1>/dev/null
        fi
        if [ $? -ne 0 ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

checkPodState() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local podname=$4
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      pod_status=$("${OC_CLIENT}" -n "${namespace}" get pod "${podname}" | grep -v "^NAME" | awk '{print $3}')
      dumpVerbose "POD STATUS:${pod_status} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
      if [ "${pod_status}" == "${expected}" ]; then
        return 0
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

checkServiceAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        SERVICE_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" -c)
        dumpVerbose "SERVICE AMOUNT:${SERVICE_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${SERVICE_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

checkServiceUp() {
    local service_ip_host=$1
    local service_ip_port=$2
    local iterations=$3
    local counter
    local http_service="http://${service_ip_host}:${service_ip_port}/adv"
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
            wget -O /dev/null -o /dev/null --timeout=${TO_WGET_CONNECTION} ${http_service}
        else
            wget -O /dev/null -o /dev/null --timeout=${TO_WGET_CONNECTION} ${http_service} 2>/dev/null 1>/dev/null
        fi
        if [ $? -eq 0 ]; then
            return 0
        fi
        counter=$((counter+1))
        dumpVerbose "WAITING SERVICE:${http_service} UP, COUNTER:${counter}/${iterations}"
        sleep 1
    done
    return 1
}

checkActiveKeysAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        ACTIVE_KEYS_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get tangserver -o json | jq '.items[0].status.activeKeys | length')
        dumpVerbose "ACTIVE KEYS AMOUNT:${ACTIVE_KEYS_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${ACTIVE_KEYS_AMOUNT} -eq ${expected} ];
        then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    rlLog "Active Keys Amount not as expected: Active Keys:${ACTIVE_KEYS_AMOUNT}, Expected:[${expected}]"
    return 1
}

checkHiddenKeysAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        HIDDEN_KEYS_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get tangserver -o json | jq '.items[0].status.hiddenKeys | length')
        dumpVerbose "HIDDEN KEYS AMOUNT:${HIDDEN_KEYS_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${HIDDEN_KEYS_AMOUNT} -eq ${expected} ];
        then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    rlLog "Hidden Keys Amount not as expected: Hidden Keys:${HIDDEN_KEYS_AMOUNT}, Expected:[${expected}]"
    return 1
}

getPodNameWithPrefix() {
    local prefix=$1
    local namespace=$2
    local iterations=$3
    local tail_position=$4
    test -z "${tail_position}" && tail_position=1
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local pod_line
      pod_line=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" | grep "${prefix}" | tail -${tail_position} | head -1)
      dumpVerbose "POD LINE:[${pod_line}] POD PREFIX:[${prefix}] COUNTER:[${counter}/${iterations}]"
      if [ "${pod_line}" != "" ]; then
          echo "${pod_line}" | awk '{print $1}'
          dumpVerbose "FOUND POD name:[$(echo ${pod_line} | awk '{print $1}')] POD PREFIX:[${prefix}] COUNTER:[${counter}/${iterations}]"
          return 0
      else
          counter=$((counter+1))
          sleep 1
      fi
    done
    return 1
}

getServiceNameWithPrefix() {
    local prefix=$1
    local namespace=$2
    local iterations=$3
    local tail_position=$4
    test -z "${tail_position}" && tail_position=1
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local service_name
      service_name=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" | grep "${prefix}" | tail -${tail_position} | head -1)
      dumpVerbose "SERVICE NAME:[${service_name}] COUNTER:[${counter}/${iterations}]"
      if [ "${service_name}" != "" ]; then
          dumpVerbose "FOUND SERVICE name:[$(echo ${service_name} | awk '{print $1}')] POD PREFIX:[${prefix}] COUNTER:[${counter}/${iterations}]"
          echo "${service_name}" | awk '{print $1}'
          return 0
      else
          counter=$((counter+1))
          sleep 1
      fi
    done
    return 1
}

getServiceIp() {
    local service_name=$1
    local namespace=$2
    local iterations=$3
    counter=0
    dumpVerbose "Getting SERVICE:[${service_name}](Namespace:[${namespace}]) IP/HOST ..."
    if [ ${EXECUTION_MODE} == "CRC" ];
    then
        local crc_service_ip
        crc_service_ip=$(crc ip)
        dumpVerbose "CRC MODE, SERVICE IP/HOST:[${crc_service_ip}]"
        echo "${crc_service_ip}"
        return 0
    elif [ ${EXECUTION_MODE} == "MINIKUBE" ];
    then
        local minikube_service_ip
        minikube_service_ip=$(minikube ip)
        dumpVerbose "MINIKUBE MODE, SERVICE IP/HOST:[${minikube_service_ip}]"
        echo "${minikube_service_ip}"
        return 0
    fi
    while [ ${counter} -lt ${iterations} ];
    do
        local service_ip
        service_ip=$("${OC_CLIENT}" -n "${namespace}" describe service "${service_name}" | grep -i "LoadBalancer Ingress:" | awk -F ':' '{print $2}' | tr -d ' ')
        dumpVerbose "SERVICE IP/HOST:[${service_ip}](Namespace:[${namespace}])"
        if [ -n "${service_ip}" ] && [ "${service_ip}" != "<pending>" ];
        then
            echo "${service_ip}"
            return 0
        else
            dumpVerbose "PENDING OR EMPTY IP/HOST:[${service_ip}], COUNTER[${counter}/${iterations}]"
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

getServicePort() {
    local service_name=$1
    local namespace=$2
    local service_port
    dumpVerbose "Getting SERVICE:[${service_name}](Namespace:[${namespace}]) PORT ..."
    if [ ${EXECUTION_MODE} == "CLUSTER" ];
    then
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk '{print $5}' | awk -F ':' '{print $1}')
    else
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk '{print $5}' | awk -F ':' '{print $2}' | awk -F '/' '{print $1}')
    fi
    result=$?
    dumpVerbose "SERVICE PORT:[${service_port}](Namespace:[${namespace}])"
    echo "${service_port}"
    return ${result}
}

serviceAdv() {
    ip=$1
    port=$2
    URL="http://${ip}:${port}/${ADV_PATH}"
    local file
    file=$(mktemp)
    ### wget
    COMMAND="wget ${URL} --timeout=${TO_WGET_CONNECTION} -O ${file} -o /dev/null"
    dumpVerbose "CONNECTION_COMMAND:[${COMMAND}]"
    ${COMMAND}
    wget_res=$?
    dumpVerbose "WGET RESULT:$(cat ${file})"
    JSON_ADV=$(cat "${file}")
    dumpVerbose "CONNECTION_COMMAND:[${COMMAND}],RESULT:[${wget_res}],JSON_ADV:[${JSON_ADV}])"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file}"
    else
        jq . -M -a < "${file}" 2>/dev/null
    fi
    jq_res=$?
    rm "${file}"
    return $((wget_res+jq_res))
}

checkKeyRotation() {
    local ip=$1
    local port=$2
    local namespace=$3
    local file1
    file1=$(mktemp)
    local file2
    file2=$(mktemp)
    dumpKeyAdv "${ip}" "${port}" "${file1}"
    rlRun "reg_test/func_test/key_rotation/rotate_keys.sh ${namespace} ${OC_CLIENT}" 0 "Rotating keys"
    rlLog "Waiting:${TO_KEY_ROTATION} secs. for keys to rotate"
    sleep "${TO_KEY_ROTATION}"
    dumpKeyAdv "${ip}" "${port}" "${file2}"
    dumpVerbose "Comparing files:${file1} and ${file2}"
    rlAssertDiffer "${file1}" "${file2}"
    res=$?
    rm -f "${file1}" "${file2}"
    return ${res}
}

dumpKeyAdv() {
    local ip=$1
    local port=$2
    local file=$3
    test -z "${file}" && file="-"
    local url
    url="http://${ip}:${port}/${ADV_PATH}"
    local get_command1
    get_command1="wget ${url} --timeout=${TO_WGET_CONNECTION} -O ${file} -o /dev/null"
    dumpVerbose "DUMP_KEY_ADV_COMMAND:[${get_command1}]"
    ${get_command1}
}

serviceAdvCompare() {
    local ip=$1
    local port=$2
    local ip2=$3
    local port2=$4
    local url
    url="http://${ip}:${port}/${ADV_PATH}"
    local url2
    url2="http://${ip2}:${port2}/${ADV_PATH}"
    local jq_equal=1
    local file1
    local file2
    file1=$(mktemp)
    file2=$(mktemp)
    local jq_json_file1
    local jq_json_file2
    jq_json_file1=$(mktemp)
    jq_json_file2=$(mktemp)
    local command1
    command1="wget ${url} --timeout=${TO_WGET_CONNECTION} -O ${file1} -o /dev/null"
    local command2
    command2="wget ${url2} --timeout=${TO_WGET_CONNECTION} -O ${file2} -o /dev/null"
    dumpVerbose "CONNECTION_COMMAND:[${command1}]"
    dumpVerbose "CONNECTION_COMMAND:[${command2}]"
    ${command1}
    wget_res1=$?
    ${command2}
    wget_res2=$?
    dumpVerbose "CONNECTION_COMMAND:[${command1}],RESULT:[${wget_res1}],json_adv:[$(cat ${file1})]"
    dumpVerbose "CONNECTION_COMMAND:[${command2}],RESULT:[${wget_res2}],json_adv:[$(cat ${file2})]"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file1}" 2>&1 | tee "${jq_json_file1}"
    else
        jq . -M -a < "${file1}" > "${jq_json_file1}"
    fi
    jq_res1=$?
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file2}" 2>&1 | tee "${jq_json_file2}"
    else
        jq . -M -a < "${file2}" > "${jq_json_file2}"
    fi
    jq_res2=$?
    rlAssertDiffer "${jq_json_file1}" "${jq_json_file2}"
    jq_equal=$?
    rm "${jq_json_file1}" "${jq_json_file2}"
    return $((wget_res1+wget_res2+jq_res1+jq_res2+jq_equal))
}

checkStatusRunningReplicas() {
    local counter
    counter=0
    local expected=$1
    local namespace=$2
    local iterations=$3
    while [ ${counter} -lt ${iterations} ];
    do
      local running
      running=$("${OC_CLIENT}" -n "${namespace}" get tangserver -o json | jq '.items[0].status.running | length')
      dumpVerbose "Status Running Replicas: Expected:[${expected}], Running:[${running}]"
      if [ ${expected} -eq ${running} ];
      then
          return 0
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

checkStatusReadyReplicas() {
    local counter
    counter=0
    local expected=$1
    local namespace=$2
    local iterations=$3
    while [ ${counter} -lt ${iterations} ];
    do
      local ready
      ready=$("${OC_CLIENT}" -n "${namespace}" get tangserver -o json | jq '.items[0].status.ready | length')
      dumpVerbose "Status Ready Replicas: Expected:[${expected}], Ready:[${ready}]"
      if [ ${expected} -eq ${ready} ];
      then
          return 0
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

uninstallDownstreamVersion() {
    pushd ${tmpdir}/tang-operator/tools/index_tools
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        ./tang_uninstall_catalog.sh || err=1
    else
        ./tang_uninstall_catalog.sh 1>/dev/null 2>/dev/null || err=1
    fi
    popd || return 1
    return $?
}

installDownstreamVersion() {
    local err=0
    # Download required tools
    pushd ${tmpdir}
    # WARNING: if tang-operator is changed to OpenShift organization, change this
    git clone https://github.com/latchset/tang-operator
    pushd tang-operator/tools/index_tools
    local downstream_version=$(echo ${DOWNSTREAM_IMAGE_VERSION} | awk -F ':' '{print $2}')
    dumpVerbose "Installing Downstream version: ${DOWNSTREAM_IMAGE_VERSION} DOWNSTREAM_VERSION:[${downstream_version}]"
    rlLog "Indexing and installing catalog"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        DO_NOT_LOGIN="1" ./tang_index.sh "${DOWNSTREAM_IMAGE_VERSION}" "${downstream_version}" || err=1
        ./tang_install_catalog.sh || err=1
    else
        DO_NOT_LOGIN="1" ./tang_index.sh "${DOWNSTREAM_IMAGE_VERSION}" "${downstream_version}" 1>/dev/null 2>/dev/null || err=1
        ./tang_install_catalog.sh 1>/dev/null 2>/dev/null || err=1
    fi
    popd || return 1
    popd || return 1
    return $err
}

bundleStart() {
    if [ "${DISABLE_BUNDLE_INSTALL_TESTS}" == "1" ];
    then
      return 0
    fi
    if [ -n "${DOWNSTREAM_IMAGE_VERSION}" ];
    then
      installDownstreamVersion
      return $?
    fi
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
      operator-sdk run bundle --timeout ${TO_BUNDLE} ${IMAGE_VERSION} ${RUN_BUNDLE_PARAMS} --namespace ${OPERATOR_NAMESPACE}
    else
      operator-sdk run bundle --timeout ${TO_BUNDLE} ${IMAGE_VERSION} ${RUN_BUNDLE_PARAMS} --namespace ${OPERATOR_NAMESPACE} 2>/dev/null
    fi
    return $?
}

bundleStop() {
    if [ "${DISABLE_BUNDLE_INSTALL_TESTS}" == "1" ];
    then
      return 0
    fi
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        operator-sdk cleanup tang-operator --namespace ${OPERATOR_NAMESPACE}
    else
        operator-sdk cleanup tang-operator --namespace ${OPERATOR_NAMESPACE} 2>/dev/null
    fi
    if [ $? -eq 0 ];
    then
        checkPodAmount 0 ${TO_ALL_POD_CONTROLLER_TERMINATE} ${OPERATOR_NAMESPACE}
    fi
    return 0
}

getPodCpuRequest() {
    local pod_name=$1
    local namespace=$2
    dumpVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) CPU Request ..."
    local cpu
    cpu=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'cpu' | awk -F ":" '{print $2}' | tr -d ' ' | tr -d "[A-Z,a-z]")
    dumpVerbose "CPU REQUEST COMMAND:["${OC_CLIENT}" -n "${namespace}" describe pod ${pod_name} | grep -i Requests -A2 | grep 'cpu' | awk -F ':' '{print $2}' | tr -d ' ' | tr -d \"[A-Z,a-z]\""
    dumpVerbose "POD:[${pod_name}](Namespace:[${namespace}]) CPU Request:[${cpu}]"
    echo "${cpu}"
}

getPodMemRequest() {
    local pod_name=$1
    local namespace=$2
    dumpVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) MEM Request ..."
    local mem
    mem=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'memory' | awk -F ":" '{print $2}' | tr -d ' ')
    local unit
    unit="${mem: -1}"
    local mult
    mult=1
    case "${unit}" in
        K|k)
            mult=1024
            ;;
        M|m)
            mult=$((1024*1024))
            ;;
        G|g)
            mult=$((1024*1024*1024))
            ;;
        T|t)
            mult=$((1024*1024*1024*1024))
            ;;
        *)
            mult=1
            ;;
    esac
    dumpVerbose "MEM REQUEST COMMAND:["${OC_CLIENT}" -n "${namespace}" describe pod ${pod_name} | grep -i Requests -A2 | grep 'memory' | awk -F ':' '{print $2}' | tr -d ' '"
    dumpVerbose "POD:[${pod_name}](Namespace:[${namespace}]) MEM Request With Unit:[${mem}] Unit:[${unit}] Mult:[${mult}]"
    local mem_no_unit
    mem_no_unit="${mem/${unit}/}"
    local mult_mem
    mult_mem=$((mem_no_unit*mult))
    dumpVerbose "POD:[${pod_name}](Namespace:[${namespace}]) MEM Request:[${mult_mem}] Unit:[${unit}] Mult:[${mult}]"
    echo "${mult_mem}"
}

dumpOpenShiftClientStatus() {
    if [ "${EXECUTION_MODE}" == "MINIKUBE" ];
    then
	return 0
    fi
    if [ "${OC_CLIENT}" != "oc" ];
    then
	return 0
    fi
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        "${OC_CLIENT}" status
    else
        "${OC_CLIENT}" status 2>/dev/null 1>/dev/null
    fi
    return 0
}

installSecret() {
    if [ ${EXECUTION_MODE} == "MINIKUBE" ];
    then
        ## Only required for Minikube
        local md5sum_secret
        md5sum_secret=$(md5sum "${QUAY_FILE_NAME_PATH}" | awk '{print $1}')
        if [ "${md5sum_secret}" == "${QUAY_FILE_NAME_TO_FILL_UNFILLED_MD5}" ];
        then
             rlDie "Need to fill secret file for quay on MINIKUBE execution mode"
        else
            "${OC_CLIENT}" apply -f "${QUAY_FILE_NAME_PATH}"
        fi
        return $?
    else
        return 0
    fi
}

installScPv() {
    if [ ${EXECUTION_MODE} == "CLUSTER" ];
    then
	for sc in $("${OC_CLIENT}" get storageclasses.storage.k8s.io  | grep "\(${OPERATOR_NAMESPACE}\)" | awk '{print $1}' );
        do
            "${OC_CLIENT}" patch storageclass "${sc}" -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
	done
	rlLog "After Storage Class deletion:"
        "${OC_CLIENT}" get storageclasses.storage.k8s.io
        "${OC_CLIENT}" apply -f "${TEST_SC_FILE}"
        "${OC_CLIENT}" apply -f "${TEST_PV_FILE}"
	rlLog "After Storage Class application:"
        "${OC_CLIENT}" get storageclasses.storage.k8s.io
    fi
    return 0
}

getVersion() {
    if [ -n "${DOWNSTREAM_IMAGE_VERSION}" ];
    then
        echo "${DOWNSTREAM_IMAGE_VERSION}"
    else
        echo "${IMAGE_VERSION}"
    fi
}

analyzeVersion() {
    dumpVerbose "DETECTING MALWARE ON VERSION:[${1}]"
    "${CONTAINER_MGR}" pull "${1}"
    dir_mount=$("${CONTAINER_MGR}" unshare ./mount_image.sh -v "${1}" -c "${CONTAINER_MGR}")
    rlAssertEquals "Checking image could be mounted appropriately" "$?" "0"
    analyzed_dir=$(echo "${dir_mount}" | sed -e 's@/merged@@g')
    dumpVerbose "Analyzing directory:[${analyzed_dir}]"
    commandVerbose "tree ${analyzed_dir}"
    prefix=$(echo "${1}" | tr ':' '_' | awk -F "/" '{print $NF}')
    rlRun "clamscan -o --recursive --infected ${analyzed_dir} --log ${tmpdir}/${prefix}_malware.log" 0 "Checking for malware, logfile:${tmpdir}/${prefix}_malware.log"
    infected_files=$(grep -i "Infected Files:" "${tmpdir}/${prefix}_malware.log" | awk -F ":" '{print $2}' | tr -d ' ')
    rlAssertEquals "Checking no infected files" "${infected_files}" "0"
    if [ "${infected_files}" != "0" ]; then
        rlLogWarning "${infected_files} Infected Files Detected!"
        rlLogWarning "Please, review Malware Detection log file: ${tmpdir}/${prefix}_malware.log"
    fi
    "${CONTAINER_MGR}" unshare ./umount_image.sh -v "${1}" -c "${CONTAINER_MGR}"
    rlAssertEquals "Checking image could be umounted appropriately" "$?" "0"
}

rlJournalStart
    parseAndDumpMode
    parseAndDumpClient
    dumpDate
    dumpInfo
    rlPhaseStartSetup
        rlRun "tmpdir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "dumpOpenShiftClientStatus" 0 "Checking OpenshiftClient installation"
        rlRun "operator-sdk version > /dev/null" 0 "Checking operator-sdk installation"
        rlRun "checkClusterStatus" 0 "Checking cluster status"
        # In case previous execution was abruptelly stopped:
        rlRun "bundleStop" 0 "Cleaning already installed tang-operator (if any)"
        rlRun "bundleStart" 0 "Installing tang-operator-bundle version:${VERSION}"
        rlRun "${OC_CLIENT} apply -f ${TEST_NAMESPACE_FILE}" 0 "Creating test namespace:${TEST_NAMESPACE}"
        rlRun "${OC_CLIENT} get namespace ${TEST_NAMESPACE}" 0 "Checking test namespace:${TEST_NAMESPACE}"
        rlRun "installSecret" 0 "Installing secret if necessary"
    rlPhaseEnd

    ########## CHECK CONTROLLER RUNNING #########
    rlPhaseStartTest "Check tang-operator controller is running"
        controller_name=$(getPodNameWithPrefix "tang-operator-controller" "${OPERATOR_NAMESPACE}" "${TO_POD_START}")
        rlRun "checkPodState Running ${TO_POD_START} "${OPERATOR_NAMESPACE}" ${controller_name}" 0 "Checking controller POD in Running [Timeout=${TO_POD_START} secs.]"
    rlPhaseEnd

    ############# KEY MANAGEMENT TESTS ############
    rlPhaseStartTest "Key Management Test"
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/minimal-keyretrieve/daemons_v1alpha1_pv.yaml" 0 "Creating key management test pv"
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/minimal-keyretrieve/daemons_v1alpha1_tangserver.yaml" 0 "Creating key management test tangserver"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is running [Timeout=${TO_SERVICE_START} secs.]"
        rlRun "checkActiveKeysAmount 1 ${TO_ACTIVE_KEYS} ${TEST_NAMESPACE}" 0 "Checking Active Keys Amount is 1"
        rlRun "checkHiddenKeysAmount 0 ${TO_HIDDEN_KEYS} ${TEST_NAMESPACE}" 0 "Checking Hidden Keys Amount is 0"
        # Rotate VIA API
        rlRun "reg_test/key_management_test/api_key_rotate.sh -n ${TEST_NAMESPACE} -c ${OC_CLIENT}" 0 "Rotating keys"
        rlRun "checkHiddenKeysAmount 1 ${TO_HIDDEN_KEYS} ${TEST_NAMESPACE}" 0 "Checking Hidden Keys Amount is 1"
        rlRun "checkActiveKeysAmount 1 ${TO_ACTIVE_KEYS} ${TEST_NAMESPACE}" 0 "Checking Active Keys Amount is 1"
        # Rotate again VIA API, keeping all the hidden
        rlRun "reg_test/key_management_test/key_rotate_keep_existing.sh -n ${TEST_NAMESPACE} -c ${OC_CLIENT}" 0 "Rotating keys again"
        rlRun "checkActiveKeysAmount 1 ${TO_ACTIVE_KEYS} ${TEST_NAMESPACE}" 0 "Checking Active Keys Amount is 1"
        rlRun "checkHiddenKeysAmount 2 ${TO_HIDDEN_KEYS} ${TEST_NAMESPACE}" 0 "Checking Hidden Keys Amount is 2"
        # Delete one, keep one (selective deletion of hidden keys)
        rlRun "reg_test/key_management_test/key_delete_one_keep_one.sh -n ${TEST_NAMESPACE} -c ${OC_CLIENT}" 0 "Deleteing keys selectively"
        rlRun "checkActiveKeysAmount 1 ${TO_ACTIVE_KEYS} ${TEST_NAMESPACE}" 0 "Checking Active Keys Amount is 1"
        rlRun "checkHiddenKeysAmount 1 ${TO_HIDDEN_KEYS} ${TEST_NAMESPACE}" 0 "Checking Hidden Keys Amount is 1"

        # Delete all VIA API
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/minimal-keyretrieve-deletehiddenkeys/daemons_v1alpha1_pv.yaml" 0 "Deleting key management test pv"
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/minimal-keyretrieve-deletehiddenkeys/daemons_v1alpha1_tangserver.yaml" 0 "Deleting key management test tangserver"
        rlRun "checkActiveKeysAmount 1 ${TO_ACTIVE_KEYS} ${TEST_NAMESPACE}" 0 "Checking Active Keys Amount is 1"
        rlRun "checkHiddenKeysAmount 0 ${TO_HIDDEN_KEYS} ${TEST_NAMESPACE}" 0 "Checking Hidden Keys Amount is 0"
        rlRun "${OC_CLIENT} delete -f reg_test/key_management_test/minimal-keyretrieve/daemons_v1alpha1_tangserver.yaml" 0 "Deleting key management test tangserver"
        rlRun "${OC_CLIENT} delete -f reg_test/key_management_test/minimal-keyretrieve/daemons_v1alpha1_pv.yaml" 0 "Deleting key management test pv"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Multiple Key Management Replicas Test"
        ### Check Running / Ready Replicas
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_clusterrole.yaml" 0 "Creating multiple key management test clusterrole"
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_pv.yaml" 0 "Creating multiple key management test pv"
        rlRun "${OC_CLIENT} apply -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_tangserver.yaml" 0 "Creating multiple key management test tangserver"
        cat reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_clusterrolebinding.yaml \
          | sed "s/{{OPERATOR_NAMESPACE}}/${OPERATOR_NAMESPACE}/g" | ${OC_CLIENT} apply -f -
        rlRun "checkPodAmount 3 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 3 PODs are started [Timeout=${TO_POD_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 2)
        pod3_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 3)
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod3_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkStatusRunningReplicas 3 ${TEST_NAMESPACE} ${TO_POD_START}" 0 "Checking Running Replicas in tangserver status"
        rlRun "checkStatusReadyReplicas 3 ${TEST_NAMESPACE} ${TO_POD_START}" 0 "Checking Ready Replicas in tangserver status"
        rlRun "${OC_CLIENT} delete -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_clusterrole.yaml" 0 "Deleting key management test clusterrole"
        rlRun "${OC_CLIENT} delete -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_tangserver.yaml" 0 "Deleting key management test tangserver"
        rlRun "${OC_CLIENT} delete -f reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_pv.yaml" 0 "Deleting key management test pv"
        cat reg_test/key_management_test/multiple-keyretrieve/daemons_v1alpha1_clusterrolebinding.yaml \
          | sed "s/{{OPERATOR_NAMESPACE}}/${OPERATOR_NAMESPACE}/g" | ${OC_CLIENT} delete -f -
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd
    ############# /KEY MANAGEMENT TESTS ###########

    ########## CONFIGURATION TESTS #########
    rlPhaseStartTest "Minimal Configuration"
        rlRun "${OC_CLIENT} apply -f reg_test/conf_test/minimal/" 0 "Creating minimal configuration"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/conf_test/minimal/" 0 "Deleting minimal configuration"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no POD continues running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Main Configuration"
        rlRun "${OC_CLIENT} apply -f reg_test/conf_test/main/" 0 "Creating main configuration"
        rlRun "checkPodAmount 3 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 3 PODs are started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 2)
        pod3_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 3)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod3_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod3_name}" 0 "Checking POD:[$pod3_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/conf_test/main/" 0 "Deleting main configuration"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Multiple Deployment Configuration"
        rlRun "${OC_CLIENT} apply -f reg_test/conf_test/multi_deployment/" 0 "Creating multiple deployment configuration"
        rlRun "checkPodAmount 5 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 5 PODs are started [Timeout=${TO_POD_START} secs.]"
        rlRun "sleep 5" 0 "Waiting to ensure no more than expected replicas are started"
        rlRun "checkPodAmount 5 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 5 PODs continue running [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 2 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 2 Services are running [Timeout=${TO_SERVICE_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 2)
        pod3_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 3)
        pod4_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 4)
        pod5_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 5)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod3_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod4_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod5_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod3_name}" 0 "Checking POD:[$pod3_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod4_name}" 0 "Checking POD:[$pod2_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod5_name}" 0 "Checking POD:[$pod3_name] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/conf_test/multi_deployment/" 0 "Deleting multiple deployment configuration"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd
    ######### /CONFIGURATION TESTS ########

    ########### FUNCTIONAL TESTS ##########
    rlPhaseStartTest "Unique deployment functional test"
        rlRun "${OC_CLIENT} apply -f reg_test/func_test/unique_deployment_test/" 0 "Creating unique deployment"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        service_name=$(getServiceNameWithPrefix "service" "${TEST_NAMESPACE}" 5 1)
        service_ip=$(getServiceIp "${service_name}" "${TEST_NAMESPACE}" "${TO_EXTERNAL_IP}")
        service_port=$(getServicePort "${service_name}" "${TEST_NAMESPACE}")
	rlRun "checkServiceUp ${service_ip} ${service_port} ${TO_SERVICE_UP}" 0 "Checking Service:[${service_ip}] UP"
        rlRun "serviceAdv ${service_ip} ${service_port}" 0 "Checking Service Advertisement [IP/HOST:${service_ip} PORT:${service_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/unique_deployment_test/" 0 "Deleting unique deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Unique deployment functional test (with clevis encryption/decryption)"
        rlRun "${OC_CLIENT} apply -f reg_test/func_test/unique_deployment_test/" 0 "Creating unique deployment"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        service_name=$(getServiceNameWithPrefix "service" "${TEST_NAMESPACE}" 5 1)
        service_ip=$(getServiceIp "${service_name}" "${TEST_NAMESPACE}" "${TO_EXTERNAL_IP}")
        service_port=$(getServicePort "${service_name}" "${TEST_NAMESPACE}")
	rlRun "checkServiceUp ${service_ip} ${service_port} ${TO_SERVICE_UP}" 0 "Checking Service:[${service_ip}] UP"
        rlRun "serviceAdv ${service_ip} ${service_port}" 0 "Checking Service Advertisement [IP/HOST:${service_ip} PORT:${service_port}]"

        rlRun "echo \"${TOP_SECRET_WORDS}\" | clevis encrypt tang '{\"url\":\"http://${service_ip}:${service_port}\"}' -y > ${tmpdir}/test_secret_words.jwe"
        rlRun "decrypted=\$(clevis decrypt < ${tmpdir}/test_secret_words.jwe)"
        rlAssertEquals "Checking clevis decryption worked properly" "${decrypted}" "${TOP_SECRET_WORDS}"

        rlRun "${OC_CLIENT} delete -f reg_test/func_test/unique_deployment_test/" 0 "Deleting unique deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Multiple deployment functional test"
        rlRun "${OC_CLIENT} apply -f reg_test/func_test/multiple_deployment_test/" 0 "Creating multiple deployment"
        rlRun "checkPodAmount 2 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 2 PODs are started [Timeout=${TO_POD_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 2)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 2 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 2 Services are started [Timeout=${TO_SERVICE_START} secs.]"
        service1_name=$(getServiceNameWithPrefix "service" "${TEST_NAMESPACE}" 5 1)
        service1_ip=$(getServiceIp "${service1_name}" "${TEST_NAMESPACE}" "${TO_EXTERNAL_IP}")
        service1_port=$(getServicePort "${service1_name}" "${TEST_NAMESPACE}")
        service2_name=$(getServiceNameWithPrefix "service" "${TEST_NAMESPACE}" 5 2)
        service2_ip=$(getServiceIp "${service2_name}" "${TEST_NAMESPACE}" "${TO_EXTERNAL_IP}")
        service2_port=$(getServicePort "${service2_name}" "${TEST_NAMESPACE}")
	rlRun "checkServiceUp ${service1_ip} ${service1_port} ${TO_SERVICE_UP}" 0 "Checking Service:[${service1_ip}] UP"
	rlRun "checkServiceUp ${service2_ip} ${service2_port} ${TO_SERVICE_UP}" 0 "Checking Service:[${service2_ip}] UP"
        rlRun "serviceAdvCompare ${service1_ip} ${service1_port} ${service2_ip} ${service2_port}" 0 \
              "Checking Services Advertisement [IP1/HOST1:${service1_ip} PORT1:${service1_port}][IP2/HOST2:${service2_ip} PORT2:${service2_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/multiple_deployment_test/" 0 "Deleting multiple deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Key rotation functional test"
        rlRun "${OC_CLIENT} apply -f reg_test/func_test/key_rotation/" 0 "Creating key rotation deployment"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 PODs is started [Timeout=${TO_POD_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        service_name=$(getServiceNameWithPrefix "service" "${TEST_NAMESPACE}" 5 1)
        service_ip=$(getServiceIp "${service_name}" "${TEST_NAMESPACE}" "${TO_EXTERNAL_IP}")
        service_port=$(getServicePort "${service_name}" "${TEST_NAMESPACE}")
	rlRun "checkServiceUp ${service_ip} ${service_port} ${TO_SERVICE_UP}" 0 "Checking Service:[${service_ip}] UP"
        rlRun "checkKeyRotation ${service_ip} ${service_port} ${TEST_NAMESPACE}" 0\
              "Checking Key Rotation [IP/HOST:${service_ip} PORT:${service_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/key_rotation/" 0 "Deleting key rotation deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd
    ########### /FUNCTIONAL TESTS #########

    ########### SCALABILTY TESTS ##########
    rlPhaseStartTest "Scale-out scalability test"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_out/scale_out0/" 0 "Creating scale out test [0]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is started [Timeout=${TO_SERVICE_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_out/scale_out1/" 0 "Creating scale out test [1]"
        rlRun "checkPodAmount 2 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1+1 PODs are started [Timeout=${TO_POD_START} secs.]"
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking added POD in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/scale_test/scale_out/scale_out0/" 0 "Deleting scale out test"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Scale-in scalability test"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_in/scale_in0/" 0 "Creating scale in test [0]"
        rlRun "checkPodAmount 2 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 2 PODs are started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is running [Timeout=${TO_SERVICE_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 2)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_in/scale_in1/" 0 "Creating scale in test [1]"
        rlRun "checkPodAmount 1 ${TO_POD_SCALEIN_WAIT} ${TEST_NAMESPACE}" 0 "Checking only 1 POD continues running [Timeout=${TO_POD_SCALEIN_WAIT} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] still in Running state [Timeout=${TO_POD_START} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/scale_test/scale_in/scale_in0/" 0 "Deleting scale in test"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_START} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Scale-up scalability test"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_up/scale_up0/" 0 "Creating scale up test [0]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is running [Timeout=${TO_SERVICE_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        cpu1=$(getPodCpuRequest "${pod1_name}" "${TEST_NAMESPACE}")
        mem1=$(getPodMemRequest "${pod1_name}" "${TEST_NAMESPACE}")
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_up/scale_up1/" 0 "Creating scale up test [1]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking only 1 POD continues running [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodKilled ${pod1_name} ${TEST_NAMESPACE} ${TO_POD_TERMINATE}" 0 "Checking POD:[${pod1_name}] not available any more [Timeout=${TO_POD_TERMINATE} secs.]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 new POD is running [Timeout=${TO_POD_START} secs.]"
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlAssertNotEquals "Checking new POD has been created" "${pod1_name}" "${pod2_name}"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        cpu2=$(getPodCpuRequest "${pod2_name}" "${TEST_NAMESPACE}")
        mem2=$(getPodMemRequest "${pod2_name}" "${TEST_NAMESPACE}")
        rlAssertGreater "Checking cpu request value increased" ${cpu2} ${cpu1}
        rlAssertGreater "Checking mem request value increased" ${mem2} ${mem1}
        rlRun "${OC_CLIENT} delete -f reg_test/scale_test/scale_up/scale_up0/" 0 "Deleting scale up test"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd

    rlPhaseStartTest "Scale-down scalability test"
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_down/scale_down0/" 0 "Creating scale down test [0]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is running [Timeout=${TO_SERVICE_START} secs.]"
        pod1_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod1_name}" ""
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        cpu1=$(getPodCpuRequest "${pod1_name}" "${TEST_NAMESPACE}")
        mem1=$(getPodMemRequest "${pod1_name}" "${TEST_NAMESPACE}")
        rlRun "${OC_CLIENT} apply -f reg_test/scale_test/scale_down/scale_down1/" 0 "Creating scale down test [1]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking only 1 POD continues running [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodKilled ${pod1_name} ${TEST_NAMESPACE} ${TO_POD_TERMINATE}" 0 "Checking POD:[${pod1_name}] not available any more [Timeout=${TO_POD_TERMINATE} secs.]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 new POD is running [Timeout=${TO_POD_START} secs.]"
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlAssertNotEquals "Checking new POD has been created" "${pod1_name}" "${pod2_name}"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        cpu2=$(getPodCpuRequest "${pod2_name}" "${TEST_NAMESPACE}")
        mem2=$(getPodMemRequest "${pod2_name}" "${TEST_NAMESPACE}")
        rlAssertLesser "Checking cpu request value decreased" "${cpu2}" "${cpu1}"
        rlAssertLesser "Checking mem request value decreased" "${mem2}" "${mem1}"
        rlRun "${OC_CLIENT} delete -f reg_test/scale_test/scale_down/scale_down0/" 0 "Deleting scale down test"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd
    ########### /SCALABILTY TESTS #########

    ############# LEGACY TESTS ############
    rlPhaseStartTest "Legacy Test"
        rlRun "${OC_CLIENT} apply -f reg_test/legacy_test/" 0 "Creating legacy test"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 POD is started [Timeout=${TO_POD_START} secs.]"
        rlRun "checkServiceAmount 1 ${TO_SERVICE_START} ${TEST_NAMESPACE}" 0 "Checking 1 Service is running [Timeout=${TO_SERVICE_START} secs.]"
        pod_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5)
        rlAssertNotEquals "Checking pod name not empty" "${pod_name}" ""
        rlRun "checkPodState Running ${TO_LEGACY_POD_RUNNING} ${TEST_NAMESPACE} ${pod_name}" 0 "Checking POD in Running state [Timeout=${TO_LEGACY_POD_RUNNING} secs.]"
        rlRun "${OC_CLIENT} delete -f reg_test/legacy_test/" 0 "Deleting legacy test"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Services continue running [Timeout=${TO_SERVICE_STOP} secs.]"
    rlPhaseEnd
    ############# /LEGACY TESTS ###########

    ############# DAST TESTS ############
    ### Only execute DAST TESTS if helm command exists ...
    command -v helm >/dev/null && {
        rlPhaseStartTest "Dynamic Application Security Testing"
            # 1 - Log helm version
            dumpVerbose "$(helm version)"

            # 2 - clone rapidast code (development branch)
            pushd "${tmpdir}" && git clone https://github.com/RedHatProductSecurity/rapidast.git -b development

            # 3 - download configuration file template
            # WARNING: if tang-operator is changed to OpenShift organization, change this
            wget -O tang_operator.yaml https://raw.githubusercontent.com/latchset/tang-operator/main/tools/scan_tools/tang_operator_template.yaml

            # 4 - adapt configuration file template (token, machine)
            API_HOST_PORT=$("${OC_CLIENT}" whoami --show-server | tr -d  ' ')
            DEFAULT_TOKEN=$("${OC_CLIENT}" get secret -n "${OPERATOR_NAMESPACE}" $("${OC_CLIENT}" get secret -n "${OPERATOR_NAMESPACE}"\
                            | grep ^tang-operator | grep service-account | awk '{print $1}') -o json | jq -Mr '.data.token' | base64 -d)
            sed -i s@"API_HOST_PORT_HERE"@"${API_HOST_PORT}"@g tang_operator.yaml
            sed -i s@"AUTH_TOKEN_HERE"@"${DEFAULT_TOKEN}"@g tang_operator.yaml
            sed -i s@"OPERATOR_NAMESPACE_HERE"@"${OPERATOR_NAMESPACE}"@g tang_operator.yaml
            dumpVerbose "API_HOST_PORT:[${API_HOST_PORT}]"
            dumpVerbose "DEFAULT_TOKEN:[${DEFAULT_TOKEN}]"
            dumpVerbose "OPERATOR_NAMESPACE provided to DAST:[${OPERATOR_NAMESPACE}]"
            rlAssertNotEquals "Checking token not empty" "${DEFAULT_TOKEN}" ""

            # 5 - adapt helm
            pushd rapidast
            sed -i s@"kubectl --kubeconfig=./kubeconfig "@"${OC_CLIENT} "@g helm/results.sh
            sed -i s@"secContext: '{}'"@"secContext: '{\"privileged\": true}'"@ helm/chart/values.yaml

            # 6 - run rapidast on adapted configuration file (via helm)
            rlRun -c "helm install rapidast ./helm/chart/ --set-file rapidastConfig=${tmpdir}/tang_operator.yaml 2>/dev/null" 0 "Installing rapidast helm chart"
            pod_name=$(getPodNameWithPrefix "rapidast" "default" 5 1)
            rlRun "checkPodState Completed ${TO_DAST_POD_COMPLETED} default ${pod_name}" 0 "Checking POD ${pod_name} in Completed state [Timeout=${TO_DAST_POD_COMPLETED} secs.]"

            # 7 - extract results
            rlRun -c "bash ./helm/results.sh 2>/dev/null" 0 "Extracting DAST results"

            # 8 - parse results (do not have to ensure no previous results exist, as this is a temporary directory)
            # Check no alarm exist ...
            report_dir=$(ls -1d ${tmpdir}/rapidast/tangservers/DAST*tangservers/ | head -1 | sed -e 's@/$@@g')
            dumpVerbose "REPORT DIR:${report_dir}"
            alerts=$(cat "${report_dir}/zap/zap-report.json" | jq '.site[0].alerts | length')
            for ((alert=0; ix<${alerts}; ix++));
            do
                risk_desc=$(cat "${report_dir}/zap/zap-report.json" | jq ".site[0].alerts[${alert}].riskdesc" | awk '{print $1}' | tr -d '"' | tr -d " ")
                rlLog "Alert[${alert}] -> Priority:[${risk_desc}]"
                rlAssertNotEquals "Checking alarm is not High Risk" "${risk_desc}" "High"
            done
            if [ "${alerts}" != "0" ];
            then
                DELETE_TMP_DIR="NO"
                rlLogWarning "Alerts detected! Please, review ZAP report: ${report_dir}/zap/zap-report.json"
            fi

            # 9 - clean helm installation
            helm uninstall rapidast

            # 10 - return
            popd
            popd

        rlPhaseEnd
    }
    ############# /DAST TESTS ###########

    ############# MALWARE DETECTION TESTS ############
    ### Only execute if podman and clamscan commands exist ...
    command -v "${CONTAINER_MGR}" >/dev/null && command -v clamscan >/dev/null && {
        rlPhaseStartTest "Malware Detection Testing"
        installed_version=$(getVersion)
        ### Bundle Image
        analyzeVersion "${installed_version}"
        ### Container Image
        controller_name=$(getPodNameWithPrefix "tang-operator-controller" "${OPERATOR_NAMESPACE}" 1)
        rlAssertNotEquals "Checking controller_name is not empty" "${controller_name}" ""
        container_image=$("${OC_CLIENT}" -n "${OPERATOR_NAMESPACE}" describe pod "${controller_name}" | grep tang | grep "Image:" | awk -F "Image:" '{print $2}' | tr -d ' ')
        rlAssertEquals "Checking container image could be parsed appropriately" "$?" "0"
        rlAssertNotEquals "Checking container image is not empty" "${container_image}" ""
        dumpVerbose "Container Image:[${container_image}]"
        test -n "${container_image}" && analyzeVersion "${container_image}"
        DELETE_TMP_DIR="NO"
        rlPhaseEnd
    }
    ############# /MALWARE DETECTION TESTS ###########

    rlPhaseStartCleanup
        rlRun "checkClusterStatus" 0 "Checking cluster status"
        controller_name=$(getPodNameWithPrefix "tang-operator-controller" "${OPERATOR_NAMESPACE}" 1)
        dumpVerbose "Controller name:[${controller_name}]"
        if [ -n "${DOWNSTREAM_IMAGE_VERSION}" ] && [ "${DISABLE_BUNDLE_INSTALL_TESTS}" != "1" ];
        then
            uninstallDownstreamVersion
        fi
        rlRun "bundleStop" 0 "Cleaning installed tang-operator"
        if [ "${DISABLE_BUNDLE_INSTALL_TESTS}" != "1" ]; then
          test -z "${controller_name}" ||
              rlRun "checkPodKilled ${controller_name} ${OPERATOR_NAMESPACE} ${TO_POD_CONTROLLER_TERMINATE}" 0 "Checking controller POD not available any more [Timeout=${TO_POD_CONTROLLER_TERMINATE} secs.]"
        fi
        rlRun "${OC_CLIENT} delete -f ${TEST_NAMESPACE_FILE}" 0 "Deleting test namespace:${TEST_NAMESPACE}"
        if [ "${DELETE_TMP_DIR}" = "YES" ];
        then
            rlRun "rm -rf ${tmpdir}" 0 "Removing tmp \(${tmpdir}\) directory"
        fi
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
