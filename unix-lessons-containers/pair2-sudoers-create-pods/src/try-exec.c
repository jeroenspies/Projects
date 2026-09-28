#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/*
 * Try to exec /bin/true. Exit 0 means exec replaced this process and true ran.
 * Exit 10 means execve failed with EPERM (what NOEXEC is documented to do).
 */
int main(void) {
    char *argv[] = {"true", NULL};
    int err;

    execv("/bin/true", argv);
    err = errno;
    fprintf(stderr, "exec /bin/true failed: %s (errno=%d)\n", strerror(err), err);
    if (err == EPERM) {
        return 10;
    }
    return 11;
}
