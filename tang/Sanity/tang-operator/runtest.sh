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
TIMEOUT="5m"
TEST_NAMESPACE_PATH="reg_test/all_test_namespace"
TEST_NAMESPACE_FILE_NAME="daemons_v1alpha1_namespace.yaml"
TEST_NAMESPACE_FILE="${TEST_NAMESPACE_PATH}/${TEST_NAMESPACE_FILE_NAME}"
TEST_NAMESPACE=$(grep -i 'name:' "${TEST_NAMESPACE_FILE}" | awk -F ':' {'print $2'} | tr -d ' ')

rlJournalStart
    rlPhaseStartSetup
        rlRun "oc status > /dev/null"  0 "Checking OpenshiftClient installation"
        rlRun "operator-sdk version > /dev/null" 0 "Checking operator-sdk installation"
        rlRun "crc status | grep OpenShift | awk -F ':' {'print $2'} | awk {'print $1'} | grep -i Running" 0 "Checking Code Ready Containers up and running"
        rlRun "oc adm policy add-scc-to-group anyuid system:authenticated" 0 "Configuring cluster to allow deployment of containers"
        rlRun "operator-sdk run bundle --timeout ${TIMEOUT} quay.io/sarroutb/tang-operator-bundle:${VERSION}" 0 "Installing tang-operator-bundle version:${VERSION}"
        rlRun "oc apply -f ${TEST_NAMESPACE_FILE}" 0 "Creating test namespace:${TEST_NAMESPACE}"
        rlRun "oc get namespace ${TEST_NAMESPACE}" 0 "Checking test namespace:${TEST_NAMESPACE}"
    rlPhaseEnd


    ########## CONFIGURATION TESTS #########
    rlPhaseStartTest
        rlRun "oc apply -f reg_test/conf_test/minimal/" 0 "Creating minimal configuration"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/conf_test/minimal/" 0 "Deleting minimal configuration"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/conf_test/main/" 0 "Creating main configuration"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/conf_test/main/" 0 "Deleting main configuration"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/conf_test/multi_deployment/" 0 "Creating multiple deployment configuration"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/conf_test/multi_deployment/" 0 "Deleting multiple deployment configuration"
    rlPhaseEnd
    ######### /CONFIGURATION TESTS ########


    ########### FUNCTIONAL TESTS ##########
    rlPhaseStartTest
        rlRun "oc apply -f reg_test/func_test/unique_deployment_test/" 0 "Creating unique deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/func_test/unique_deployment_test/" 0 "Deleting unique deployment"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/func_test/multiple_deployment_test/" 0 "Creating multiple deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/func_test/multiple_deployment_test/" 0 "Deleting multiple deployment"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/func_test/key_rotation/" 0 "Creating key rotation deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/func_test/key_rotation/" 0 "Deleting key rotation deployment"
    rlPhaseEnd
    ########### /FUNCTIONAL TESTS #########

    ########### SCALABILTY TESTS ##########
    rlPhaseStartTest
        rlRun "oc apply -f reg_test/scale_test/scale_out/scale_out0/" 0 "Creating scale out test [0]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc apply -f reg_test/scale_test/scale_out/scale_out1/" 0 "Creating scale out test [1]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/scale_test/scale_out/scale_out0/" 0 "Deleting scale out test"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/scale_test/scale_in/scale_in0/" 0 "Creating scale in test [0]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc apply -f reg_test/scale_test/scale_in/scale_in1/" 0 "Creating scale in test [1]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/scale_test/scale_in/scale_in0/" 0 "Deleting scale in test"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/scale_test/scale_up/scale_up0/" 0 "Creating scale up test [0]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc apply -f reg_test/scale_test/scale_up/scale_up1/" 0 "Creating scale up test [1]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/scale_test/scale_up/scale_up0/" 0 "Deleting scale up test"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "oc apply -f reg_test/scale_test/scale_down/scale_down0/" 0 "Creating scale down test [0]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc apply -f reg_test/scale_test/scale_down/scale_down1/" 0 "Creating scale down test [1]"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/scale_test/scale_down/scale_down0/" 0 "Deleting scale down test"
    rlPhaseEnd
    ########### /SCALABILTY TESTS #########

    ############# LEGACY TESTS ############
    rlPhaseStartTest
        rlRun "oc apply -f reg_test/legacy_test/" 0 "Creating legacy test"
        rlRun "oc -n ${TEST_NAMESPACE} get pods" 0 "Checking deployed pod"
        rlRun "oc -n ${TEST_NAMESPACE} get deployments" 0 "Checking deployment"
        rlRun "oc -n ${TEST_NAMESPACE} get service" 0 "Checking service"
        rlRun "oc delete -f reg_test/legacy_test/" 0 "Deleting legacy test"
    rlPhaseEnd
    ############# /LEGACY TESTS ###########

    rlPhaseStartCleanup
        rlRun "oc status" 0 "Checking status"
        rlRun "oc -n ${TEST_NAMESPACE} status" 0 "Checking namespace:${TEST_NAMESPACE} status"
        rlRun "operator-sdk cleanup tang-operator" 0 "Removing tang-operator"
        rlRun "oc delete -f ${TEST_NAMESPACE_FILE}" 0 "Deleting test namespace:${TEST_NAMESPACE}"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
