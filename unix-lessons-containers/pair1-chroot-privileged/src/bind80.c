#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

/*
 * Bind 127.0.0.1:80 and exit. This only reports whether the bind is allowed.
 * It does not listen, accept, or send any bytes.
 */
int main(void) {
    int fd;
    int opt = 1;
    int err;
    struct sockaddr_in addr;

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        err = errno;
        fprintf(stderr, "socket: %s (errno=%d)\n", strerror(err), err);
        return 2;
    }
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        err = errno;
        fprintf(stderr, "setsockopt: %s (errno=%d)\n", strerror(err), err);
        close(fd);
        return 2;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(80);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        err = errno;
        fprintf(stderr, "bind: %s (errno=%d)\n", strerror(err), err);
        close(fd);
        if (err == EACCES || err == EPERM) {
            return 10;
        }
        return 11;
    }

    printf("bind 127.0.0.1:80: ok\n");
    close(fd);
    return 0;
}
