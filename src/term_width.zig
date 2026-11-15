//! UTF-8 decoding, terminal display width and ANSI sequence helpers shared by
//! the line editor and the pager.
//!
//! The width table is intentionally small and hand written: ASCII is one
//! column, East Asian wide characters and most emoji are two columns, and
//! combining marks and variation selectors are zero columns.

const std = @import("std");

pub const Decoded = struct {
    codepoint: u21,
    len: usize,
};

const Interval = struct { first: u21, last: u21 };

const wide = [_]Interval{
    .{ .first = 0x1100, .last = 0x115f },
    .{ .first = 0x231a, .last = 0x231b },
    .{ .first = 0x2329, .last = 0x232a },
    .{ .first = 0x23e9, .last = 0x23ec },
    .{ .first = 0x23f0, .last = 0x23f0 },
    .{ .first = 0x23f3, .last = 0x23f3 },
    .{ .first = 0x25fd, .last = 0x25fe },
    .{ .first = 0x2614, .last = 0x2615 },
    .{ .first = 0x2648, .last = 0x2653 },
    .{ .first = 0x267f, .last = 0x267f },
    .{ .first = 0x2693, .last = 0x2693 },
    .{ .first = 0x26a1, .last = 0x26a1 },
    .{ .first = 0x26aa, .last = 0x26ab },
    .{ .first = 0x26bd, .last = 0x26be },
    .{ .first = 0x26c4, .last = 0x26c5 },
    .{ .first = 0x26ce, .last = 0x26ce },
    .{ .first = 0x26d4, .last = 0x26d4 },
    .{ .first = 0x26ea, .last = 0x26ea },
    .{ .first = 0x26f2, .last = 0x26f3 },
    .{ .first = 0x26f5, .last = 0x26f5 },
    .{ .first = 0x26fa, .last = 0x26fa },
    .{ .first = 0x26fd, .last = 0x26fd },
    .{ .first = 0x2705, .last = 0x2705 },
    .{ .first = 0x270a, .last = 0x270b },
    .{ .first = 0x2728, .last = 0x2728 },
    .{ .first = 0x274c, .last = 0x274c },
    .{ .first = 0x274e, .last = 0x274e },
    .{ .first = 0x2753, .last = 0x2755 },
    .{ .first = 0x2757, .last = 0x2757 },
    .{ .first = 0x2795, .last = 0x2797 },
    .{ .first = 0x27b0, .last = 0x27b0 },
    .{ .first = 0x27bf, .last = 0x27bf },
    .{ .first = 0x2b1b, .last = 0x2b1c },
    .{ .first = 0x2b50, .last = 0x2b50 },
    .{ .first = 0x2b55, .last = 0x2b55 },
    .{ .first = 0x2e80, .last = 0x303e },
    .{ .first = 0x3041, .last = 0x33ff },
    .{ .first = 0x3400, .last = 0x4dbf },
    .{ .first = 0x4e00, .last = 0x9fff },
    .{ .first = 0xa000, .last = 0xa4cf },
    .{ .first = 0xa960, .last = 0xa97f },
    .{ .first = 0xac00, .last = 0xd7a3 },
    .{ .first = 0xf900, .last = 0xfaff },
    .{ .first = 0xfe10, .last = 0xfe19 },
    .{ .first = 0xfe30, .last = 0xfe6f },
    .{ .first = 0xff00, .last = 0xff60 },
    .{ .first = 0xffe0, .last = 0xffe6 },
    .{ .first = 0x16fe0, .last = 0x16fe4 },
    .{ .first = 0x17000, .last = 0x18cd5 },
    .{ .first = 0x1b000, .last = 0x1b2fb },
    .{ .first = 0x1f004, .last = 0x1f004 },
    .{ .first = 0x1f0cf, .last = 0x1f0cf },
    .{ .first = 0x1f18e, .last = 0x1f18e },
    .{ .first = 0x1f191, .last = 0x1f19a },
    .{ .first = 0x1f200, .last = 0x1f2ff },
    .{ .first = 0x1f300, .last = 0x1f64f },
    .{ .first = 0x1f680, .last = 0x1f6ff },
    .{ .first = 0x1f7e0, .last = 0x1f7eb },
    .{ .first = 0x1f90c, .last = 0x1f9ff },
    .{ .first = 0x1fa70, .last = 0x1faff },
    .{ .first = 0x20000, .last = 0x2fffd },
    .{ .first = 0x30000, .last = 0x3fffd },
};

