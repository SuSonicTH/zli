#include "fm_aux.h"

#include <stdlib.h>
#include <string.h>

// TODO: Test writelines and writefile functions
// TODO: fw_aux_tabletostring: fix crash with bigger tables (stack problem?)

int luaopen_lwaux(lua_State *L) {
    luaL_newlib(L, fw_auxlib);
    return 1;
}

int fw_aux_extend_libs(lua_State *L) {
    lua_settop(L, 0);

    lua_getglobal(L, "string");
    if (!lua_isnil(L, -1)) {
        luax_settable_cfunction(L, 1, "split", fw_aux_split);
        luax_settable_cfunction(L, 1, "trim", fw_aux_trim);
        luax_settable_cfunction(L, 1, "ltrim", fw_aux_ltrim);
        luax_settable_cfunction(L, 1, "rtrim", fw_aux_rtrim);
    }
    lua_pop(L, 1);

    lua_getglobal(L, "table");
    if (!lua_isnil(L, -1)) {
        luax_settable_cfunction(L, 1, "mergesort", fw_aux_mergesort_ext);
        luax_settable_cfunction(L, 1, "kpairs", fw_aux_kpairs);
        luax_settable_cfunction(L, 1, "copy", fw_aux_copy_table);
        luax_settable_cfunction(L, 1, "concats", fw_aux_concats);
        luax_settable_cfunction(L, 1, "tostring", fw_aux_tabletostring);
    }
    lua_pop(L, 1);

    lua_getglobal(L, "io");
    if (!lua_isnil(L, -1)) {
        luax_settable_cfunction(L, 1, "readlines", fw_aux_readlines);
        luax_settable_cfunction(L, 1, "readfile", fw_aux_readfile);
        luax_settable_cfunction(L, 1, "writelines", fw_aux_writelines);
        luax_settable_cfunction(L, 1, "writefile", fw_aux_writefile);
    }
    lua_pop(L, 1);

    return 0;
}

int fw_aux_split(lua_State *L) {
    const char *seperator;
    char sep = ',';
    const char *string;
    const char *cpos, *spos, *epos;
    size_t len;
    int cnt = 0;
    size_t clen;

    if (lua_isstring(L, 2)) {
        seperator = lua_tostring(L, 2);
        sep = seperator[0];
    }

    if ((string = lua_tolstring(L, 1, &len)) == NULL) {
        return 0;
    }

    cpos = string;
    spos = string;
    epos = string + len - 1;

    while (cpos <= epos) {
        if (*cpos == sep) {
            lua_checkstack(L, 1);
            clen = cpos - spos;
            if (!clen) {
                lua_pushstring(L, "");
            } else {
                lua_pushlstring(L, spos, cpos - spos);
            }
            spos = cpos + 1;
            cnt++;
        }
        cpos++;
    }

    lua_checkstack(L, 1);
    clen = cpos - spos;
    if (!clen) {
        lua_pushstring(L, "");
    } else {
        lua_pushlstring(L, spos, cpos - spos);
    }
    cnt++;

    return cnt;
}

int fw_aux_trim(lua_State *L) {
    const char *spos;
    const char *epos;
    size_t len;

    spos = lua_tolstring(L, 1, &len);
    if (spos == NULL || len == 0) {
        lua_pushstring(L, "");
        return 1;
    }
    epos = spos + len - 1;

    while (spos < epos && (*spos == ' ' || *spos == '\t' || *spos == '\r' || *spos == '\n' || *spos == 0)) {
        spos++;
    }

    while (epos >= spos && (*epos == ' ' || *epos == '\t' || *epos == '\r' || *epos == '\n' || *epos == 0)) {
        epos--;
    }

    if ((len = epos - spos + 1) > 0) {
        lua_pushlstring(L, spos, len);
    } else {
        lua_pushstring(L, "");
    }

    return 1;
}

int fw_aux_ltrim(lua_State *L) {
    const char *spos;
    const char *epos;
    size_t len;

    spos = lua_tolstring(L, 1, &len);
    epos = spos + len;

    while (spos < epos && (*spos == ' ' || *spos == '\t' || *spos == '\r' || *spos == '\n' || *spos == 0)) {
        spos++;
    }

    lua_pushlstring(L, spos, epos - spos);
    return 1;
}

