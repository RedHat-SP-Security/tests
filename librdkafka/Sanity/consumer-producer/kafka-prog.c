#include <assert.h>
#include <ctype.h>
#include <getopt.h>
#include <rdkafka.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>

#define BUFFERSIZE 512
static volatile sig_atomic_t run = 1;
enum kafka_mode_t { MODE_UNSPECIFIED, MODE_CONSUMER, MODE_PRODUCER };

static void stop(int sig) {
  run = 0;
  fclose(stdin);
}

static void logger(const rd_kafka_t* rk, int level, const char* fac,
                   const char* buf) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  fprintf(stderr, "%u.%03u RDKAFKA-%i-%s: %s: %s\n", (int)tv.tv_sec,
          (int)(tv.tv_usec / 1000), level, fac, rk ? rd_kafka_name(rk) : NULL,
          buf);
}

static void usage(char* prog_name) {
  printf(
      "Usage:\n"
      "%s consumer <broker> <group.id> <topic1> <topic2>..\n"
      "%s producer <broker> <topic>\n",
      prog_name, prog_name);
}

int main(int argc, char** argv) {
  char buffer[BUFFERSIZE];
  enum kafka_mode_t mode = MODE_UNSPECIFIED;
  const char* topic = NULL;
  char** topics = NULL;
  const char* brokers = NULL;
  const char* groupid = NULL;
  int topic_cnt;

  rd_kafka_t* rk;
  rd_kafka_conf_t* conf;
  rd_kafka_resp_err_t err;

  if (argc > 1 && strcmp(argv[1], "consumer") == 0) {
    mode = MODE_CONSUMER;
    brokers = argv[2];
    groupid = argv[3];
    topics = &argv[4];
    topic_cnt = argc - 4;
  } else if (argc > 1 && strcmp(argv[1], "producer") == 0) {
    mode = MODE_PRODUCER;
    brokers = argv[2];
    topic = argv[3];
  } else {
    usage(argv[0]);
    exit(1);
  }

  conf = rd_kafka_conf_new();
  // rd_kafka_conf_set_log_cb(conf, logger);

  if (rd_kafka_conf_set(conf, "bootstrap.servers", brokers, buffer,
                        sizeof(buffer)) != RD_KAFKA_CONF_OK) {
    fprintf(stderr, "%s\n", buffer);
    exit(1);
  }

  signal(SIGINT, stop);

  if (mode == MODE_PRODUCER) {
    fprintf(stderr, "Starting producer\n");
    assert(brokers != NULL && topic != NULL);

    if (rd_kafka_conf_set(conf, "client.id", "TestID", buffer,
                          sizeof(buffer)) != RD_KAFKA_CONF_OK) {
      fprintf(stderr, "%s\n", buffer);
      exit(1);
    }

    //  rd_kafka_conf_set_dr_msg_cb(conf, dr_msg_cb);

    if (!(rk = rd_kafka_new(RD_KAFKA_PRODUCER, conf, buffer, sizeof(buffer)))) {
      fprintf(stderr, "Failed to create new producer: %s\n", buffer);
      exit(1);
    }

    const int controllerID = rd_kafka_controllerid(rk, 10 * 1000);
    printf("Producer: rd_kafka_controllerid='%d'\n", controllerID);

    while (run && fgets(buffer, sizeof(buffer), stdin)) {
      size_t len = strlen(buffer);

      if (buffer[len - 1] == '\n') buffer[--len] = '\0';

      if (len == 0) {
        rd_kafka_poll(rk, 0 /*non-blocking */);
        continue;
      }
    retry:
      err = rd_kafka_producev(rk, RD_KAFKA_V_TOPIC(topic),
                              RD_KAFKA_V_MSGFLAGS(RD_KAFKA_MSG_F_COPY),
                              RD_KAFKA_V_VALUE(buffer, len),
                              RD_KAFKA_V_OPAQUE(NULL), RD_KAFKA_V_END);

      if (err) {
        fprintf(stderr, "Failed to produce to topic %s: %d\n", topic,
                rd_kafka_err2str(err));

        if (err == RD_KAFKA_RESP_ERR__QUEUE_FULL) {
          rd_kafka_poll(rk, 1000 /*block for max 1000ms*/);
          goto retry;
        }
      } else {
        fprintf(stderr,
                "Enqueued message (%zd bytes) "
                "for topic: %s\n",
                len, topic);
      }

      rd_kafka_poll(rk, 0 /*non-blocking*/);
    }
    fprintf(stderr, "Flushing final messages..\n");
    rd_kafka_flush(rk, 10 * 1000);

    if (rd_kafka_outq_len(rk) > 0)
      fprintf(stderr, "%d message(s) were not delivered\n",
              rd_kafka_outq_len(rk));

  } else if (mode == MODE_CONSUMER) {
    rd_kafka_topic_partition_list_t* subscription;

    // consumer - client
    fprintf(stderr, "Starting consumer brokers=%s, groupdid=%s, topics=%s\n",
            brokers, groupid, topics[0]);
    assert(brokers != NULL && groupid != NULL && topics != 0);

    if (rd_kafka_conf_set(conf, "group.id", groupid, buffer, sizeof(buffer)) !=
        RD_KAFKA_CONF_OK) {
      fprintf(stderr, "%s\n", buffer);
      rd_kafka_conf_destroy(conf);
      return 1;
    }

    rk = rd_kafka_new(RD_KAFKA_CONSUMER, conf, buffer, sizeof(buffer));
    if (!rk) {
      fprintf(stderr, "%% Failed to create new consumer: %s\n", buffer);
      return 1;
    }
    conf = NULL;
    rd_kafka_poll_set_consumer(rk);
    subscription = rd_kafka_topic_partition_list_new(topic_cnt);
    for (int i = 0; i < topic_cnt; i++) {
      rd_kafka_topic_partition_list_add(subscription, topics[i],
                                        RD_KAFKA_PARTITION_UA);
    }
    err = rd_kafka_subscribe(rk, subscription);
    if (err) {
      fprintf(stderr, "%% Failed to subscribe to %d topics: %s\n",
              subscription->cnt, rd_kafka_err2str(err));
      rd_kafka_topic_partition_list_destroy(subscription);
      rd_kafka_destroy(rk);
      return 1;
    }

    rd_kafka_topic_partition_list_destroy(subscription);
    const int controllerID = rd_kafka_controllerid(rk, 10 * 1000);
    printf("Consumer: rd_kafka_controllerid='%d'\n", controllerID);
    while (run) {
      rd_kafka_message_t* rkm;

      rkm = rd_kafka_consumer_poll(rk, 100);
      if (!rkm) continue;

      if (rkm->err) {
        fprintf(stderr, "%% Consumer error: %s\n",
                rd_kafka_message_errstr(rkm));
        rd_kafka_message_destroy(rkm);
        continue;
      }

      printf("There was a proper message\n");
      printf("On %s [%" PRId32 "] at offset %" PRId64 "\n",
             rd_kafka_topic_name(rkm->rkt), rkm->partition, rkm->offset);

      printf(" Value: %.*s\n", (int)rkm->len,
             rkm->payload ? (const char*)rkm->payload : "NULL");
      fflush(stdout);

      rd_kafka_message_destroy(rkm);
    }

    printf("Closing consumer\n");
    rd_kafka_consumer_close(rk);
  }

  fflush(stdin);

  rd_kafka_destroy(rk);
  return 0;
}