const zero_width = [_]Interval{
    .{ .first = 0x0300, .last = 0x036f },
    .{ .first = 0x0483, .last = 0x0489 },
    .{ .first = 0x0591, .last = 0x05bd },
    .{ .first = 0x05bf, .last = 0x05bf },
    .{ .first = 0x05c1, .last = 0x05c2 },
    .{ .first = 0x05c4, .last = 0x05c5 },
    .{ .first = 0x05c7, .last = 0x05c7 },
    .{ .first = 0x0610, .last = 0x061a },
    .{ .first = 0x064b, .last = 0x065f },
    .{ .first = 0x0670, .last = 0x0670 },
    .{ .first = 0x06d6, .last = 0x06dc },
    .{ .first = 0x06df, .last = 0x06e4 },
    .{ .first = 0x06e7, .last = 0x06e8 },
    .{ .first = 0x06ea, .last = 0x06ed },
    .{ .first = 0x0711, .last = 0x0711 },
    .{ .first = 0x0730, .last = 0x074a },
    .{ .first = 0x07a6, .last = 0x07b0 },
    .{ .first = 0x07eb, .last = 0x07f3 },
    .{ .first = 0x0816, .last = 0x082d },
    .{ .first = 0x0859, .last = 0x085b },
    .{ .first = 0x08d3, .last = 0x0902 },
    .{ .first = 0x093a, .last = 0x093a },
    .{ .first = 0x093c, .last = 0x093c },
    .{ .first = 0x0941, .last = 0x0948 },
    .{ .first = 0x094d, .last = 0x094d },
    .{ .first = 0x0951, .last = 0x0957 },
    .{ .first = 0x0962, .last = 0x0963 },
    .{ .first = 0x0981, .last = 0x0981 },
    .{ .first = 0x09bc, .last = 0x09bc },
    .{ .first = 0x09c1, .last = 0x09c4 },
    .{ .first = 0x09cd, .last = 0x09cd },
    .{ .first = 0x0a01, .last = 0x0a02 },
    .{ .first = 0x0a3c, .last = 0x0a3c },
    .{ .first = 0x0a41, .last = 0x0a42 },
    .{ .first = 0x0a47, .last = 0x0a48 },
    .{ .first = 0x0a4b, .last = 0x0a4d },
    .{ .first = 0x0a51, .last = 0x0a51 },
    .{ .first = 0x0a70, .last = 0x0a71 },
    .{ .first = 0x0a75, .last = 0x0a75 },
    .{ .first = 0x0a81, .last = 0x0a82 },
    .{ .first = 0x0abc, .last = 0x0abc },
    .{ .first = 0x0ac1, .last = 0x0ac5 },
    .{ .first = 0x0ac7, .last = 0x0ac8 },
    .{ .first = 0x0acd, .last = 0x0acd },
    .{ .first = 0x0ae2, .last = 0x0ae3 },
    .{ .first = 0x0b01, .last = 0x0b01 },
    .{ .first = 0x0b3c, .last = 0x0b3c },
    .{ .first = 0x0b3f, .last = 0x0b3f },
    .{ .first = 0x0b41, .last = 0x0b44 },
    .{ .first = 0x0b4d, .last = 0x0b4d },
    .{ .first = 0x0b56, .last = 0x0b56 },
    .{ .first = 0x0b62, .last = 0x0b63 },
    .{ .first = 0x0b82, .last = 0x0b82 },
    .{ .first = 0x0bc0, .last = 0x0bc0 },
    .{ .first = 0x0bcd, .last = 0x0bcd },
    .{ .first = 0x0c00, .last = 0x0c00 },
    .{ .first = 0x0c04, .last = 0x0c04 },
    .{ .first = 0x0c3e, .last = 0x0c40 },
    .{ .first = 0x0c46, .last = 0x0c48 },
    .{ .first = 0x0c4a, .last = 0x0c4d },
    .{ .first = 0x0c55, .last = 0x0c56 },
    .{ .first = 0x0c62, .last = 0x0c63 },
    .{ .first = 0x0c81, .last = 0x0c81 },
    .{ .first = 0x0cbc, .last = 0x0cbc },
    .{ .first = 0x0cbf, .last = 0x0cbf },
    .{ .first = 0x0cc6, .last = 0x0cc6 },
    .{ .first = 0x0ccc, .last = 0x0ccd },
    .{ .first = 0x0ce2, .last = 0x0ce3 },
    .{ .first = 0x0d00, .last = 0x0d01 },
    .{ .first = 0x0d3b, .last = 0x0d3c },
    .{ .first = 0x0d41, .last = 0x0d44 },
    .{ .first = 0x0d4d, .last = 0x0d4d },
    .{ .first = 0x0d62, .last = 0x0d63 },
    .{ .first = 0x0dca, .last = 0x0dca },
    .{ .first = 0x0dd2, .last = 0x0dd4 },
    .{ .first = 0x0dd6, .last = 0x0dd6 },
    .{ .first = 0x0e31, .last = 0x0e31 },
    .{ .first = 0x0e34, .last = 0x0e3a },
    .{ .first = 0x0e47, .last = 0x0e4e },
    .{ .first = 0x0eb1, .last = 0x0eb1 },
    .{ .first = 0x0eb4, .last = 0x0ebc },
    .{ .first = 0x0ec8, .last = 0x0ecd },
    .{ .first = 0x0f18, .last = 0x0f19 },
    .{ .first = 0x0f35, .last = 0x0f35 },
    .{ .first = 0x0f37, .last = 0x0f37 },
    .{ .first = 0x0f39, .last = 0x0f39 },
    .{ .first = 0x0f71, .last = 0x0f7e },
    .{ .first = 0x0f80, .last = 0x0f84 },
    .{ .first = 0x0f86, .last = 0x0f87 },
    .{ .first = 0x0f8d, .last = 0x0f97 },
    .{ .first = 0x0f99, .last = 0x0fbc },
    .{ .first = 0x0fc6, .last = 0x0fc6 },
    .{ .first = 0x102d, .last = 0x1030 },
    .{ .first = 0x1032, .last = 0x1037 },
    .{ .first = 0x1039, .last = 0x103a },
    .{ .first = 0x103d, .last = 0x103e },
    .{ .first = 0x1058, .last = 0x1059 },
    .{ .first = 0x105e, .last = 0x1060 },
    .{ .first = 0x1071, .last = 0x1074 },
    .{ .first = 0x1082, .last = 0x1082 },
    .{ .first = 0x1085, .last = 0x1086 },
    .{ .first = 0x108d, .last = 0x108d },
    .{ .first = 0x109d, .last = 0x109d },
    .{ .first = 0x135d, .last = 0x135f },
    .{ .first = 0x1712, .last = 0x1714 },
    .{ .first = 0x1732, .last = 0x1734 },
    .{ .first = 0x1752, .last = 0x1753 },
    .{ .first = 0x1772, .last = 0x1773 },
    .{ .first = 0x17b4, .last = 0x17b5 },
    .{ .first = 0x17b7, .last = 0x17bd },
    .{ .first = 0x17c6, .last = 0x17c6 },
    .{ .first = 0x17c9, .last = 0x17d3 },
    .{ .first = 0x17dd, .last = 0x17dd },
    .{ .first = 0x180b, .last = 0x180d },
    .{ .first = 0x1885, .last = 0x1886 },
    .{ .first = 0x18a9, .last = 0x18a9 },
    .{ .first = 0x1920, .last = 0x1922 },
    .{ .first = 0x1927, .last = 0x1928 },
    .{ .first = 0x1932, .last = 0x1932 },
    .{ .first = 0x1939, .last = 0x193b },
    .{ .first = 0x1a17, .last = 0x1a18 },
    .{ .first = 0x1a1b, .last = 0x1a1b },
    .{ .first = 0x1a56, .last = 0x1a56 },
    .{ .first = 0x1a58, .last = 0x1a5e },
    .{ .first = 0x1a60, .last = 0x1a60 },
    .{ .first = 0x1a62, .last = 0x1a62 },
    .{ .first = 0x1a65, .last = 0x1a6c },
    .{ .first = 0x1a73, .last = 0x1a7c },
    .{ .first = 0x1a7f, .last = 0x1a7f },
    .{ .first = 0x1ab0, .last = 0x1ac0 },
    .{ .first = 0x1b00, .last = 0x1b03 },
    .{ .first = 0x1b34, .last = 0x1b34 },
    .{ .first = 0x1b36, .last = 0x1b3a },
    .{ .first = 0x1b3c, .last = 0x1b3c },
    .{ .first = 0x1b42, .last = 0x1b42 },
    .{ .first = 0x1b6b, .last = 0x1b73 },
    .{ .first = 0x1b80, .last = 0x1b81 },
    .{ .first = 0x1ba2, .last = 0x1ba5 },
    .{ .first = 0x1ba8, .last = 0x1ba9 },
    .{ .first = 0x1bab, .last = 0x1bad },
    .{ .first = 0x1be6, .last = 0x1be6 },
    .{ .first = 0x1be8, .last = 0x1be9 },
    .{ .first = 0x1bed, .last = 0x1bed },
    .{ .first = 0x1bef, .last = 0x1bf1 },
    .{ .first = 0x1c2c, .last = 0x1c33 },
    .{ .first = 0x1c36, .last = 0x1c37 },
    .{ .first = 0x1cd0, .last = 0x1cd2 },
    .{ .first = 0x1cd4, .last = 0x1ce0 },
    .{ .first = 0x1ce2, .last = 0x1ce8 },
    .{ .first = 0x1ced, .last = 0x1ced },
    .{ .first = 0x1cf4, .last = 0x1cf4 },
    .{ .first = 0x1cf8, .last = 0x1cf9 },
    .{ .first = 0x1dc0, .last = 0x1dff },
    .{ .first = 0x200b, .last = 0x200f },
    .{ .first = 0x202a, .last = 0x202e },
    .{ .first = 0x2060, .last = 0x2064 },
    .{ .first = 0x2066, .last = 0x206f },
    .{ .first = 0x20d0, .last = 0x20f0 },
    .{ .first = 0x2cef, .last = 0x2cf1 },
    .{ .first = 0x2d7f, .last = 0x2d7f },
    .{ .first = 0x2de0, .last = 0x2dff },
    .{ .first = 0x302a, .last = 0x302d },
    .{ .first = 0x3099, .last = 0x309a },
    .{ .first = 0xa66f, .last = 0xa672 },
    .{ .first = 0xa674, .last = 0xa67d },
    .{ .first = 0xa69e, .last = 0xa69f },
    .{ .first = 0xa6f0, .last = 0xa6f1 },
    .{ .first = 0xa802, .last = 0xa802 },
    .{ .first = 0xa806, .last = 0xa806 },
    .{ .first = 0xa80b, .last = 0xa80b },
    .{ .first = 0xa825, .last = 0xa826 },
    .{ .first = 0xa8c4, .last = 0xa8c5 },
    .{ .first = 0xa8e0, .last = 0xa8f1 },
    .{ .first = 0xa926, .last = 0xa92d },
    .{ .first = 0xa947, .last = 0xa951 },
    .{ .first = 0xa980, .last = 0xa982 },
    .{ .first = 0xa9b3, .last = 0xa9b3 },
    .{ .first = 0xa9b6, .last = 0xa9b9 },
    .{ .first = 0xa9bc, .last = 0xa9bd },
    .{ .first = 0xa9e5, .last = 0xa9e5 },
    .{ .first = 0xaa29, .last = 0xaa2e },
    .{ .first = 0xaa31, .last = 0xaa32 },
    .{ .first = 0xaa35, .last = 0xaa36 },
    .{ .first = 0xaa43, .last = 0xaa43 },
    .{ .first = 0xaa4c, .last = 0xaa4c },
    .{ .first = 0xaa7c, .last = 0xaa7c },
    .{ .first = 0xaab0, .last = 0xaab0 },
    .{ .first = 0xaab2, .last = 0xaab4 },
    .{ .first = 0xaab7, .last = 0xaab8 },
    .{ .first = 0xaabe, .last = 0xaabf },
    .{ .first = 0xaac1, .last = 0xaac1 },
    .{ .first = 0xaaec, .last = 0xaaed },
    .{ .first = 0xaaf6, .last = 0xaaf6 },
    .{ .first = 0xabe5, .last = 0xabe5 },
    .{ .first = 0xabe8, .last = 0xabe8 },
    .{ .first = 0xabed, .last = 0xabed },
    .{ .first = 0xfb1e, .last = 0xfb1e },
    .{ .first = 0xfe00, .last = 0xfe0f },
    .{ .first = 0xfe20, .last = 0xfe2f },
    .{ .first = 0xfeff, .last = 0xfeff },
    .{ .first = 0x101fd, .last = 0x101fd },
    .{ .first = 0x102e0, .last = 0x102e0 },
    .{ .first = 0x10376, .last = 0x1037a },
    .{ .first = 0x10a01, .last = 0x10a03 },
    .{ .first = 0x10a05, .last = 0x10a06 },
    .{ .first = 0x10a0c, .last = 0x10a0f },
    .{ .first = 0x10a38, .last = 0x10a3a },
    .{ .first = 0x10a3f, .last = 0x10a3f },
    .{ .first = 0x10ae5, .last = 0x10ae6 },
    .{ .first = 0x10d24, .last = 0x10d27 },
    .{ .first = 0x10eab, .last = 0x10eac },
    .{ .first = 0x10f46, .last = 0x10f50 },
    .{ .first = 0x11001, .last = 0x11001 },
    .{ .first = 0x11038, .last = 0x11046 },
    .{ .first = 0x1107f, .last = 0x11081 },
    .{ .first = 0x110b3, .last = 0x110b6 },
    .{ .first = 0x110b9, .last = 0x110ba },
    .{ .first = 0x11100, .last = 0x11102 },
    .{ .first = 0x11127, .last = 0x1112b },
    .{ .first = 0x1112d, .last = 0x11134 },
    .{ .first = 0x11173, .last = 0x11173 },
    .{ .first = 0x11180, .last = 0x11181 },
    .{ .first = 0x111b6, .last = 0x111be },
    .{ .first = 0x111c9, .last = 0x111cc },
    .{ .first = 0x1122f, .last = 0x11231 },
    .{ .first = 0x11234, .last = 0x11234 },
    .{ .first = 0x11236, .last = 0x11237 },
    .{ .first = 0x1123e, .last = 0x1123e },
    .{ .first = 0x112df, .last = 0x112df },
    .{ .first = 0x112e3, .last = 0x112ea },
    .{ .first = 0x11300, .last = 0x11301 },
    .{ .first = 0x1133b, .last = 0x1133c },
    .{ .first = 0x11340, .last = 0x11340 },
    .{ .first = 0x11366, .last = 0x1136c },
    .{ .first = 0x11370, .last = 0x11374 },
    .{ .first = 0x11438, .last = 0x1143f },
    .{ .first = 0x11442, .last = 0x11444 },
    .{ .first = 0x11446, .last = 0x11446 },
    .{ .first = 0x1145e, .last = 0x1145e },
    .{ .first = 0x114b3, .last = 0x114b8 },
    .{ .first = 0x114ba, .last = 0x114ba },
    .{ .first = 0x114bf, .last = 0x114c0 },
    .{ .first = 0x114c2, .last = 0x114c3 },
    .{ .first = 0x115b2, .last = 0x115b5 },
    .{ .first = 0x115bc, .last = 0x115bd },
    .{ .first = 0x115bf, .last = 0x115c0 },
    .{ .first = 0x115dc, .last = 0x115dd },
    .{ .first = 0x11633, .last = 0x1163a },
    .{ .first = 0x1163d, .last = 0x1163d },
    .{ .first = 0x1163f, .last = 0x11640 },
    .{ .first = 0x116ab, .last = 0x116ab },
    .{ .first = 0x116ad, .last = 0x116ad },
    .{ .first = 0x116b0, .last = 0x116b5 },
    .{ .first = 0x116b7, .last = 0x116b7 },
    .{ .first = 0x1171d, .last = 0x1171f },
    .{ .first = 0x11722, .last = 0x11725 },
    .{ .first = 0x11727, .last = 0x1172b },
    .{ .first = 0x1182f, .last = 0x11837 },
    .{ .first = 0x11839, .last = 0x1183a },
    .{ .first = 0x1193b, .last = 0x1193c },
    .{ .first = 0x1193e, .last = 0x1193e },
    .{ .first = 0x11943, .last = 0x11943 },
    .{ .first = 0x119d4, .last = 0x119d7 },
    .{ .first = 0x119da, .last = 0x119db },
    .{ .first = 0x119e0, .last = 0x119e0 },
    .{ .first = 0x11a01, .last = 0x11a0a },
    .{ .first = 0x11a33, .last = 0x11a38 },
    .{ .first = 0x11a3b, .last = 0x11a3e },
    .{ .first = 0x11a47, .last = 0x11a47 },
    .{ .first = 0x11a51, .last = 0x11a56 },
    .{ .first = 0x11a59, .last = 0x11a5b },
    .{ .first = 0x11a8a, .last = 0x11a96 },
    .{ .first = 0x11a98, .last = 0x11a99 },
    .{ .first = 0x11c30, .last = 0x11c36 },
    .{ .first = 0x11c38, .last = 0x11c3d },
    .{ .first = 0x11c3f, .last = 0x11c3f },
    .{ .first = 0x11c92, .last = 0x11ca7 },
    .{ .first = 0x11caa, .last = 0x11cb0 },
    .{ .first = 0x11cb2, .last = 0x11cb3 },
    .{ .first = 0x11cb5, .last = 0x11cb6 },
    .{ .first = 0x11d31, .last = 0x11d36 },
    .{ .first = 0x11d3a, .last = 0x11d3a },
    .{ .first = 0x11d3c, .last = 0x11d3d },
    .{ .first = 0x11d3f, .last = 0x11d45 },
    .{ .first = 0x11d47, .last = 0x11d47 },
    .{ .first = 0x11d90, .last = 0x11d91 },
    .{ .first = 0x11d95, .last = 0x11d95 },
    .{ .first = 0x11d97, .last = 0x11d97 },
    .{ .first = 0x11ef3, .last = 0x11ef4 },
    .{ .first = 0x16af0, .last = 0x16af4 },
    .{ .first = 0x16b30, .last = 0x16b36 },
    .{ .first = 0x16f4f, .last = 0x16f4f },
    .{ .first = 0x16f8f, .last = 0x16f92 },
    .{ .first = 0x16fe4, .last = 0x16fe4 },
    .{ .first = 0x1bc9d, .last = 0x1bc9e },
    .{ .first = 0x1d167, .last = 0x1d169 },
    .{ .first = 0x1d17b, .last = 0x1d182 },
    .{ .first = 0x1d185, .last = 0x1d18b },
    .{ .first = 0x1d1aa, .last = 0x1d1ad },
    .{ .first = 0x1d242, .last = 0x1d244 },
    .{ .first = 0x1da00, .last = 0x1da36 },
    .{ .first = 0x1da3b, .last = 0x1da6c },
    .{ .first = 0x1da75, .last = 0x1da75 },
    .{ .first = 0x1da84, .last = 0x1da84 },
    .{ .first = 0x1da9b, .last = 0x1da9f },
    .{ .first = 0x1daa1, .last = 0x1daaf },
    .{ .first = 0x1e000, .last = 0x1e006 },
    .{ .first = 0x1e008, .last = 0x1e018 },
    .{ .first = 0x1e01b, .last = 0x1e021 },
    .{ .first = 0x1e023, .last = 0x1e024 },
    .{ .first = 0x1e026, .last = 0x1e02a },
    .{ .first = 0x1e130, .last = 0x1e136 },
    .{ .first = 0x1e2ec, .last = 0x1e2ef },
    .{ .first = 0x1e8d0, .last = 0x1e8d6 },
    .{ .first = 0x1e944, .last = 0x1e94a },
    .{ .first = 0xe0100, .last = 0xe01ef },
};