int fw_aux_rtrim(lua_State *L) {
    const char *spos;
    const char *epos;
    size_t len;

    spos = lua_tolstring(L, 1, &len);
    epos = spos + len - 1;

    while (epos > spos && (*epos == ' ' || *epos == '\t' || *epos == '\r' || *epos == '\n' || *epos == 0)) {
        epos--;
    }

    lua_pushlstring(L, spos, epos - spos + 1);
    return 1;
}

/* Mergesort */
int fw_aux_chek_lte(lua_State *L, int *al, int *bl, int a, int b, int idx, int func) {
    int ret;

    if (func) {
        lua_pushvalue(L, func);
        lua_rawgeti(L, idx, al[a]);
        lua_rawgeti(L, idx, bl[b]);
        lua_call(L, 2, 1);
        ret = lua_toboolean(L, -1);
        lua_pop(L, 1);
    } else {
        lua_rawgeti(L, idx, al[a]);
        lua_rawgeti(L, idx, bl[b]);
        ret = lua_lessthan(L, -2, -1) || lua_equal(L, -1, -2);
        lua_pop(L, 2);
    }
    return ret;
}

int *fw_aux_mergesort_sublist(lua_State *L, int *in, int *tmp, int len, int idx, int func) {
    switch (len) {
        case 3:
            if (fw_aux_chek_lte(L, in, in, 0, 1, idx, func)) {
                if (fw_aux_chek_lte(L, in, in, 1, 2, idx, func)) {
                    tmp[0] = in[0];
                    tmp[1] = in[1];
                    tmp[2] = in[2];
                } else {
                    if (fw_aux_chek_lte(L, in, in, 0, 2, idx, func)) {
                        tmp[0] = in[0];
                        tmp[1] = in[2];
                        tmp[2] = in[1];
                    } else {
                        tmp[0] = in[2];
                        tmp[1] = in[0];
                        tmp[2] = in[1];
                    }
                }
            } else {
                if (fw_aux_chek_lte(L, in, in, 1, 2, idx, func)) {
                    if (fw_aux_chek_lte(L, in, in, 0, 2, idx, func)) {
                        tmp[0] = in[1];
                        tmp[1] = in[0];
                        tmp[2] = in[2];
                    } else {
                        tmp[0] = in[1];
                        tmp[1] = in[2];
                        tmp[2] = in[0];
                    }
                } else {
                    tmp[0] = in[2];
                    tmp[1] = in[1];
                    tmp[2] = in[0];
                }
            }
            return tmp;
            break;
        case 2:
            if (fw_aux_chek_lte(L, in, in, 0, 1, idx, func)) {
                tmp[0] = in[0];
                tmp[1] = in[1];
            } else {
                tmp[0] = in[1];
                tmp[1] = in[0];
            }
            return tmp;
            break;
        default:
            return fw_aux_mergesort_impl(L, in, tmp, len, idx, func);
            break;
    }
}

int *fw_aux_mergesort_impl(lua_State *L, int *in, int *tmp, int len, int idx, int func) {
    int *lt, *rt;
    int lp = 0, rp = 0;
    int ls, rs;
    int *out;
    int cnt = 0;

    // sort left sublist
    ls = len / 2;
    lt = fw_aux_mergesort_sublist(L, in, tmp, ls, idx, func);

    // sort right sublist
    rs = len - ls;
    rt = fw_aux_mergesort_sublist(L, in + ls, tmp + ls, rs, idx, func);

    // allocate output list
    out = malloc(sizeof(int) * len);

    // check left against right list and merge them sorted in output list
    if (func) {
        while (lp < ls && rp < rs) {
            lua_pushvalue(L, func);
            lua_rawgeti(L, idx, lt[lp]);
            lua_rawgeti(L, idx, rt[rp]);
            lua_call(L, 2, 1);
            if (lua_toboolean(L, -1)) {
                out[cnt++] = lt[lp++];
            } else {
                out[cnt++] = rt[rp++];
            }
            lua_pop(L, 1);
        }
    } else {
        while (lp < ls && rp < rs) {
            lua_rawgeti(L, idx, lt[lp]);
            lua_rawgeti(L, idx, rt[rp]);
            if (lua_lessthan(L, -2, -1) || lua_equal(L, -2, -1)) {
                out[cnt++] = lt[lp++];
            } else {
                out[cnt++] = rt[rp++];
            }
            lua_pop(L, 2);
        }
    }

    // copy all values from left table into output list
    while (lp < ls) {
        out[cnt++] = lt[lp++];
    }

    // copy all values from right table into output list
    while (rp < rs) {
        out[cnt++] = rt[rp++];
    }

    // Free left and right list if we allocated them
    if (ls > 3) {
        free(lt);
    }
    if (rs > 3) {
        free(rt);
    }
    return out;
}

