#include "fm_sb.h"
#include <stdlib.h>
#include <string.h>

fm_sb *fm_sb_init(fm_sb *sb) {
    sb->last = NULL;
    sb->root = NULL;
    sb->len = 0;
    return sb;
}

fm_sb *fm_sb_alloc() {
    fm_sb *sb=malloc(sizeof(fm_sb));
    fm_sb_init(sb);
    return sb;
}

void fm_sb_add(fm_sb *sb, const char *str, int len, char copy) {
    fm_sb_node *node = malloc(sizeof(fm_sb_node));

    if (len < 0) {
        len = strlen(str);
    }
    if (len==0){
        return;
    }

    if (copy == FM_SB_COPY) {
        node->str = malloc(len + 1);
        memcpy(node->str, str, len);
        node->str[len]=0;
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
        return "";
    }

    if (sb->root == sb->last) {
        return sb->root->str;
    }

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
    cnode->copy = FM_SB_ISCOPY;
    cnode->next = NULL;
    sb->root = cnode;
    sb->last = cnode;

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
    free(sb);
}
