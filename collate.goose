// The root collation of UTS #10.
//
// The order is the CLDR root collation. The variable weighting is
// non-ignorable: a variable character keeps its primary weight. The
// case order is lower case first, through the tertiary level. The options
// of collate_opts change the strength, the variable weighting, the digits
// and the case order. A code point with no table row takes the implicit
// weights of UTS #10. The table holds contractions of up to three code
// points, and the longest match wins.
namespace unicode;

import std;

// The smaller of two values.
fn coll_min(a: i64, b: i64) -> i64 {
    if a < b { return a; }
    return b;
}

// The unit of one code point: the index of its single row. -1 when no
// single row holds the code point.
fn coll_single_unit(cp: i64) -> i64 {
    return find_exact(COLL_CP[..], cp);
}

// The unit of the contraction record of group g with the tail code
// points t1 and t2. t2 below 0 asks for a tail of one code point. -1
// when no record holds the tail.
fn coll_find_rec(g: i64, t1: i64, t2: i64) -> i64 {
    var k: i64 = COLL_FOFF[g];
    let stop = COLL_FOFF[g + 1];
    while k < stop {
        let tail = COLL_REC[k];
        if tail == 1 {
            if t2 < 0 && COLL_REC[k + 1] == t1 { return COLL_REC[k + 2]; }
        } else {
            if t2 >= 0 && COLL_REC[k + 1] == t1 && COLL_REC[k + 2] == t2 {
                return COLL_REC[k + 3];
            }
        }
        k += tail + 2;
    }
    return -1;
}

// True when the group g holds a contraction of three code points whose
// second tail code point is t1.
fn coll_has_deep(g: i64, t1: i64) -> bool {
    var k: i64 = COLL_FOFF[g];
    let stop = COLL_FOFF[g + 1];
    while k < stop {
        let tail = COLL_REC[k];
        if tail == 2 && COLL_REC[k + 1] == t1 { return true; }
        k += tail + 2;
    }
    return false;
}

// True when the last code point of at least one tail of the group g is
// a mark. Only such a group can match across a skipped mark.
fn coll_trailing_mark(g: i64) -> bool {
    var k: i64 = COLL_FOFF[g];
    let stop = COLL_FOFF[g + 1];
    while k < stop {
        let tail = COLL_REC[k];
        if combining_class(COLL_REC[k + tail]) != 0 { return true; }
        k += tail + 2;
    }
    return false;
}

// The state of a walk: the options that act inside it, and the flag
// that the last element dropped out.
struct CollState {
    alternate: i64,   // the alternate handling: 0 non-ignorable, 1 shifted
    dropped: i64,     // 1 when the last element dropped out
    case_first: i64,  // the case order: 0 off, 1 lower first, 2 upper first
    numeric: i64,     // 1 when a run of digits is one number
    strength: i64,    // the strength: the levels that the key holds
}

// The lowest primary weight of the digit zero in the table.
const COLL_DIGIT_BASE: i64 = 0x2278;
// The lowest primary weight of a number. The numbers take the ten
// weights below the digits of the table.
const COLL_NUM_BASE: i64 = 0x2268;
// The highest primary weight of a variable element. The weights 0x0201
// to 0x04E4 hold the spaces, the punctuation and the symbols that the
// table marks as variable.
const COLL_VAR_LAST: i64 = 0x04E4;

// A primary weight as the walk stores it. The numeric order gives the
// numbers the ten weights below the digits, so every weight below the
// digits moves down by 16 and sorts before the numbers. The weights of
// the table above the digits keep their value, so every weight of the
// key stays below 0x10000.
fn coll_primary(st: CollState&, p: i64) -> i64 {
    if st.numeric == 1 && p < COLL_DIGIT_BASE { return p - 16; }
    return p;
}

// The upper case tertiary weights of the table. Each weight sets one
// bit. The table holds no tertiary weight above 30.
const COLL_UPPER_MASK: i64 = (1 << 8) | (1 << 9) | (1 << 10) | (1 << 11)
    | (1 << 12) | (1 << 14) | (1 << 17) | (1 << 18) | (1 << 29);

// A tertiary weight as the walk stores it. The case order puts a case
// bit above the weight. The nine upper case weights of the table decide
// the class of an element. The bit sits at the weight 0x20, above every
// tertiary weight of the table, so the value stays below 0x10000.
fn coll_tertiary(st: CollState&, t: i64) -> i64 {
    if st.case_first == 0 { return t; }
    let upper = (COLL_UPPER_MASK >> t) & 1 == 1;
    var bit: i64 = 0;
    if st.case_first == 1 && upper { bit = 1; }
    if st.case_first == 2 && !upper { bit = 1; }
    return (bit << 5) | t;
}