int *fw_aux_mergesort_arr(lua_State *L, int idx, int func, unsigned int *tlen) {
    int *in, *out, *tmp;
    unsigned int i;
    unsigned int len = (unsigned int)lua_objlen(L, idx);

    if (tlen != NULL) {
        *tlen = len;
    }

    // check for empty and single item table and immediatly return result
    if (len == 0) {
        return NULL;
    } else if (len == 1) {
        out = malloc(sizeof(int));
        *out = 1;
        return out;
    }

    // create an arry and write table indexes from 1 to tablelen into it
    in = malloc(sizeof(int) * len);
    for (i = 0; i < len; i++) {
        in[i] = i + 1;
    }
    // create working space for subarrays of lenght 2 and 3
    tmp = malloc(sizeof(int) * len);

    if (len <= 3) {
        // the array has only 2 or 3 elements -> sort them by fixed sorting
        out = fw_aux_mergesort_sublist(L, in, tmp, len, idx, func);
    } else {
        // sort in array with merge sort and get sorted data back in out
        out = fw_aux_mergesort_impl(L, in, tmp, len, idx, func);
        free(tmp);
    }
    free(in);
    return out;
}

int fw_aux_mergesort_int(lua_State *L, int idx, int func, int copy) {
    int *out;
    int len;
    int i, n;

    out = fw_aux_mergesort_arr(L, idx, func, &len);

    // write sorted table entries in return table
    lua_newtable(L);
    n = lua_gettop(L);
    for (i = 0; i < len; i++) {
        lua_rawgeti(L, idx, out[i]);
        lua_rawseti(L, n, i + 1);
    }

    // copy sorted data back to original table if arg 3 is true
    if (copy) {
        for (i = 1; i <= len; i++) {
            lua_rawgeti(L, n, i);
            lua_rawseti(L, idx, i);
        }
    }

    free(out);
    return 1;
}

int fw_aux_mergesort_ext(lua_State *L) {
    unsigned int len = (unsigned int)lua_objlen(L, 1);
    int func = lua_isfunction(L, 2);
    int copy = lua_toboolean(L, 3);

    fw_aux_mergesort_int(L, 1, func ? 2 : 0, copy);

    return 1;
}

int fw_aux_kpairs(lua_State *L) {
    int i = 1;
    int func = lua_isfunction(L, 2);

    // create array with table key
    lua_newtable(L);
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        lua_pop(L, 1);
        lua_pushvalue(L, -1);
        lua_rawseti(L, 2, i++);
    }
    // call table.sort
    if (func) {
        lua_pushvalue(L, -1);
        lua_pushvalue(L, 2);
        luax_call_lib(L, "table", "sort", 2, 0, 1);
    } else {
        luax_call_lib(L, "table", "sort", 1, 0, 0);
    }

    // push iterator function
    lua_pushvalue(L, 1);
    lua_pushnumber(L, 1);
    lua_pushcclosure(L, fw_aux_kpairs_iter, 3);

    return 1;
}

int fw_aux_kpairs_iter(lua_State *L) {
    unsigned int i = (unsigned int)lua_tonumber(L, lua_upvalueindex(3));
    lua_rawgeti(L, lua_upvalueindex(1), i);
    lua_pushvalue(L, -1);
    lua_gettable(L, lua_upvalueindex(2));
    lua_pushnumber(L, ++i);
    lua_replace(L, lua_upvalueindex(3));
    return 2;
}

