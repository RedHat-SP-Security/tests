#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/librdkafka/Sanity/consumer-producer
#   Description: sanity test for rdkafka library
#   Author: Attila Lakatos <alakatos@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc.
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
# . /usr/bin/rhts-environment.sh || :
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="rsyslog"
CONTROLLERID=123

# This test focuses on creating a producer-consumer environment and estabilishing
# exactly one consumer(server) and one producer(client). First, the producer will
# start generating messages, which will be then processed/received by the consumer.
# The test checks if all messages have arrived successfully and if the rd_kafka_controllerid
# symbol is available in the dynamically linked shared object library and if it works as expected.

rlJournalStart && {
  rlPhaseStartSetup && {
    rlRun "rlImport --all" 0 "Import libraries" || rlDie "cannot continue"
    tcfRun "rlCheckMakefileRequires"
    CleanupRegister 'rlRun "rlSEPortRestore"'

    rlRun "rlSEPortAdd tcp 9092 syslogd_port_t"
    rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    CleanupRegister "rlRun 'rm -r $TmpDir' 0 'Removing tmp directory'"
    CleanupRegister 'rlRun "popd"'
    rlRun "ls -al"
    rlRun "cp Makefile kafka-prog.c $TmpDir"
    rlRun "pushd $TmpDir"
    CleanupRegister 'rlRun "rlFileRestore"'
    rlRun "rlFileBackup --clean /var/log/imkafka.log /tmp/kafka-logs /tmp/zookeeper"
    rlRun "rm -rf /tmp/kafka-logs /tmp/zookeeper"

    rlRun "rlDownload kafka_2.11-2.1.0.tgz http://download.eng.bos.redhat.com/qa/rhts/lookaside/kafka_2.11-2.1.0.tgz"
    rlRun "tar -xzf kafka_2.11-2.1.0.tgz"
    rlRun "cd kafka_2.11-2.1.0"
    rlRun "bin/zookeeper-server-start.sh config/zookeeper.properties &"
    CleanupRegister "rlRun 'kill $!' 0 'kill zookeeper server'; rlWaitForSocket --close 2181"
    rlWaitForSocket 2181
    rlRun "sleep 3"

    rlRun "sed -i -E 's/^(broker\.id=)[0-9]+$/\1$CONTROLLERID/' config/server.properties"
    rlRun "head -30 config/server.properties"
    rlRun "bin/kafka-server-start.sh config/server.properties &"
    CleanupRegister "rlRun 'kill $!' 0 'kill kafka server'; rlWaitForSocket --close 9092"
    rlWaitForSocket 9092
    rlRun "sleep 10"

    rlRun "bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic TestTopic" 0-255
    rlRun "bin/kafka-topics.sh --list --zookeeper localhost:2181"
    CleanupRegister "rlRun 'make clean'"
    rlRun "cp ../Makefile ../kafka-prog.c ."
    rlRun "make"

  rlPhaseEnd; }

  rlPhaseStartTest "Pre-test" && {
    rlRun "nm -D /usr/lib64/librdkafka.so | grep rd_kafka_controllerid" 0 "The rd_kafka_controllerid symbol must be present in the shared object library"
  rlPhaseEnd; }

  tcfTry "Tests" --no-assert && {
    rlPhaseStartTest && {
      rlRun "./kafka-prog consumer 127.0.0.1:9092 TestGroupID TestTopic > /tmp/kafka-consumer.log 2>&1 &"
      CleanupRegister "rlRun 'kill -SIGINT $!' 0 'kill kafka consumer'"
      CleanupRegister "rlRun 'rm -f /tmp/kafka-consumer.log' "
      sleep 3

      ITER=20
      for i in `seq $ITER`; do
        echo "Testing producer-consumer scenario $i" >> /tmp/kafka-producer-input.log
      done
      rlRun "cat /tmp/kafka-producer-input.log"

      rlRun "./kafka-prog producer 127.0.0.1:9092 TestTopic < /tmp/kafka-producer-input.log > /tmp/kafka-producer.log 2>&1 &"
      CleanupRegister "rlRun 'kill -SIGINT $!' 0-1 'kill kafka producer'"
      CleanupRegister "rlRun 'rm -f /tmp/kafka-producer.log /tmp/kafka-producer-input.log' "


      sleep 10
      rlRun "cat /tmp/kafka-consumer.log"
      rlRun "cat /tmp/kafka-producer.log"
      for i in `seq $ITER`; do
        rlAssertGrep "Value: Testing producer-consumer scenario $i" /tmp/kafka-consumer.log
      done
      rlAssertGrep "Consumer: rd_kafka_controllerid='$CONTROLLERID'" /tmp/kafka-consumer.log
      rlAssertGrep "Producer: rd_kafka_controllerid='$CONTROLLERID'" /tmp/kafka-producer.log

    rlPhaseEnd; }
  tcfFin; }

  rlPhaseStartCleanup && {
    CleanupDo
    tcfCheckFinal
  rlPhaseEnd; }
  rlJournalPrintText
rlJournalEnd; }