fn inTable(table: []const Interval, cp: u21) bool {
    for (table) |interval| {
        if (cp < interval.first) return false;
        if (cp <= interval.last) return true;
    }
    return false;
}

pub fn isWide(cp: u21) bool {
    return inTable(&wide, cp);
}

pub fn isZeroWidth(cp: u21) bool {
    return inTable(&zero_width, cp);
}

pub fn codepointWidth(cp: u21) usize {
    if (cp < 0x20 or cp == 0x7f) return 0;
    if (isZeroWidth(cp)) return 0;
    if (isWide(cp)) return 2;
    return 1;
}

pub fn decode(s: []const u8, index: usize) Decoded {
    if (index >= s.len) return .{ .codepoint = 0, .len = 0 };

    const first = s[index];
    if (first < 0x80) return .{ .codepoint = first, .len = 1 };

    const len = std.unicode.utf8ByteSequenceLength(first) catch return .{ .codepoint = 0xfffd, .len = 1 };
    if (index + len > s.len) return .{ .codepoint = 0xfffd, .len = 1 };

    const cp: u21 = switch (len) {
        2 => std.unicode.utf8Decode2(s[index..][0..2].*) catch return .{ .codepoint = 0xfffd, .len = 1 },
        3 => std.unicode.utf8Decode3(s[index..][0..3].*) catch return .{ .codepoint = 0xfffd, .len = 1 },
        4 => std.unicode.utf8Decode4(s[index..][0..4].*) catch return .{ .codepoint = 0xfffd, .len = 1 },
        else => return .{ .codepoint = 0xfffd, .len = 1 },
    };
    return .{ .codepoint = cp, .len = len };
}