int fw_aux_copy_table(lua_State *L) {
    int t = lua_gettop(L);
    int n = t + 1;
    lua_newtable(L);
    lua_pushnil(L);
    while (lua_next(L, t)) {
        if (lua_istable(L, -1)) {
            fw_aux_copy_table(L);
            lua_pushvalue(L, -3);  // key
            lua_pushvalue(L, -2);  // value
            lua_rawset(L, n);
            lua_pop(L, 2);
        } else {
            lua_pushvalue(L, -2);  // key
            lua_pushvalue(L, -2);  // value
            lua_rawset(L, n);
            lua_pop(L, 1);
        }
    }
    return 1;
}

int fw_aux_concats(lua_State *L) {
    luaL_Buffer buffer;
    unsigned int len = (unsigned int)lua_objlen(L, 1);
    const char *sep = NULL;
    size_t seplen;
    const char *itm;
    size_t itmlen;
    unsigned int i;

    if (!lua_isnoneornil(L, 2)) {
        sep = lua_tolstring(L, 2, &seplen);
    }

    luaL_buffinit(L, &buffer);
    for (i = 1; i <= len; i++) {
        lua_rawgeti(L, 1, i);
        itm = lua_tolstring(L, -1, &itmlen);
        lua_pop(L, 1);

        luaL_addlstring(&buffer, itm, itmlen);
        if (sep && i < len) {
            luaL_addlstring(&buffer, sep, seplen);
        }
    }
    luaL_pushresult(&buffer);
    return 1;
}

int fw_aux_readfile(lua_State *L) {
    FILE *fh;
    char *buffer;
    size_t len;
    const char *filename = lua_tostring(L, 1);

    // open file
    if ((fh = fopen(filename, "rb")) == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "Could not open file!");
    }

    // get filesize
    fseek(fh, 0, SEEK_END);
    len = ftell(fh);
    fseek(fh, 0, SEEK_SET);

    // alloc buffer
    if ((buffer = malloc(len)) == NULL) {
        fclose(fh);
        lua_pushnil(L);
        lua_pushstring(L, "Could not allocate buffer");
    }

    // read file
    len = fread(buffer, 1, len, fh);

    // push buffer
    lua_pushlstring(L, buffer, len);

    // cleanup
    free(buffer);
    fclose(fh);

    return 1;
}

int fw_aux_readlines(lua_State *L) {
    FILE *fh;
    char *buffer, *spos, *cpos, *epos;
    unsigned int len, n, i = 0;
    const char *filename = lua_tostring(L, 1);

    // open file
    if ((fh = fopen(filename, "rb")) == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "Could not open file!");
    }

    // get filesize
    fseek(fh, 0, SEEK_END);
    len = ftell(fh);
    fseek(fh, 0, SEEK_SET);

    // alloc buffer
    if ((buffer = malloc(len)) == NULL) {
        fclose(fh);
        lua_pushnil(L);
        lua_pushstring(L, "Could not allocate buffer");
    }

    // read file
    len = (unsigned int)fread(buffer, 1, len, fh);
    fclose(fh);

    // create return table
    lua_newtable(L);
    n = lua_gettop(L);

    // add line after line to table
    spos = buffer;
    epos = buffer + len;
    cpos = spos;
    while (cpos <= epos) {
        while (cpos <= epos && *cpos != '\r' && *cpos != '\n') {
            cpos++;
        }
        lua_pushlstring(L, spos, cpos - spos);
        lua_rawseti(L, n, i++);
        if (*cpos == '\r' && cpos < epos && *(cpos + 1) == '\n') {
            cpos++;
        }
        cpos++;
        spos = cpos;
    }

    // cleanup
    free(buffer);

    return 1;
}

int fw_aux_writefile(lua_State *L) {
    size_t len;
    const char *data;
    const char *filename = lua_tostring(L, 1);
    FILE *fh;

    // open file
    if ((fh = fopen(filename, "wb")) == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "Could not open file!");
    }

    // get data
    data = lua_tolstring(L, 2, &len);

    // write data
    if (fwrite(data, 1, len, fh) != len) {
        lua_pushnil(L);
        lua_pushstring(L, "Could not write data");
    }

    // cleanup
    fclose(fh);

    lua_pushboolean(L, 1);
    return 1;
}

