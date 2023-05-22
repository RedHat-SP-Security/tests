#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rsyslog/Sanity/smoke-elasticsearch
#   Description: Smoke test for elastic search feature
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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
    rlRun "rlCheckMakefileRequires" || rlDie 'cannot continue'
    CleanupRegister 'tcfRun "rsyslogCleanup"'
    tcfRun "rsyslogSetup"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlSEBooleanRestore allow_ypbind"'
    rlRun "rlSEBooleanOn allow_ypbind"
    CleanupRegister 'rlRun "rlServiceStop elasticsearch"'
    rlRun "rlServiceStart elasticsearch"
    rlRun "rlWaitForSocket --port 9200"
#    rlRun "sleep 20"
    rlRun "rlServiceStatus elasticsearch"
    rlRun "netstat -putna | grep 9200" 0-255
    rlRun "curl -XGET 'http://127.0.0.1:9200/'"
    rlRun "curl -XDELETE 'http://127.0.0.1:9200/system'"
    rlRun "curl -XGET 'http://127.0.0.1:9200/_all/_search?q=testMSG&pretty'"
    ESv=${ESv:+esVersion.major=\"$ESv\"}
    SearchIndex=${SearchIndex:+searchindex=\"$SearchIndex\" searchtype=\"\"}
    rsyslogConfigAddTo "RULES" /etc/rsyslog.conf <<EOF
module(load="omelasticsearch") #for indexing to Elasticsearch

template(name="plain-syslog-tpl" type="list") {
    constant(value="{")
    constant(value="\"@timestamp\":\"")     property(name="timereported" dateFormat="rfc3339")
    constant(value="\",\"host\":\"")        property(name="hostname")
    constant(value="\",\"severity\":\"")    property(name="syslogseverity-text")
    constant(value="\",\"facility\":\"")    property(name="syslogfacility-text")
    constant(value="\",\"tag\":\"")   property(name="syslogtag" format="json")
    constant(value="\",\"message\":\"")    property(name="msg" format="json")
    constant(value="\"}")
}
action(type="omelasticsearch" server="127.0.0.1" $SearchIndex template="plain-syslog-tpl" $ESv)
EOF
    CleanupRegister 'rlRun "rlServiceStop rsyslog"'
    rlRun "rsyslogPrintEffectiveConfig -n"
    rlRun "rlServiceStart rsyslog"
    rlRun "netstat -putna | grep 9200" 0-255; :
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      rlRun "logger testMSG"
      rlRun "sleep 20"
      #rlRun -s "curl -XGET 'http://127.0.0.1:9200/test-index?pretty=true'"
      #rlRun -s "curl -XPOST localhost:9200/system/events/_search?q=testMSG 2>stderr | sed s/.*_source//"
      rlRun -s "curl -XGET 'http://127.0.0.1:9200/_all/_search?q=*&pretty'"
      rlAssertGrep '"message" *: *"testMSG"' $rlRun_LOG
      rm -f $rlRun_LOG
    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }

rlJournalPrintText
rlJournalEnd; }