pub fn nextBoundary(s: []const u8, index: usize) usize {
    const decoded = decode(s, index);
    if (decoded.len == 0) return s.len;
    return index + decoded.len;
}

pub fn prevBoundary(s: []const u8, index: usize) usize {
    if (index == 0) return 0;
    var i = @min(index, s.len);
    i -= 1;
    while (i > 0 and (s[i] & 0xc0) == 0x80) i -= 1;
    return i;
}

/// Returns the length of an ANSI escape sequence starting at `index`, or 0.
pub fn ansiSequenceLength(s: []const u8, index: usize) usize {
    if (index >= s.len or s[index] != 0x1b) return 0;
    if (index + 1 >= s.len) return 1;

    switch (s[index + 1]) {
        '[' => {
            var i = index + 2;
            while (i < s.len) : (i += 1) {
                const b = s[i];
                if (b >= 0x40 and b <= 0x7e) return i + 1 - index;
            }
            return s.len - index;
        },
        ']' => {
            var i = index + 2;
            while (i < s.len) : (i += 1) {
                if (s[i] == 0x07) return i + 1 - index;
                if (s[i] == 0x1b and i + 1 < s.len and s[i + 1] == '\\') return i + 2 - index;
            }
            return s.len - index;
        },
        else => return 2,
    }
}

