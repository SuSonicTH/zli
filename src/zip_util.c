#include "zip_util.h"

#include <time.h>

#ifdef _WIN32

#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

void filetime_to_ziptime(const char *filename, zip_fileinfo *zfi) {
    WIN32_FIND_DATA ffd;
    HANDLE ffh = NULL;
    SYSTEMTIME st;
    SYSTEMTIME lt;

    if ((ffh = FindFirstFile(filename, &ffd)) == INVALID_HANDLE_VALUE) {
        return;
    }
    FindClose(ffh);

    FileTimeToSystemTime(&ffd.ftLastWriteTime, &st);
    SystemTimeToTzSpecificLocalTime(NULL, &st, &lt);

    zfi->tmz_date.tm_year = lt.wYear;
    zfi->tmz_date.tm_mon = lt.wMonth - 1;
    zfi->tmz_date.tm_mday = lt.wDay;
    zfi->tmz_date.tm_hour = lt.wHour;
    zfi->tmz_date.tm_min = lt.wMinute;
    zfi->tmz_date.tm_sec = lt.wSecond;
    zfi->dosDate = 0;
    zfi->external_fa = 0;
    zfi->internal_fa = 0;
}

#else  // not _WIN32

#include <sys/stat.h>

void filetime_to_ziptime(const char *filename, zip_fileinfo *zfi) {
    struct stat s;

    if (stat(filename, &s) != 0) {
        return;
    }

    time_t tm_t = s.st_mtime;
    struct tm *filedate = localtime(&tm_t);

    zfi->tmz_date.tm_sec = filedate->tm_sec;
    zfi->tmz_date.tm_min = filedate->tm_min;
    zfi->tmz_date.tm_hour = filedate->tm_hour;
    zfi->tmz_date.tm_mday = filedate->tm_mday;
    zfi->tmz_date.tm_mon = filedate->tm_mon;
    zfi->tmz_date.tm_year = filedate->tm_year;
    zfi->dosDate = 0;
    zfi->external_fa = 0;
    zfi->internal_fa = 0;
}
#endif

void systemtime_to_ziptime(zip_fileinfo *zfi) {
    time_t tm_t = 0;
    struct tm *systemTime;
    time(&tm_t);
    systemTime = localtime(&tm_t);

    zfi->tmz_date.tm_sec = systemTime->tm_sec;
    zfi->tmz_date.tm_min = systemTime->tm_min;
    zfi->tmz_date.tm_hour = systemTime->tm_hour;
    zfi->tmz_date.tm_mday = systemTime->tm_mday;
    zfi->tmz_date.tm_mon = systemTime->tm_mon;
    zfi->tmz_date.tm_year = systemTime->tm_year;
    zfi->dosDate = 0;
    zfi->external_fa = 0;
    zfi->internal_fa = 0;
}
