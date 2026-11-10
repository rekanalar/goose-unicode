// The root collation of UTS #10.
//
// The order is the CLDR root collation. The variable weighting is
// non-ignorable: a variable character keeps its primary weight. The
// case order is lower case first, through the tertiary level. A code
// point with no table row takes the implicit weights of UTS #10. The
// table holds contractions of up to three code points, and the
// longest match wins.
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

// Appends the elements of one unit to the three level buffers. A
// primary of 0000 stays out of the first level. The caller checks the
// total bound.
fn coll_unit_levels(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, unit: i64) {
    let start = COLL_EOFF[unit];
    let stop = COLL_EOFF[unit + 1];
    for e in start..stop {
        // A weight of 0000 stays out of its level: an element with
        // nothing at a level holds that level back.
        if COLL_P[e] != 0 { l1.push(COLL_P[e]); }
        if COLL_S[e] != 0 { l2.push(COLL_S[e]); }
        if COLL_T[e] != 0 { l3.push(COLL_T[e]); }
    }
}

// The weights of a code point with no row: the implicit weights of
// UTS #10. The Hangul syllables decompose into their jamos. The
// siniform scripts take the base of their block. The core Han takes
// the base of the plane of its block, the other Han the base of the
// plane of the unified ideographs, and the rest the base of the
// unassigned code points. Each group appends the base with the common
// secondary and tertiary weights, then the tail as a second primary.
fn coll_implicit(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, cp: i64) {
    if cp >= 0xAC00 && cp <= 0xD7A3 {
        let s = cp - 0xAC00;
        coll_jamo(l1, l2, l3, 0x1100 + s / 588);
        coll_jamo(l1, l2, l3, 0x1161 + (s % 588) / 28);
        let t = s % 28;
        if t > 0 { coll_jamo(l1, l2, l3, 0x11A7 + t); }
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
    l1.push(aaaa);
    l2.push(0x0020);
    l3.push(0x0002);
    l1.push(bbbb);
}

// Appends the elements of one Hangul jamo. Every jamo holds a row.
fn coll_jamo(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, jamo: i64) {
    let unit = coll_single_unit(jamo);
    if unit >= 0 {
        coll_unit_levels(l1, l2, l3, unit);
    }
}

// Appends the weights of one plain code point: its row, or the
// implicit weights. A skipped mark takes this path.
fn coll_single(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, cp: i64) {
    let single = coll_single_unit(cp);
    if single >= 0 {
        coll_unit_levels(l1, l2, l3, single);
    } else {
        coll_implicit(l1, l2, l3, cp);
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
fn coll_step(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, cps: const i64[:], i: i64) -> i64 {
    let cp = cps[i];
    let n = cps.len;
    let g = find_exact(COLL_FIRST[..], cp);
    if g < 0 {
        coll_single(l1, l2, l3, cp);
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
        coll_unit_levels(l1, l2, l3, u2);
        return 3;
    }
    var u1: i64 = -1;
    if c2 >= 0 { u1 = coll_find_rec(g, c2, -1); }
    if u1 >= 0 && !coll_has_deep(g, c2) {
        coll_unit_levels(l1, l2, l3, u1);
        return 2;
    }
    // The discontiguous match: the mark that failed to extend the
    // match is the first skipped mark, and the scan looks for a code
    // point that completes the contraction. The state is 0 when no
    // tail code point matched yet, and 1 when c2 matched as the tail
    // of a contraction of two code points.
    var st: i64 = 0;
    var m0: i64 = -1;
    if u1 >= 0 {
        if c3 < 0 || combining_class(c3) == 0 || !coll_trailing_mark(g) {
            coll_unit_levels(l1, l2, l3, u1);
            return 2;
        }
        st = 1;
        m0 = i + 2;
    } else if c2 >= 0 {
        if combining_class(c2) == 0 || !coll_trailing_mark(g) {
            coll_single(l1, l2, l3, cp);
            return 1;
        }
        m0 = i + 1;
    } else {
        coll_single(l1, l2, l3, cp);
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
            if st == 2 {
                u = coll_find_rec(g, mt, c);
            } else if st == 1 {
                u = coll_find_rec(g, c2, c);
            } else {
                u = coll_find_rec(g, c, -1);
            }
            if u >= 0 {
                if st == 0 && coll_has_deep(g, c) {
                    mp = p;
                    mu = u;
                    mt = c;
                    st = 2;
                    p += 1;
                    skipped = 0;
                    continue;
                }
                coll_unit_levels(l1, l2, l3, u);
                for k in m0..p {
                    if k != mp { coll_single(l1, l2, l3, cps[k]); }
                }
                return p + 1 - i;
            }
        }
        prev = cc;
        p += 1;
        skipped += 1;
    }
    if st == 1 {
        coll_unit_levels(l1, l2, l3, u1);
        return 2;
    }
    if mp >= 0 {
        coll_unit_levels(l1, l2, l3, mu);
        for k in m0..mp {
            coll_single(l1, l2, l3, cps[k]);
        }
        return mp + 1 - i;
    }
    coll_single(l1, l2, l3, cp);
    return 1;
}

// Decodes s, decomposes the text to the canonical form of the
// standard and fills the three level buffers. The canonical form puts
// each run of marks in the order that the weights expect. On a fault
// the buffers are empty.
fn coll_levels(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, s: const u8[:]) -> i64, i64 {
    l1.clear();
    l2.clear();
    l3.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var raw: i64[>..] = [];
    var cps: i64[>..] = [];
    let code, off = utf8_decode(raw, s);
    if code != OK { return code, off; }
    let nfd = normalize_cps(cps, raw[..], FORM_NFD);
    if nfd != OK { return nfd, -1; }
    var i: i64 = 0;
    while i < cps.len {
        let n = coll_step(l1, l2, l3, cps[..], i);
        // The three separators of the key count toward the bound.
        if l1.len + l2.len + l3.len + 3 > MAX_OUTPUT {
            l1.clear();
            l2.clear();
            l3.clear();
            return ERR_TOO_LONG, -1;
        }
        i += n;
    }
    return OK, -1;
}

// Assembles the key from the three level buffers. Each weight holds
// its 16-bit value. The byte 1 ends each level and the byte 0 ends the
// key. No weight holds 0 or 1, so the order of the keys equals the
// order of the levels. A text with no code point gives the empty key.
fn coll_assemble(out: i64[>..]&, l1: const i64[:], l2: const i64[:], l3: const i64[:]) {
    for k in 0..l1.len { out.push(l1[k]); }
    out.push(1);
    for k in 0..l2.len { out.push(l2[k]); }
    out.push(1);
    for k in 0..l3.len { out.push(l3[k]); }
    out.push(0);
}

// Gives the sort key of s in out: the primary weights, then the
// secondary weights, then the tertiary weights, as their 16-bit
// values. Each level ends with the byte 1 and the key ends with the
// byte 0. A text with
// no code point gives the empty key. The sign of the comparison of two
// keys equals the sign of compare of the two texts. A bad byte gives
// ERR_BAD_UTF8 and the offset of the first bad byte. A text above
// MAX_INPUT or a key above MAX_OUTPUT gives ERR_TOO_LONG. Either fault
// leaves out empty.
fn sort_key(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    var l1: i64[>..] = [];
    var l2: i64[>..] = [];
    var l3: i64[>..] = [];
    let code, off = coll_levels(l1, l2, l3, s);
    if code != OK { return code, off; }
    if s.len == 0 { return OK, -1; }
    coll_assemble(out, l1[..], l2[..], l3[..]);
    return OK, -1;
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

// Gives the sign of the root collation order of a and b in out: -1, 0
// or 1. The call decodes both texts, decomposes each to the canonical
// form, and walks both at once. It stops on the first difference of
// the highest level that decides. A bad byte in a gives ERR_BAD_UTF8
// and the offset in a. A bad byte in b, with a well formed a, gives
// ERR_BAD_UTF8 and the offset in b. A text above MAX_INPUT gives
// ERR_TOO_LONG. Either fault leaves out empty.
fn compare(out: i64[>..]&, a: const u8[:], b: const u8[:]) -> i64, i64 {
    out.clear();
    if a.len > MAX_INPUT || b.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var ra: i64[>..] = [];
    var rb: i64[>..] = [];
    var ca: i64[>..] = [];
    var cb: i64[>..] = [];
    let code, off = utf8_decode(ra, a);
    if code != OK { return code, off; }
    let na = normalize_cps(ca, ra[..], FORM_NFD);
    if na != OK { return na, -1; }
    let code2, off2 = utf8_decode(rb, b);
    if code2 != OK { return code2, off2; }
    let nb = normalize_cps(cb, rb[..], FORM_NFD);
    if nb != OK { return nb, -1; }
    var l1: i64[>..] = [];
    var l2: i64[>..] = [];
    var l3: i64[>..] = [];
    var m1: i64[>..] = [];
    var m2: i64[>..] = [];
    var m3: i64[>..] = [];
    var s1: i64 = 0;
    var s2: i64 = 0;
    var s3: i64 = 0;
    var p1: i64 = 0;
    var p2: i64 = 0;
    var p3: i64 = 0;
    var i: i64 = 0;
    var j: i64 = 0;
    while i < ca.len || j < cb.len {
        if i < ca.len {
            let n = coll_step(l1, l2, l3, ca[..], i);
            i += n;
        }
        if j < cb.len {
            let n = coll_step(m1, m2, m3, cb[..], j);
            j += n;
        }
        if l1.len + l2.len + l3.len > MAX_OUTPUT
            || m1.len + m2.len + m3.len > MAX_OUTPUT {
            return ERR_TOO_LONG, -1;
        }
        if s1 == 0 {
            s1 = coll_region_sign(l1[..], m1[..], p1);
            p1 = coll_min(l1.len, m1.len);
        }
        if s2 == 0 {
            s2 = coll_region_sign(l2[..], m2[..], p2);
            p2 = coll_min(l2.len, m2.len);
        }
        if s3 == 0 {
            s3 = coll_region_sign(l3[..], m3[..], p3);
            p3 = coll_min(l3.len, m3.len);
        }
        if s1 != 0 { break; }
    }
    var sign: i64 = s1;
    if sign == 0 { sign = coll_level_sign(l1[..], m1[..]); }
    if sign == 0 { sign = s2; }
    if sign == 0 { sign = coll_level_sign(l2[..], m2[..]); }
    if sign == 0 { sign = s3; }
    if sign == 0 { sign = coll_level_sign(l3[..], m3[..]); }
    out.push(sign);
    return OK, -1;
}
