#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang/Sanity/tang-operator
#   Description: Deployment and basic functionality of the tang operator
#   Author: Martin Zeleny <mzeleny@redhat.com>
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

PACKAGE="tang"
VERSION="latest"
TO_BUNDLE="5m"
TEST_NAMESPACE_PATH="reg_test/all_test_namespace"
TEST_NAMESPACE_FILE_NAME="daemons_v1alpha1_namespace.yaml"
TEST_NAMESPACE_FILE="${TEST_NAMESPACE_PATH}/${TEST_NAMESPACE_FILE_NAME}"
TEST_NAMESPACE=$(grep -i 'name:' "${TEST_NAMESPACE_FILE}" | awk -F ':' {'print $2'} | tr -d ' ')
TEST_PVSC_PATH="reg_test/all_test_namespace"
TEST_PV_FILE_NAME="daemons_v1alpha1_pv.yaml"
TEST_PV_FILE="${TEST_PVSC_PATH}/${TEST_PV_FILE_NAME}"
TEST_SC_FILE_NAME="daemons_v1alpha1_storageclass.yaml"
TEST_SC_FILE="${TEST_PVSC_PATH}/${TEST_SC_FILE_NAME}"
TEST_=$(grep -i 'name:' "${TEST_NAMESPACE_FILE}" | awk -F ':' {'print $2'} | tr -d ' ')
EXECUTION_MODE=
TO_POD_START=60 #seconds
TO_POD_SCALEIN_WAIT=60 #seconds
TO_LEGACY_POD_RUNNING=60 #seconds
TO_POD_STOP=5 #seconds
TO_POD_TERMINATE=60 #seconds
TO_POD_CONTROLLER_TERMINATE=180 #seconds (for controller to end must wait longer)
TO_POD_DISAPPEARS=10 #seconds
TO_SERVICE_START=60 #seconds
TO_SERVICE_STOP=120 #seconds
TO_EXTERNAL_IP=120 #seconds
TO_WGET_CONNECTION=5 #seconds
TO_ALL_POD_CONTROLLER_TERMINATE=120 #seconds
TO_KEY_ROTATION=1 #seconds
ADV_PATH="adv"
QUAY_PATH="quay_secret"
QUAY_FILE_NAME_TO_FILL="daemons_v1alpha1_tangserver_secret_registry_redhat_io.yaml"
QUAY_FILE_NAME_PATH="${QUAY_PATH}/${QUAY_FILE_NAME_TO_FILL}"
QUAY_FILE_NAME_TO_FILL_UNFILLED_MD5="db099cc0b92220feb7a38783b02df897"
OC_DEFAULT_CLIENT="kubectl"

dumpVerbose() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        rlLog "${1}"
    fi
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
        if [ ! -z "${TEST_CRC_MODE}" ];
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
        rlRun "crc status | grep OpenShift | awk -F ':' {'print $2'} | awk {'print $1'} | grep -i Running" 0 "Checking Code Ready Containers up and running"
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
    local counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        POD_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" | wc -l)
        dumpVerbose "POD AMOUNT:${POD_AMOUNT} EXPECTED:${expected} COUNTER:${counter}"
        if [ ${POD_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        let counter=$counter+1
        sleep 1
    done
    return 1
}

checkPodKilled() {
    local pod_name=$1
    local namespace=$2
    local iterations=$3
    local counter=0
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
        let counter=$counter+1
        sleep 1
    done
    return 1
}

checkPodState() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local podname=$4
    local counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      pod_status=$("${OC_CLIENT}" -n "${namespace}" get pod "${podname}" | grep -v "^NAME" | awk {'print $3'})
      dumpVerbose "POD STATUS:${pod_status} EXPECTED:${expected} COUNTER:${counter}"
      if [ "${pod_status}" == "${expected}" ]; then
        return 0
      fi
      let counter=$counter+1
      sleep 1
    done
    return 1
}

checkServiceAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        SERVICE_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" | wc -l)
        dumpVerbose "SERVICE AMOUNT:${SERVICE_AMOUNT} EXPECTED:${expected} COUNTER:${counter}"
        if [ ${SERVICE_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        let counter=$counter+1
        sleep 1
    done
    return 1
}

getPodNameWithPrefix() {
    local prefix=$1
    local namespace=$2
    local iterations=$3
    local tail_position=$4
    test -z "${tail_position}" && let tail_position=1
    local counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local pod_line=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" | grep "${prefix}" | tail -${tail_position} | head -1)
      dumpVerbose "POD LINE:[${pod_line}] POD PREFIX:[${prefix}] COUNTER:[${counter}]"
      if [ "${pod_line}" != "" ]; then
          echo "$(echo ${pod_line} | awk {'print $1'})"
          dumpVerbose "FOUND POD name:[$(echo ${pod_line} | awk {'print $1'})] POD PREFIX:[${prefix}] COUNTER:[${counter}]"
          return 0
      else
          let counter=${counter}+1
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
    test -z "${tail_position}" && let tail_position=1
    local counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local service_name=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" | grep "${prefix}" | tail -${tail_position} | head -1)
      dumpVerbose "SERVICE NAME:[${service_name}] COUNTER:[${counter}]"
      if [ "${service_name}" != "" ]; then
          dumpVerbose "FOUND SERVICE name:[$(echo ${service_name} | awk {'print $1'})] POD PREFIX:[${prefix}] COUNTER:[${counter}]"
          echo "$(echo ${service_name} | awk {'print $1'})"
          return 0
      else
          let counter=${counter}+1
          sleep 1
      fi
    done
    return 1
}

getServiceIp() {
    local service_name=$1
    local namespace=$2
    local iterations=$3
    let counter=0
    dumpVerbose "Getting SERVICE:[${service_name}](Namespace:[${namespace}]) IP ..."
    if [ ${EXECUTION_MODE} == "CRC" ];
    then
        local crc_service_ip=$(crc ip)
        dumpVerbose "CRC MODE, SERVICE IP:[${crc_service_ip}]"
        echo "${crc_service_ip}"
        return 0
    elif [ ${EXECUTION_MODE} == "MINIKUBE" ];
    then
        local minikube_service_ip=$(minikube ip)
        dumpVerbose "MINIKUBE MODE, SERVICE IP:[${minikube_service_ip}]"
        echo "${minikube_service_ip}"
        return 0
    fi
    while [ ${counter} -lt ${iterations} ];
    do
        local service_ip=$("${OC_CLIENT}" -n "${namespace}" describe service "${service_name}" | grep -i "LoadBalancer Ingress:" | awk -F ':' {'print $2'} | tr -d ' ')
        dumpVerbose "SERVICE IP:[${service_ip}](Namespace:[${namespace}])"
        if [ ! -z "${service_ip}" ] && [ "${service_ip}" != "<pending>" ];
        then
            echo "${service_ip}"
            return 0
        else
            dumpVerbose "PENDING OR EMPTY IP:[${service_ip}], COUNTER[${counter}/${iterations}]"
        fi
        let counter=${counter}+1
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
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk {'print $5'} | awk -F ':' {'print $1'})
    else
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk {'print $5'} | awk -F ':' {'print $2'} | awk -F '/' {'print $1'})
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
    local file=$(mktemp)
    COMMAND="wget ${URL} --timeout=${TO_WGET_CONNECTION} -O ${file} -o /dev/null"
    dumpVerbose "CONNECTION_COMMAND:[${COMMAND}]"
    $(${COMMAND})
    wget_res=$?
    dumpVerbose "WGET RESULT:$(cat ${file})"
    JSON_ADV=$(cat ${file})
    dumpVerbose "CONNECTION_COMMAND:[${COMMAND}],RESULT:[${wget_res}],JSON_ADV:[${JSON_ADV}])"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        cat "${file}" | jq . -M -a
    else
        cat "${file}" | jq . -M -a 2>/dev/null
    fi
    jq_res=$?
    rm "${file}"
    return $((${wget_res}+${jq_res}))
}

checkKeyRotation() {
    local ip=$1
    local port=$2
    local namespace=$3
    local file1=$(mktemp)
    local file2=$(mktemp)
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
    local url="http://${ip}:${port}/${ADV_PATH}"
    local get_command1="wget ${url} --timeout=${TO_WGET_CONNECTION} -O ${file} -o /dev/null"
    dumpVerbose "DUMP_KEY_ADV_COMMAND:[${get_command1}]"
    ${get_command1}
}