pub fn visibleWidth(s: []const u8) usize {
    var width: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        const skip = ansiSequenceLength(s, i);
        if (skip != 0) {
            i += skip;
            continue;
        }
        const decoded = decode(s, i);
        if (decoded.len == 0) break;
        if (decoded.codepoint == '\t') {
            width += 8 - (width % 8);
        } else {
            width += codepointWidth(decoded.codepoint);
        }
        i += decoded.len;
    }
    return width;
}

/// Width of `s` starting at byte `start` and stopping before byte `end`.
pub fn visibleWidthSlice(s: []const u8, start: usize, end: usize) usize {
    return visibleWidth(s[@min(start, s.len)..@min(end, s.len)]);
}

/// Returns the byte offset in `s` that is `columns` display cells after
/// `start`, clamped to `end`. Zero-width characters stay with the preceding
/// position.
pub fn byteAtColumn(s: []const u8, start: usize, end: usize, columns: usize) usize {
    var i = start;
    var width: usize = 0;
    while (i < end) {
        const decoded = decode(s, i);
        if (decoded.len == 0) break;
        const cp_width = codepointWidth(decoded.codepoint);
        if (width + cp_width > columns) break;
        width += cp_width;
        i += decoded.len;
    }
    return i;
}

/// Truncate `s` to at most `columns` display cells, appending `ellipsis` when
/// content was removed. ANSI escape sequences are copied through unchanged.
fn expandTabs(s: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var column: usize = 0;
    var index: usize = 0;
    while (index < s.len) {
        if (s[index] == '\n') {
            try out.append(allocator, '\n');
            column = 0;
            index += 1;
            continue;
        }
        const skip = ansiSequenceLength(s, index);
        if (skip != 0) {
            try out.appendSlice(allocator, s[index .. index + skip]);
            index += skip;
            continue;
        }
        const decoded = decode(s, index);
        if (decoded.len == 0) break;
        if (decoded.codepoint == '\t') {
            const advance = 8 - (column % 8);
            try out.appendNTimes(allocator, ' ', advance);
            column += advance;
        } else {
            try out.appendSlice(allocator, s[index .. index + decoded.len]);
            column += codepointWidth(decoded.codepoint);
        }
        index += decoded.len;
    }
    return out.toOwnedSlice(allocator);
}

