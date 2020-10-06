/* Author: Steve Grubb <sgrubb@redhat.com> */
/* https://bugzilla.redhat.com/show_bug.cgi?id=593635 */

#include <stdio.h>
#include <cap-ng.h>
#include <pthread.h>
#include <errno.h>
#include <string.h>
#include <sys/syscall.h>

pthread_t thread1, thread2;

void *thread1_main(void *arg)
{
    printf("thread1: %u\n", (long int)syscall(__NR_gettid));
    capng_clear(CAPNG_SELECT_BOTH);
    capng_updatev(CAPNG_ADD, CAPNG_EFFECTIVE|CAPNG_PERMITTED, CAP_NET_RAW, CAP_SETPCAP, -1);
    capng_apply(CAPNG_SELECT_CAPS);
    capng_print_caps_numeric(CAPNG_PRINT_STDOUT, CAPNG_SELECT_BOTH);
    sleep(4);
    return NULL;
}

void *thread2_main(void *arg)
{
    printf("thread2: %u\n", (long int)syscall(__NR_gettid));
    sleep(2);
    printf("thread2 getting caps\n");
    capng_get_caps_process();
    printf("thread2 got caps\n");
    capng_print_caps_numeric(CAPNG_PRINT_STDOUT, CAPNG_SELECT_BOTH);
    capng_clear(CAPNG_SELECT_BOTH);
    capng_update(CAPNG_ADD, CAPNG_EFFECTIVE|CAPNG_PERMITTED, CAP_NET_RAW);
    if (capng_apply(CAPNG_SELECT_BOTH))
        printf("Failed applying caps: %s\n", strerror(errno));
    capng_print_caps_numeric(CAPNG_PRINT_STDOUT, CAPNG_SELECT_BOTH);
    return NULL;
}

int main(void)
{
    if (capng_have_capabilities(CAPNG_SELECT_CAPS) != CAPNG_FULL) {
        printf("Error- you do not have capabilities\n");
        return 1;
    }
    pthread_create(&thread1, NULL, thread1_main, NULL);
    pthread_create(&thread2, NULL, thread2_main, NULL);
    sleep(7);
    return 0;
}


