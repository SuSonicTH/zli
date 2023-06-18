#ifndef FM_PAYLOAD_INCLUDED
#define FM_PAYLOAD_INCLUDED

#include "fm_sbuilder.h"
#include "lauxlib.h"
#include "unzip.h"

#define FM_PAYLOAD_BUFFER_SIZE 4096

void create_payload_searcher(lua_State *L, char *exename);

#endif  // FM_PAYLOAD_INCLUDED