serviceAdvCompare() {
    local ip=$1
    local port=$2
    local ip2=$3
    local port2=$4
    local url="http://${ip}:${port}/${ADV_PATH}"
    local url2="http://${ip2}:${port2}/${ADV_PATH}"
    let jq_equal=1
    local file1=$(mktemp)
    local file2=$(mktemp)
    local jq_json_file1=$(mktemp)
    local jq_json_file2=$(mktemp)
    local command1="wget ${url} --timeout=${TO_WGET_CONNECTION} -O ${file1} -o /dev/null"
    local command2="wget ${url2} --timeout=${TO_WGET_CONNECTION} -O ${file2} -o /dev/null"
    dumpVerbose "CONNECTION_COMMAND:[${command1}]"
    dumpVerbose "CONNECTION_COMMAND:[${command2}]"
    ${command1}
    wget_res1=$?
    ${command2}
    wget_res2=$?
    dumpVerbose "CONNECTION_COMMAND:[${command1}],RESULT:[${wget_res1}],json_adv:[$(cat ${file1})]"
    dumpVerbose "CONNECTION_COMMAND:[${command2}],RESULT:[${wget_res2}],json_adv:[$(cat ${file2})]"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        cat "${file1}" | jq . -M -a 2>&1 | tee ${jq_json_file1}
    else
        cat "${file1}" | jq . -M -a > ${jq_json_file1}
    fi
    jq_res1=$?
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        cat "${file2}" | jq . -M -a 2>&1 | tee ${jq_json_file2}
    else
        cat "${file2}" | jq . -M -a > ${jq_json_file2}
    fi
    jq_res2=$?
    rlAssertDiffer "${jq_json_file1}" "${jq_json_file2}"
    let jq_equal=$?
    rm "${jq_json_file1}" "${jq_json_file2}"
    return $((${wget_res1}+${wget_res2}+${jq_res1}+${jq_res2}+${jq_equal}))
}

bundleStart() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
      operator-sdk run bundle --timeout ${TO_BUNDLE} quay.io/sarroutb/tang-operator-bundle:${VERSION}
    else
      operator-sdk run bundle --timeout ${TO_BUNDLE} quay.io/sarroutb/tang-operator-bundle:${VERSION} 2>/dev/null
    fi
    return $?
}

bundleStop() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        operator-sdk cleanup tang-operator
    else
        operator-sdk cleanup tang-operator 2>/dev/null
    fi
    if [ $? -eq 0 ];
    then
        checkPodAmount 0 ${TO_ALL_POD_CONTROLLER_TERMINATE} default
    fi
    return 0
}

getPodCpuRequest() {
    local pod_name=$1
    local namespace=$2
    dumpVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) CPU Request ..."
    local cpu=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'cpu' | awk -F ":" {'print $2'} | tr -d ' ' | tr -d "[A-Z,a-z]")
    dumpVerbose "CPU REQUEST COMMAND:["${OC_CLIENT}" -n ${namespace} describe pod ${pod_name} | grep -i Requests -A2 | grep 'cpu' | awk -F ':' {'print $2'} | tr -d ' ' | tr -d \"[A-Z,a-z]\""
    dumpVerbose "POD:[${pod_name}](Namespace:[${namespace}]) CPU Request:[${cpu}]"
    echo "${cpu}"
}

getPodMemRequest() {
    local pod_name=$1
    local namespace=$2
    dumpVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) MEM Request ..."
    local mem=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'memory' | awk -F ":" {'print $2'} | tr -d ' ')
    local unit="${mem: -1}"
    local mult=1
    case "${unit}" in
        K|k)
            let mult=1024
            ;;
        M|m)
            let mult=$((1024*1024))
            ;;
        G|g)
            let mult=$((1024*1024*1024))
            ;;
        T|t)
            let mult=$((1024*1024*1024*1024))
            ;;
        *)
            let mult=1
            ;;
    esac
    dumpVerbose "MEM REQUEST COMMAND:["${OC_CLIENT}" -n ${namespace} describe pod ${pod_name} | grep -i Requests -A2 | grep 'memory' | awk -F ':' {'print $2'} | tr -d ' '"
    dumpVerbose "POD:[${pod_name}](Namespace:[${namespace}]) MEM Request With Unit:[${mem}] Unit:[${unit}] Mult:[${mult}]"
    local mem_no_unit="${mem/${unit}/}"
    local mult_mem=$((mem_no_unit*mult))
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
        local md5sum_secret=$(md5sum "${QUAY_FILE_NAME_PATH}" | awk {'print $1'})
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
	for sc in $("${OC_CLIENT}" get storageclasses.storage.k8s.io  | grep '\(default\)' | awk {'print $1'} );
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

addContainerRootPermission() {
    if [ "${OC_CLIENT}" == "oc" ];
    then
        rlRun "${OC_CLIENT} adm policy add-scc-to-group anyuid system:authenticated" 0 "Configuring cluster to allow deployment of containers (anyuid)"
    fi
}

