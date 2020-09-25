#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/mmkubernetes-module-test
#   Description: basic sanity check for mmkubernetes module
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
PYTHON="/usr/libexec/platform-python"
which $PYTHON || PYTHON="python"


rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires"
    CleanupRegister 'rsyslogCleanup'
    rlRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/log/containers/ /var/log/mmkubernetes.log"
    rsyslogPrepareConf
    rsyslogConfigAddTo 'RULES' < <(rsyslogConfigCreateSection 'kubernetes')

    rsyslogConfigReplace 'kubernetes' <<EOF
module(load="imfile")
module(load="mmjsonparse")
module(load="mmkubernetes"  busyretryinterval="1" token="dummy" kubernetesurl="http://localhost:514")
template(name="mmk8s_template" type="list") {
    property(name="\$!all-json-plain")
    constant(value="\n")
}
ruleset(name="mmk"){
  action(type="mmjsonparse" cookie="")
  action(type="mmkubernetes")
  action(type="omfile" file="/var/log/mmkubernetes.log" template="mmk8s_template")
}
input(type="imfile" file="/var/log/containers/pod-*.log" tag="kubernetes" addmetadata="on" ruleset="mmk")
EOF
    cat > /etc/rsyslog.d/k8s_filename.rulebase << EOF
version=2
rule=:/var/log/containers/%pod_name:char-to:_%_%namespace_name:char-to:_%_%container_name_and_id:char-to:.%.log
EOF
    cat > /etc/rsyslog.d/k8s_container_name.rulebase << EOF