pub fn truncate(
    s: []const u8,
    columns: usize,
    ellipsis: []const u8,
    allocator: std.mem.Allocator,
) ![]u8 {
    if (std.mem.indexOfScalar(u8, s, '\t') != null) {
        const expanded = try expandTabs(s, allocator);
        defer allocator.free(expanded);
        return truncate(expanded, columns, ellipsis, allocator);
    }
    if (visibleWidth(s) <= columns) return allocator.dupe(u8, s);

    const ellipsis_width = visibleWidth(ellipsis);
    const add_ellipsis = ellipsis_width != 0 and ellipsis_width < columns;
    const budget = if (add_ellipsis) columns - ellipsis_width else columns;

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    var used: usize = 0;
    var had_ansi = false;
    while (i < s.len) {
        const skip = ansiSequenceLength(s, i);
        if (skip != 0) {
            had_ansi = true;
            try out.appendSlice(allocator, s[i .. i + skip]);
            i += skip;
            continue;
        }
        const decoded = decode(s, i);
        if (decoded.len == 0) break;
        const cp_width = codepointWidth(decoded.codepoint);
        if (used + cp_width > budget) break;
        try out.appendSlice(allocator, s[i .. i + decoded.len]);
        used += cp_width;
        i += decoded.len;
    }

    if (add_ellipsis) try out.appendSlice(allocator, ellipsis);
    if (had_ansi) try out.appendSlice(allocator, "\x1b[0m");
    return out.toOwnedSlice(allocator);
}

