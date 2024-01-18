#include "timer.h"

#ifdef _WIN32

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

double nanotime(void) {
    static double multiplier = 0;

    if (multiplier == 0) {
        LARGE_INTEGER freq;
        QueryPerformanceFrequency(&freq);
        multiplier = 1.0 / (double)freq.QuadPart;
    }

    LARGE_INTEGER timer;
    QueryPerformanceCounter(&timer);
    return timer.QuadPart * multiplier;
}

#else  // linux

#include <time.h>

double nanotime(void) {
    const double multiplier = 1.0 / 1e9;
    struct timespec ts;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }
    return ts.tv_sec + (ts.tv_nsec * multiplier);
}

#endif