// Appends the elements of one unit to the three level buffers. A
// primary of 0000 stays out of the first level. The shifted handling
// drops a variable element, and the elements without a primary weight
// that follow it. The caller checks the total bound.
fn coll_unit_levels(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, unit: i64) {
    let start = COLL_EOFF[unit];
    let stop = COLL_EOFF[unit + 1];
    for e in start..stop {
        let p = COLL_P[e];
        if st.alternate == 1 {
            if (p > 0x0200 && p <= COLL_VAR_LAST) || (p == 0 && st.dropped == 1) {
                st.dropped = 1;
                continue;
            }
            st.dropped = 0;
        }
        // A weight of 0000 stays out of its level: an element with
        // nothing at a level holds that level back. A level above the
        // strength holds no weight, because the key keeps no level.
        if p != 0 { l1.push(coll_primary(st, p)); }
        if st.strength >= STRENGTH_SECONDARY && COLL_S[e] != 0 { l2.push(COLL_S[e]); }
        if st.strength >= STRENGTH_TERTIARY && COLL_T[e] != 0 {
            l3.push(coll_tertiary(st, COLL_T[e]));
        }
    }
}

// The weights of a code point with no row: the implicit weights of
// UTS #10. The Hangul syllables decompose into their jamos. The
// siniform scripts take the base of their block. The core Han takes
// the base of the plane of its block, the other Han the base of the
// plane of the unified ideographs, and the rest the base of the
// unassigned code points. Each group appends the base with the common
// secondary and tertiary weights, then the tail as a second primary.
fn coll_implicit(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, cp: i64) {
    if cp >= 0xAC00 && cp <= 0xD7A3 {
        let s = cp - 0xAC00;
        coll_jamo(l1, l2, l3, st, 0x1100 + s / 588);
        coll_jamo(l1, l2, l3, st, 0x1161 + (s % 588) / 28);
        let t = s % 28;
        if t > 0 { coll_jamo(l1, l2, l3, st, 0x11A7 + t); }
        return;
    }
    var aaaa: i64 = 0xFBC0 + (cp >> 15);
    var bbbb: i64 = (cp & 0x7FFF) | 0x8000;
    let si = run_at(COLL_SINI_S[..], COLL_SINI_E[..], cp);
    if si >= 0 {
        aaaa = COLL_SINI_A[si];
        bbbb = ((cp - COLL_SINI_B[si]) & 0x7FFF) | 0x8000;
    } else if run_at(COLL_HAN_S[..], COLL_HAN_E[..], cp) >= 0 {
        aaaa = 0xFB40 + (cp >> 15);
    } else if run_at(COLL_HANO_S[..], COLL_HANO_E[..], cp) >= 0 {
        aaaa = 0xFB80 + (cp >> 15);
    }
    st.dropped = 0;
    l1.push(coll_primary(st, aaaa));
    if st.strength >= STRENGTH_SECONDARY { l2.push(0x0020); }
    if st.strength >= STRENGTH_TERTIARY { l3.push(coll_tertiary(st, 0x0002)); }
    l1.push(coll_primary(st, bbbb));
}

// Appends the elements of one Hangul jamo. Every jamo holds a row.
fn coll_jamo(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, jamo: i64) {
    let unit = coll_single_unit(jamo);
    if unit >= 0 {
        coll_unit_levels(l1, l2, l3, st, unit);
    }
}

// Appends the weights of one plain code point: its row, or the
// implicit weights. A skipped mark takes this path.
fn coll_single(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, cp: i64) {
    let single = coll_single_unit(cp);
    if single >= 0 {
        coll_unit_levels(l1, l2, l3, st, single);
    } else {
        coll_implicit(l1, l2, l3, st, cp);
    }
}

// The cap on the marks a discontiguous scan may skip. A longer run of
// marks ends the scan and the marks take their own weights.
const COLL_MAX_SKIP: i64 = 32;

