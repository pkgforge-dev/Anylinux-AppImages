#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <locale.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#define LOG(fmt, ...) fprintf(stderr, " LOCALEFIX >> " fmt "\n", ##__VA_ARGS__)

/*
 * While we normally bundle locales with quick-sharun and apps have working
 * language interface, we do not bundle the libc locale because glibc
 * has issues when LOCPATH is used This means some applications like dolphin-emu
 * crash when glibc cannot switch locale even though the application itself can
 * This library checks that and forces the C locale instead to prevent crashes
 */

__attribute__((constructor))
static void locale_fix_init(void) {
    if (!setlocale(LC_ALL, "")) {
        LOG("Failed to set locale, falling back to C locale.");
        if (!setlocale(LC_ALL, "C")) {
            LOG("Failed to setlocale(LC_ALL, \"C\"): %s", strerror(errno));
        }
        if (setenv("LC_ALL", "C", 1) != 0) {
            LOG("Failed to setenv(LC_ALL, \"C\"): %s", strerror(errno));
        }
    }
}