version=2
rule=:%k8s_prefix:char-to:_%_%container_name:char-to:_%_%pod_name:char-to:_%_%namespace_name:char-to:_%_%not_used_1:char-to:_%_%not_used_2:rest%
EOF
    rlRun "rsyslogPrintEffectiveConfig -n"
    ( $PYTHON -u <<'EOF'
# {{{
# Used by the mmkubernetes tests
# This is a simple http server which responds to kubernetes api requests
# and responds with kubernetes api server responses
# added 2018-04-06 by richm, released under ASL 2.0
import os
import json
import sys

try:
    from http.server import HTTPServer, BaseHTTPRequestHandler
except ImportError:
    from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler

ns_template = '''{{
  "kind": "Namespace",
  "apiVersion": "v1",
  "metadata": {{
    "name": "{namespace_name}",
    "selfLink": "/api/v1/namespaces/{namespace_name}",
    "uid": "{namespace_name}-id",
    "resourceVersion": "2988",
    "creationTimestamp": "2018-04-09T21:56:39Z",
    "labels": {{
      "label.1.key":"label 1 value",
      "label.2.key":"label 2 value",
      "label.with.empty.value":""
    }},
    "annotations": {{
      "k8s.io/description": "",
      "k8s.io/display-name": "",
      "k8s.io/node-selector": "",
      "k8s.io/sa.scc.mcs": "s0:c9,c4",
      "k8s.io/sa.scc.supplemental-groups": "1000080000/10000",
      "k8s.io/sa.scc.uid-range": "1000080000/10000",
      "quota.k8s.io/cluster-resource-override-enabled": "false"
    }}
  }},
  "spec": {{
    "finalizers": [
      "openshift.io/origin",
      "kubernetes"
    ]
  }},
  "status": {{
    "phase": "Active"
  }}
}}'''

pod_template = '''{{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {{
    "name": "{pod_name}",
    "generateName": "{pod_name}-prefix",
    "namespace": "{namespace_name}",
    "selfLink": "/api/v1/namespaces/{namespace_name}/pods/{pod_name}",
    "uid": "{pod_name}-id",
    "resourceVersion": "3486",
    "creationTimestamp": "2018-04-09T21:56:39Z",
    "labels": {{
      "component": "{pod_name}-component",
      "deployment": "{pod_name}-deployment",
      "deploymentconfig": "{pod_name}-dc",
      "custom.label": "{pod_name}-label-value",
      "label.with.empty.value":""
    }},
    "annotations": {{
      "k8s.io/deployment-config.latest-version": "1",
      "k8s.io/deployment-config.name": "{pod_name}-dc",
      "k8s.io/deployment.name": "{pod_name}-deployment",
      "k8s.io/custom.name": "custom value",
      "annotation.with.empty.value":""
    }}
  }},
  "status": {{
    "phase": "Running",
    "hostIP": "172.18.4.32",
    "podIP": "10.128.0.14",
    "startTime": "2018-04-09T21:57:39Z"
  }}
}}'''

err_template = '''{{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {{
  }},
  "status": "Failure",
  "message": "{kind} \\\"{objectname}\\\" {err}",
  "reason": "{reason}",
  "details": {{
    "name": "{objectname}",
    "kind": "{kind}"
  }},
  "code": {code}
}}'''

is_busy = False

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        # "http://localhost:18443/api/v1/namespaces/namespace-name2"
        # parse url - either /api/v1/namespaces/$ns_name
        # or
        # /api/v1/namespaces/$ns_name/pods/$pod_name
        global is_busy
        comps = self.path.split('/')
        status = 400
        if len(comps) >= 5 and comps[1] == 'api' and comps[2] == 'v1' and comps[3] == 'namespaces':
            resp = None
            hsh = {'namespace_name':comps[4],'objectname':comps[4],'kind':'namespace'}
            if len(comps) == 5: # namespace
                resp_template = ns_template
                status = 200
            elif len(comps) == 7 and comps[5] == 'pods': # pod
                hsh['pod_name'] = comps[6]
                hsh['kind'] = 'pods'
                hsh['objectname'] = hsh['pod_name']
                resp_template = pod_template
                status = 200
            else:
                resp = '{{"error":"do not recognize {0}"}}'.format(self.path)
            if hsh['objectname'].endswith('not-found'):
                status = 404
                hsh['reason'] = 'NotFound'
                hsh['err'] = 'not found'
                resp_template = err_template
            elif hsh['objectname'].endswith('busy'):
                is_busy = not is_busy
                if is_busy:
                    status = 429
                    hsh['reason'] = 'Busy'
                    hsh['err'] = 'server is too busy'
                    resp_template = err_template
            if not resp:
                hsh['code'] = status
                resp = resp_template.format(**hsh)
        else:
            resp = '{{"error":"do not recognize {0}"}}'.format(self.path)
        if not status == 200:
            self.log_error(resp)
        self.send_response(status)
        self.end_headers()
        self.wfile.write(json.dumps(json.loads(resp), separators=(',',':')).encode())

port = int(514)

httpd = HTTPServer(('localhost', port), SimpleHTTPRequestHandler)

# write pid to file named in argv[2]
with open("./server.pid", "w") as ff:
    ff.write('{0}\n'.format(os.getpid()))

httpd.serve_forever()
#}}}
EOF
) &
    rlRun "rlWaitForFile ./server.pid"
    CleanupRegister "rlRun 'kill $(cat ./server.pid)'"
    rlRun "mkdir -p /var/log/containers"
    rlRun "rm -f /var/log/mmkubernetes.log"
    rlRun "rsyslogServiceStart"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      rlRun 'cat > /var/log/containers/pod-name1_namespace-name1_container-name1-id1.log <<EOF
{"log":"{\"type\":\"response\",\"@timestamp\":\"2018-04-06T17:26:34Z\",\"tags\":[],\"pid\":75,\"method\":\"head\",\"statusCode\":200,\"req\":{\"url\":\"/\",\"method\":\"head\",\"headers\":{\"user-agent\":\"curl/7.29.0\",\"host\":\"localhost:5601\",\"accept\":\"*/*\"},\"remoteAddress\":\"127.0.0.1\",\"userAgent\":\"127.0.0.1\"},\"res\":{\"statusCode\":200,\"responseTime\":1,\"contentLength\":9},\"message\":\"HEAD1 / 200 1ms - 9.0B\"}\n","stream":"stdout","time":"2018-04-06T17:26:34.492083106Z","testid":3}
EOF
'
      rlRun "sleep 10s"
      rlRun "cat /var/log/mmkubernetes.log"
      rlAssertGrep '"kubernetes":{"namespace_id":"namespace-name1-id","namespace_labels":{"label_1_key":"la
bel 1 value","label_2_key":"label 2 value","label_with_empty_value":""},"creation_timestamp":"2018-04-09T21:56:39Z","pod_id":"pod-name1-id","labels":{"component":"pod-name1-component","deployment":"pod-name1-deployment","deploymentconfig":
"pod-name1-dc","custom_label":"pod-name1-label-value","label_with_empty_value":""},"pod_name":"pod-name1","namespace_name":"namespace-name1","container_name":"container-name1","master_url":"http:\/\/localhost:514"},"docker":{"container_id"
:"id1"}' /var/log/mmkubernetes.log
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
