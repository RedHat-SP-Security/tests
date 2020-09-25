#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <string.h>
#include <sys/un.h>

static struct sockaddr_un SyslogAddr;
//static char* msg = "<133>2012-12-10T16:47:28.229278+01:00 bla bla bla msg";
static char* msg = "<133>2012-12-10T16:47:28.229278+01:00 this is a test message";

int main() {
  SyslogAddr.sun_family = AF_UNIX;
  //strncpy(SyslogAddr.sun_path, "/dev/log", sizeof(SyslogAddr.sun_path));
  strncpy(SyslogAddr.sun_path, "/dev/bz886004log", sizeof(SyslogAddr.sun_path));
  int LogFile = socket(AF_UNIX, SOCK_DGRAM, 0);
  fcntl(LogFile, F_SETFD, FD_CLOEXEC);
  connect(LogFile, (struct sockaddr *)&SyslogAddr, sizeof(SyslogAddr)) == -1;
  send(LogFile, msg, strlen(msg), 0);
  close(LogFile);
  return 0;
}
