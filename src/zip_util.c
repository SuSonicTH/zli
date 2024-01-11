#include "zip_util.h"

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
        FindClose(ffh);
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
#include <time.h>

void filetime_to_ziptime(const char *filename, zip_fileinfo *zfi) {
    struct stat s;

    if (stat(name, &s) != 0) {
        return 0;
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