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
kr_namespace=$1
os_client=$2

test -z "${kr_namespace}" && kr_namespace="nbde"
test -z "${os_client}" && os_client="oc"

function get_pod() {
  "${os_client}" -n "${kr_namespace}" get pods | tail -1 | awk '{print $1}'
}

kr_pod=$(get_pod)

"${os_client}" -n ${kr_namespace} exec -i "${kr_pod}" -- /bin/bash -xc 'cd /var/db/tang; for key in *jwk; do mv -- $key .$key; done'