int fw_aux_writelines(lua_State *L) {
    unsigned int tlen = (unsigned int)lua_objlen(L, 2);
    size_t len;
    unsigned int i;
    const char *data;
    const char *le = lua_tostring(L, 3);
    const char *filename = lua_tostring(L, 1);
    FILE *fh;

    if (le == NULL) {
        le = "\r\n";
    }

    // open file
    if ((fh = fopen(filename, "wb")) == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "Could not open file!");
    }

    // write lines
    for (i = 1; i <= tlen; i++) {
        lua_rawgeti(L, 2, i);
        data = lua_tolstring(L, -1, &len);
        fwrite(data, 1, len, fh);
        if (le)
            fwrite(data, 1, len, fh);
        lua_pop(L, 1);
    }

    // cleanup
    fclose(fh);

    lua_pushboolean(L, 1);
    return 1;
}

/* String Buffer */

const char fm_sb_dontcopy = 0;
const char fm_sb_copy = 1;
const char fm_sb_iscopy = 2;

#include <stdlib.h>

fm_sb *fm_sb_init(fm_sb *sb) {
    sb->last = NULL;
    sb->root = NULL;
    sb->len = 0;
}

void fm_sb_add(fm_sb *sb, const char *str, int len, char copy) {
    fm_sb_node *node = malloc(sizeof(fm_sb_node));

    if (len < 0) {
        len = strlen(str);
    }
    if (copy == fm_sb_copy) {
        node->str = malloc(len + 1);
        memcpy(node->str, str, len + 1);
    } else {
        node->str = (char *)str;
    }

    node->len = len;
    node->copy = copy;
    node->next = NULL;

    if (sb->last != NULL) {
        sb->last->next = node;
    } else {
        sb->root = node;
    }

    sb->last = node;
    sb->len += len;
}

char *fm_sb_concat(fm_sb *sb, unsigned int *len) {
    char *str = NULL;
    const char *cpos;
    char *dpos;
    int i;
    fm_sb_node *cnode, *dnode;

    if (len != NULL) {
        *len = sb->len;
    }

    if (sb->len == 0) {
        return NULL;
    }

    if (sb->root != sb->last) {
        str = malloc(sb->len + 1);
        dpos = str;
        cnode = sb->root;
        while (cnode) {
            cpos = cnode->str;
            for (i = 0; i < cnode->len; i++) {
                *dpos++ = *cpos++;
            }
            if (cnode->copy) {
                free(cnode->str);
            }
            dnode = cnode;
            cnode = cnode->next;
            free(dnode);
        }
        *dpos = 0;

        cnode = malloc(sizeof(fm_sb_node));
        cnode->str = str;
        cnode->len = sb->len;
        cnode->copy = fm_sb_iscopy;
        cnode->next = NULL;
        sb->root = cnode;
        sb->last = cnode;
    } else {
        str = sb->root->str;
    }

    return str;
}

void fm_sb_free(fm_sb *sb) {
    fm_sb_node *cnode, *dnode;
    cnode = sb->root;
    while (cnode) {
        if (cnode->copy) {
            free(cnode->str);
        }
        dnode = cnode;
        cnode = cnode->next;
        free(dnode);
    }
    fm_sb_init(sb);
}

int fw_aux_tabletostring(lua_State *L) {
    fm_sb buffer;
    const char *name = lua_tostring(L, 2);
    const char *le = lua_tostring(L, 3);
    const char *ind = lua_tostring(L, 4);
    char *ret;
    int lvl = 0;
    unsigned int retlen;

    if (le == NULL)
        le = "\n";
    if (ind == NULL)
        ind = "  ";

    fm_sb_init(&buffer);
    if (name != NULL) {
        fm_sb_add(&buffer, name, -1, fm_sb_copy);
        fm_sb_add(&buffer, "={", 2, fm_sb_dontcopy);
        fm_sb_add(&buffer, le, -1, fm_sb_dontcopy);
        lvl++;
    }

    lua_pushvalue(L, 1);
    fw_aux_tabletostring_traverse(L, &buffer, lvl, le, ind);

    if (name != NULL) {
        fm_sb_add(&buffer, "}", 1, fm_sb_dontcopy);
    }

    ret = fm_sb_concat(&buffer, &retlen);
    lua_pushlstring(L, ret, retlen);
    fm_sb_free(&buffer);

    return 1;
}