// Appends the weights of the unit at cps[i] and gives the number of
// code points the unit covers. A contraction of the table takes its
// whole sequence, and the longest match wins. A mark that stands
// between a matched contraction and its next code point stays out of
// the match when a smaller combining class would order it first, and
// its own weights follow the weights of the contraction. The scan
// across marks stops at a starter, at the mark cap, and when the
// combining class of the last skipped mark is not smaller than the
// class of the next mark.
fn coll_step(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, cps: const i64[:], i: i64) -> i64 {
    let cp = cps[i];
    let n = cps.len;
    let g = find_exact(COLL_FIRST[..], cp);
    if g < 0 {
        coll_single(l1, l2, l3, st, cp);
        return 1;
    }
    var c2: i64 = -1;
    var c3: i64 = -1;
    if i + 1 < n { c2 = cps[i + 1]; }
    if c2 >= 0 && i + 2 < n { c3 = cps[i + 2]; }
    // The longest contiguous match first: the full tail of three code
    // points, then the tail of two.
    var u2: i64 = -1;
    if c3 >= 0 { u2 = coll_find_rec(g, c2, c3); }
    if u2 >= 0 {
        coll_unit_levels(l1, l2, l3, st, u2);
        return 3;
    }
    var u1: i64 = -1;
    if c2 >= 0 { u1 = coll_find_rec(g, c2, -1); }
    if u1 >= 0 && !coll_has_deep(g, c2) {
        coll_unit_levels(l1, l2, l3, st, u1);
        return 2;
    }
    // The discontiguous match: the mark that failed to extend the
    // match is the first skipped mark, and the scan looks for a code
    // point that completes the contraction. The state is 0 when no
    // tail code point matched yet, and 1 when c2 matched as the tail
    // of a contraction of two code points.
    var ms: i64 = 0;
    var m0: i64 = -1;
    if u1 >= 0 {
        if c3 < 0 || combining_class(c3) == 0 || !coll_trailing_mark(g) {
            coll_unit_levels(l1, l2, l3, st, u1);
            return 2;
        }
        ms = 1;
        m0 = i + 2;
    } else if c2 >= 0 {
        if combining_class(c2) == 0 || !coll_trailing_mark(g) {
            coll_single(l1, l2, l3, st, cp);
            return 1;
        }
        m0 = i + 1;
    } else {
        coll_single(l1, l2, l3, st, cp);
        return 1;
    }
    var prev = combining_class(cps[m0]);
    var p: i64 = m0 + 1;
    var skipped: i64 = 0;
    // The last match so far: its position, its unit and its tail code
    // point. A match whose group holds a longer tail stays open, and
    // the scan looks for the code point that completes it.
    var mp: i64 = -1;
    var mu: i64 = -1;
    var mt: i64 = -1;
    while p < n {
        let c = cps[p];
        let cc = combining_class(c);
        if cc == 0 || skipped >= COLL_MAX_SKIP { break; }
        if prev < cc {
            var u: i64 = -1;
            if ms == 2 {
                u = coll_find_rec(g, mt, c);
            } else if ms == 1 {
                u = coll_find_rec(g, c2, c);
            } else {
                u = coll_find_rec(g, c, -1);
            }
            if u >= 0 {
                if ms == 0 && coll_has_deep(g, c) {
                    mp = p;
                    mu = u;
                    mt = c;
                    ms = 2;
                    p += 1;
                    skipped = 0;
                    continue;
                }
                coll_unit_levels(l1, l2, l3, st, u);
                for k in m0..p {
                    if k != mp { coll_single(l1, l2, l3, st, cps[k]); }
                }
                return p + 1 - i;
            }
        }
        prev = cc;
        p += 1;
        skipped += 1;
    }
    if ms == 1 {
        coll_unit_levels(l1, l2, l3, st, u1);
        return 2;
    }
    if mp >= 0 {
        coll_unit_levels(l1, l2, l3, st, mu);
        for k in m0..mp {
            coll_single(l1, l2, l3, st, cps[k]);
        }
        return mp + 1 - i;
    }
    coll_single(l1, l2, l3, st, cp);
    return 1;
}

// The sign of the new region of two level buffers from the mark. 0
// while the region stays equal, and the sign of the first difference
// otherwise.
fn coll_region_sign(a: const i64[:], b: const i64[:], mark: i64) -> i64 {
    let stop = coll_min(a.len, b.len);
    var k: i64 = mark;
    while k < stop {
        if a[k] != b[k] {
            if a[k] < b[k] { return -1; }
            return 1;
        }
        k += 1;
    }
    return 0;
}

// The sign of the order of two level buffers: the first difference
// decides, and a shorter buffer that is a prefix of the other orders
// first. 0 when both hold the same weights.
fn coll_level_sign(a: const i64[:], b: const i64[:]) -> i64 {
    let stop = coll_min(a.len, b.len);
    for k in 0..stop {
        if a[k] != b[k] {
            if a[k] < b[k] { return -1; }
            return 1;
        }
    }
    if a.len < b.len { return -1; }
    if a.len > b.len { return 1; }
    return 0;
}

// Gives the sort key of s in out: the primary weights, then the
// secondary weights, then the tertiary weights, as their 16-bit
// values. Every option keeps the weights below 0x10000, except the
// code points that the identical strength adds. Each level ends with the byte 1 and the key ends with the
// byte 0. A text with no weight at any level gives the empty key. The
// sign of the comparison of two keys equals the sign of compare of the
// two texts. A bad byte gives ERR_BAD_UTF8 and the offset of the first
// bad byte. A text above MAX_INPUT or a key above MAX_OUTPUT gives
// ERR_TOO_LONG. Either fault leaves out empty.
fn sort_key(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    return sort_key_with(out, s, coll_options());
}

// Gives the sign of the root collation order of a and b in out: -1, 0
// or 1. The call decodes both texts, decomposes each to the canonical
// form, and walks both at once. It stops on the first difference of
// the highest level that decides. A bad byte in a gives ERR_BAD_UTF8
// and the offset in a. A bad byte in b, with a well formed a, gives
// ERR_BAD_UTF8 and the offset in b. A text above MAX_INPUT gives
// ERR_TOO_LONG. Either fault leaves out empty.
fn compare(out: i64[>..]&, a: const u8[:], b: const u8[:]) -> i64, i64 {
    return compare_with(out, a, b, coll_options());
}
