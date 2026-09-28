#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/*
 * Call chroot("/tmp") and exit. The process does not pivot, mount, or walk
 * back out. A successful return only means the syscall was permitted.
 */
int main(void) {
    int err;

    if (chroot("/tmp") != 0) {
        err = errno;
        fprintf(stderr, "chroot: %s (errno=%d)\n", strerror(err), err);
        if (err == EPERM) {
            return 10;
        }
        return 11;
    }

    printf("chroot: ok\n");
    return 0;
}