rlJournalStart
    parseAndDumpMode
    parseAndDumpClient
    rlPhaseStartSetup
        rlRun "dumpOpenShiftClientStatus" 0 "Checking OpenshiftClient installation"
        rlRun "operator-sdk version > /dev/null" 0 "Checking operator-sdk installation"
        rlRun "checkClusterStatus" 0 "Checking cluster status"
        addContainerRootPermission
        # In case previous execution was abruptelly stopped:
        rlRun "bundleStop" 0 "Cleaning already installed tang-operator (if any)"
        rlRun "bundleStart" 0 "Installing tang-operator-bundle version:${VERSION}"
        rlRun "${OC_CLIENT} apply -f ${TEST_NAMESPACE_FILE}" 0 "Creating test namespace:${TEST_NAMESPACE}"
        rlRun "${OC_CLIENT} get namespace ${TEST_NAMESPACE}" 0 "Checking test namespace:${TEST_NAMESPACE}"
        rlRun "installSecret" 0 "Installing secret if necessary"
        rlRun "installScPv" 0 "Install Storage Class and Persistent Volume if necessary"
    rlPhaseEnd

    ########## CHECK CONTROLLER RUNNING #########
    rlPhaseStartTest "Check tang-operator controller is running"
        sleep 10
        controller_name=$(getPodNameWithPrefix "tang-operator-controller" "default" 5)
        rlRun "checkPodState Running ${TO_POD_START} default ${controller_name}" 0 "Checking controller POD in Running [Timeout=${TO_POD_START} secs.]"
    rlPhaseEnd

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
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "serviceAdv ${service_ip} ${service_port}" 0 "Checking Service Advertisement [IP:${service_ip} PORT:${service_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/unique_deployment_test/" 0 "Deleting unique deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "serviceAdvCompare ${service1_ip} ${service1_port} ${service2_ip} ${service2_port}" 0 \
              "Checking Services Advertisement [IP1:${service1_ip} PORT1:${service1_port}][IP2:${service2_ip} PORT2:${service2_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/multiple_deployment_test/" 0 "Deleting multiple deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "checkKeyRotation ${service_ip} ${service_port} ${TEST_NAMESPACE}" 0\
              "Checking Key Rotation [IP:${service_ip} PORT:${service_port}]"
        rlRun "${OC_CLIENT} delete -f reg_test/func_test/key_rotation/" 0 "Deleting key rotation deployment"
        rlRun "checkPodAmount 0 ${TO_POD_STOP} ${TEST_NAMESPACE}" 0 "Checking no PODs continue running [Timeout=${TO_POD_STOP} secs.]"
        rlRun "checkServiceAmount 0 ${TO_SERVICE_STOP} ${TEST_NAMESPACE}" 0 "Checking no Service continue running [Timeout=${TO_SERVICE_STOP} secs.]"
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
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking aded POD in Running state [Timeout=${TO_POD_START} secs.]"
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
        rlRun "checkPodState Terminating ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] in Terminating state [Timeout=${TO_POD_START} secs.]"
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
        rlRun "checkPodState Terminating ${TO_POD_START} ${TEST_NAMESPACE} ${pod1_name}" 0 "Checking POD:[$pod1_name}] in Terminating state [Timeout=${TO_POD_START} secs.]"
        rlRun "checkPodKilled ${pod1_name} ${TEST_NAMESPACE} ${TO_POD_TERMINATE}" 0 "Checking POD:[${pod1_name}] not available any more [Timeout=${TO_POD_TERMINATE} secs.]"
        rlRun "checkPodAmount 1 ${TO_POD_START} ${TEST_NAMESPACE}" 0 "Checking 1 new POD is running [Timeout=${TO_POD_START} secs.]"
        pod2_name=$(getPodNameWithPrefix "tang" "${TEST_NAMESPACE}" 5 1)
        rlAssertNotEquals "Checking pod name not empty" "${pod2_name}" ""
        rlAssertNotEquals "Checking new POD has been created" "${pod1_name}" "${pod2_name}"
        rlRun "checkPodState Running ${TO_POD_START} ${TEST_NAMESPACE} ${pod2_name}" 0 "Checking POD:[$pod2_name}] in Running state [Timeout=${TO_POD_START} secs.]"
        cpu2=$(getPodCpuRequest "${pod2_name}" "${TEST_NAMESPACE}")
        mem2=$(getPodMemRequest "${pod2_name}" "${TEST_NAMESPACE}")
        rlAssertLesser "Checking cpu request value decreased" ${cpu2} ${cpu1}
        rlAssertLesser "Checking mem request value decreased" ${mem2} ${mem1}
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

    rlPhaseStartCleanup
        rlRun "checkClusterStatus" 0 "Checking cluster status"
        controller_name=$(getPodNameWithPrefix "tang-operator-controller" "default" 1)
        dumpVerbose "Controller name:[${controller_name}]"
        rlRun "bundleStop" 0 "Cleaning already installed tang-operator (if any)"
        test -z "${controller_name}" ||
            rlRun "checkPodKilled ${controller_name} default ${TO_POD_CONTROLLER_TERMINATE}" 0 "Checking controller POD not available any more [Timeout=${TO_POD_CONTROLLER_TERMINATE} secs.]"
        rlRun "${OC_CLIENT} delete -f ${TEST_NAMESPACE_FILE}" 0 "Deleting test namespace:${TEST_NAMESPACE}"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