void fw_aux_tabletostring_traverse(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind) {
    int n = lua_gettop(L);
    unsigned int i = 1;
    unsigned int len = (unsigned int)lua_objlen(L, n);
    double num;

    lua_checkstack(L, n + 4);
    for (i = 1; i <= len; i++) {
        lua_pushnumber(L, i);
        lua_rawgeti(L, n, i);
        fw_aux_tabletostring_additem(L, buffer, lvl, le, ind, 1);
        lua_pop(L, 2);
    }

    lua_pushnil(L);
    while (lua_next(L, n)) {
        if (lua_isnumber(L, -2)) {
            num = lua_tonumber(L, -2);
            if (num < 1 || num > len || num != (int)num) {
                lua_pushvalue(L, -2);
                lua_pushvalue(L, -2);
                fw_aux_tabletostring_additem(L, buffer, lvl, le, ind, 0);
                lua_pop(L, 3);
            } else {
                lua_pop(L, 1);
            }
        } else {
            lua_pushvalue(L, -2);
            lua_pushvalue(L, -2);
            fw_aux_tabletostring_additem(L, buffer, lvl, le, ind, 0);
            lua_pop(L, 3);
        }
    }
}

// TODO: fw_aux_tabletostring_additem: Hash Tables used and don't reuse them
void fw_aux_tabletostring_additem(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind, int seq) {
    const char *cpos, *epos;
    const char *key;
    size_t keylen;
    const char *value;
    int l;
    int quoutekey = 0;

    value = lua_tostring(L, -1);

    if (value == NULL && !lua_istable(L, -1)) {
        return;
    }

    for (l = 1; l <= lvl; l++) {
        fm_sb_add(buffer, ind, -1, fm_sb_dontcopy);
    }

    if (!seq) {
        key = lua_tolstring(L, -2, &keylen);

        if (key[0] == '_' || (key[0] > 'A' && key[0] < 'Z') || (key[0] > 'a' && key[0] < 'z')) {
            cpos = key;
            epos = key + keylen;
            while (cpos < epos && *cpos == '_' || (*cpos > 'A' && *cpos < 'Z') || (*cpos > 'a' && *cpos < 'z') || (*cpos > '0' && *cpos < '9')) {
                cpos++;
            }
            if (cpos != epos) {
                quoutekey = 1;
            }
        } else {
            quoutekey = 1;
        }

        if (quoutekey) {
            fm_sb_add(buffer, "['", 2, fm_sb_dontcopy);
            // TODO: fw_aux_tabletostring_additem: escape special characters
            fm_sb_add(buffer, key, -1, fm_sb_copy);
            fm_sb_add(buffer, "']=", 3, fm_sb_dontcopy);
        } else {
            fm_sb_add(buffer, key, -1, fm_sb_copy);
            fm_sb_add(buffer, "=", 1, fm_sb_dontcopy);
        }
    }

    if (lua_istable(L, -1)) {
        fm_sb_add(buffer, "{", 1, fm_sb_dontcopy);
        fm_sb_add(buffer, le, -1, fm_sb_dontcopy);
        fw_aux_tabletostring_traverse(L, buffer, lvl + 1, le, ind);
        for (l = 1; l <= lvl; l++) {
            fm_sb_add(buffer, ind, -1, fm_sb_dontcopy);
        }
        fm_sb_add(buffer, "},", 2, fm_sb_dontcopy);
        fm_sb_add(buffer, le, -1, fm_sb_dontcopy);
    } else if (lua_isnumber(L, -1)) {
        fm_sb_add(buffer, value, -1, fm_sb_copy);
        fm_sb_add(buffer, ",", 1, fm_sb_dontcopy);
        fm_sb_add(buffer, le, -1, fm_sb_dontcopy);
    } else {
        // TODO: fw_aux_tabletostring_additem: Check for Functions
        fm_sb_add(buffer, "\"", 1, fm_sb_dontcopy);
        fm_sb_add(buffer, value, -1, fm_sb_copy);
        fm_sb_add(buffer, "\",", 2, fm_sb_dontcopy);
        fm_sb_add(buffer, le, -1, fm_sb_dontcopy);
    }
}