/// Wrap `s` at `columns` display cells. Existing newlines are preserved, tabs
/// are expanded to eight-column stops and ANSI sequences are copied through.
pub fn wrap(s: []const u8, columns: usize, allocator: std.mem.Allocator) ![]u8 {
    const limit = @max(@as(usize, 1), columns);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var line_width: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\n') {
            try out.append(allocator, '\n');
            line_width = 0;
            i += 1;
            continue;
        }
        if (s[i] == '\r') {
            i += 1;
            continue;
        }
        const skip = ansiSequenceLength(s, i);
        if (skip != 0) {
            try out.appendSlice(allocator, s[i .. i + skip]);
            i += skip;
            continue;
        }
        const decoded = decode(s, i);
        if (decoded.len == 0) break;
        if (decoded.codepoint == '\t') {
            const advance = 8 - (line_width % 8);
            if (line_width != 0 and line_width + advance > limit) {
                try out.append(allocator, '\n');
                line_width = 0;
            }
            try out.appendNTimes(allocator, ' ', advance);
            line_width += advance;
            i += decoded.len;
            continue;
        }
        const cp_width = codepointWidth(decoded.codepoint);
        if (line_width != 0 and line_width + cp_width > limit) {
            try out.append(allocator, '\n');
            line_width = 0;
        }
        try out.appendSlice(allocator, s[i .. i + decoded.len]);
        line_width += cp_width;
        i += decoded.len;
    }
    return out.toOwnedSlice(allocator);
}

