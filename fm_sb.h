#ifndef FM_SB_INCLUDED
#define FM_SB_INCLUDED

#define FM_SB_DONTCOPY 0
#define FM_SB_COPY 1
#define FM_SB_ISCOPY 2

#define fm_sb_add_constant(sb, str) fm_sb_add(sb, str, sizeof(str) - 1, FM_SB_DONTCOPY)
#define fm_sb_add_string_copy(sb, str) fm_sb_add(sb, str, - 1, FM_SB_COPY)
#define fm_sb_add_string(sb, str) fm_sb_add(sb, str, - 1, FM_SB_DONTCOPY)

typedef struct fm_sb_node {
    char *str;
    char copy;
    unsigned int len;
    struct fm_sb_node *next;
} fm_sb_node;

typedef struct fm_sb {
    fm_sb_node *root;
    fm_sb_node *last;
    unsigned int len;
} fm_sb;

fm_sb *fm_sb_alloc();

void fm_sb_add(fm_sb *sb, const char *str, int len, char copy);

char *fm_sb_concat(fm_sb *sb, unsigned int *len);

void fm_sb_free(fm_sb *sb);

#endif  // FM_SB_INCLUDED