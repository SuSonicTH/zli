#include <zip.h>
void filetime_to_ziptime(const char *filename, zip_fileinfo *zfi);
void systemtime_to_ziptime(zip_fileinfo *zfi);