pub fn displayRows(s: []const u8, width: usize) usize {
    if (width == 0) return 1;
    var rows: usize = 1;
    var column: usize = 0;
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\n') {
            rows += 1;
            column = 0;
            i += 1;
            continue;
        }
        const skip = ansiSequenceLength(s, i);
        if (skip != 0) {
            i += skip;
            continue;
        }
        const decoded = decode(s, i);
        if (decoded.len == 0) break;
        if (decoded.codepoint == '\t') {
            const advance = 8 - (column % 8);
            if (column + advance > width and column != 0) {
                rows += 1;
                column = 0;
            }
            column += advance;
            i += decoded.len;
            continue;
        }
        const cp_width = codepointWidth(decoded.codepoint);
        if (column + cp_width > width and column != 0) {
            rows += 1;
            column = 0;
        }
        column += cp_width;
        i += decoded.len;
    }
    return rows;
}

test "ascii and ansi width" {
    try std.testing.expectEqual(@as(usize, 3), visibleWidth("abc"));
    try std.testing.expectEqual(@as(usize, 3), visibleWidth("\x1b[31mabc\x1b[0m"));
    try std.testing.expectEqual(@as(usize, 0), visibleWidth("\x1b[38;5;12m"));
}

test "tabs advance to eight column stops" {
    try std.testing.expectEqual(@as(usize, 9), visibleWidth("a\tb"));
    try std.testing.expectEqual(@as(usize, 8), visibleWidth("\t"));
}

test "wide and combining characters" {
    try std.testing.expectEqual(@as(usize, 2), visibleWidth("界"));
    try std.testing.expectEqual(@as(usize, 0), visibleWidth("\u{0301}"));
    try std.testing.expectEqual(@as(usize, 1), visibleWidth("e\u{0301}"));
    try std.testing.expectEqual(@as(usize, 2), visibleWidth("😀"));
}

test "utf8 boundaries" {
    const s = "a界b";
    try std.testing.expectEqual(@as(usize, 1), nextBoundary(s, 0));
    try std.testing.expectEqual(@as(usize, 4), nextBoundary(s, 1));
    try std.testing.expectEqual(@as(usize, 1), prevBoundary(s, 4));
}

test "byte at column" {
    const s = "a界b";
    try std.testing.expectEqual(@as(usize, 1), byteAtColumn(s, 0, s.len, 1));
    try std.testing.expectEqual(@as(usize, 4), byteAtColumn(s, 0, s.len, 3));
}

test "display rows" {
    try std.testing.expectEqual(@as(usize, 1), displayRows("abc", 10));
    try std.testing.expectEqual(@as(usize, 2), displayRows("abcdef", 3));
    try std.testing.expectEqual(@as(usize, 2), displayRows("a\nb", 10));
    try std.testing.expectEqual(@as(usize, 2), displayRows("\tabcdefgh", 8));
}

test "width tables are sorted" {
    for ([_][]const Interval{ &wide, &zero_width }) |table| {
        var previous: u21 = 0;
        for (table, 0..) |interval, index| {
            if (index > 0) try std.testing.expect(interval.first > previous);
            try std.testing.expect(interval.last >= interval.first);
            previous = interval.last;
        }
    }
}

test "truncate respects display columns and ellipsis" {
    const allocator = std.testing.allocator;

    const ascii = try truncate("abcdef", 4, "...", allocator);
    defer allocator.free(ascii);
    try std.testing.expectEqualStrings("a...", ascii);

    const wide_text = try truncate("a界bc", 3, "…", allocator);
    defer allocator.free(wide_text);
    try std.testing.expectEqualStrings("a…", wide_text);

    const ansi = try truncate("\x1b[31mabcdef\x1b[0m", 5, "...", allocator);
    defer allocator.free(ansi);
    try std.testing.expectEqualStrings("\x1b[31mab...\x1b[0m", ansi);
}

test "wrap breaks on display columns" {
    const allocator = std.testing.allocator;

    const ascii = try wrap("abcdef", 3, allocator);
    defer allocator.free(ascii);
    try std.testing.expectEqualStrings("abc\ndef", ascii);

    const words = try wrap("ab cd", 3, allocator);
    defer allocator.free(words);
    try std.testing.expectEqualStrings("ab \ncd", words);

    const wide_text = try wrap("a界b", 3, allocator);
    defer allocator.free(wide_text);
    try std.testing.expectEqualStrings("a界\nb", wide_text);
}
