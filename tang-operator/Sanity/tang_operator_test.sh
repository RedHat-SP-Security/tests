#!/bin/bash
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
echo "================ INFO ================"
echo "DATE:$(date)"
echo "HOSTNAME:$(hostname)"
echo "================ /INFO ==============="

result=1
./tools/dependency_install.sh
dep_res=$?
echo "Dependency installation result:${dep_res}"
echo "======= DIRECTORY:$(pwd) ========"

if [ ${dep_res} -eq 255 ];
then
    # Architecture unsupported, just let it go in this arch
    echo "Architecture execution bypassed"
    ./runnotest.sh
    result=$?
elif [ ${dep_res} -eq 0 ];
then
    chown minikube.minikube -R "$(pwd)"
    # Ugly, but the way paths are managed (root dir not directory where running):
    chown minikube.minikube -R "$(pwd)/../../../../../.."
    # User minikube should have been installed, execute test as minikube user
    su minikube -c '. ~/.bashrc && ./runtest.sh'
    run_result=$?
    echo "TEST EXECUTION RESULT:[${run_result}]"
    result=${run_result}
fi
echo "RESULT:[${result}]"
exit "${result}"
