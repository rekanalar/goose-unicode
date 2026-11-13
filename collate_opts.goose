// The options of the collation.
//
// A CollOptions value sets the strength, the alternate handling, the
// numeric order and the case order. The default value gives the root
// order of compare and sort_key. The options act inside the walk over
// the collation elements: the shifted handling drops an element, and
// the case order changes the tertiary weight of one element. The values
// follow the attributes of ICU.
namespace unicode;

import std;

// The strength: the levels that decide the order.
const STRENGTH_PRIMARY: i64 = 0;
const STRENGTH_SECONDARY: i64 = 1;
const STRENGTH_TERTIARY: i64 = 2;
const STRENGTH_IDENTICAL: i64 = 15;

// The alternate handling of the variable characters.
const ALT_NON_IGNORABLE: i64 = 0;
const ALT_SHIFTED: i64 = 1;

// The case order.
const CASE_OFF: i64 = 0;
const CASE_LOWER_FIRST: i64 = 1;
const CASE_UPPER_FIRST: i64 = 2;

// The options of a collation call. A field outside its range gives
// ERR_BAD_ARG.
struct CollOptions {
    strength: i64,
    alternate: i64,
    numeric: i64,
    case_first: i64,
}

// The default options: tertiary strength, non-ignorable variable
// characters, no numeric order and no case order.
fn coll_options() -> CollOptions {
    return CollOptions { STRENGTH_TERTIARY, ALT_NON_IGNORABLE, 0, CASE_OFF };
}

// True when every field of o holds a known value.
fn coll_options_ok(o: CollOptions) -> bool {
    let s = o.strength;
    if s != STRENGTH_PRIMARY && s != STRENGTH_SECONDARY && s != STRENGTH_TERTIARY
        && s != STRENGTH_IDENTICAL {
        return false;
    }
    if o.alternate < ALT_NON_IGNORABLE || o.alternate > ALT_SHIFTED { return false; }
    if o.numeric < 0 || o.numeric > 1 { return false; }
    return o.case_first >= CASE_OFF && o.case_first <= CASE_UPPER_FIRST;
}

// Fills the state of a walk from the options.
fn coll_state(st: CollState&, o: CollOptions) {
    st.alternate = o.alternate;
    st.dropped = 0;
    st.case_first = o.case_first;
    st.numeric = o.numeric;
    st.strength = o.strength;
}

// True when the code point is a digit of the category Nd. The ASCII
// digits give their answer without a lookup in the table.
fn coll_is_digit(cp: i64) -> bool {
    if cp >= 0x30 && cp <= 0x39 { return true; }
    if cp < 0x80 { return false; }
    return category(cp) == CAT_ND;
}

// The value of the digit at cp, for a code point of the category Nd.
// The ASCII digits give their value without a lookup in the table.
fn coll_digit_value(cp: i64) -> i64 {
    if cp >= 0x30 && cp <= 0x39 { return cp - 0x30; }
    let v, _ = numeric_value(cp);
    return v;
}

// The weights of a run of decimal digits that starts at cps[i]. The
// run is one number: the leading zeros do not count. The primary level
// holds the count of the significant digits in seven decimal digits,
// then one weight per digit. A number with fewer digits is the smaller
// one, and the digits decide the rest. The number takes no weight at
// the secondary or the tertiary level, as in ICU. Gives the code points
// of the run.
fn coll_numeric(l1: i64[>..]&, l2: const i64[:], l3: const i64[:], st: CollState&, cps: const i64[:], i: i64) -> i64, bool {
    var j: i64 = i + 1;
    while j < cps.len && coll_is_digit(cps[j]) { j += 1; }
    var k: i64 = i;
    while k < j - 1 && coll_digit_value(cps[k]) == 0 { k += 1; }
    let count = j - k;
    // The run gives seven weights for the count and one weight for each
    // digit. The bound of the key is checked before they are written.
    var n = l1.len + count + 7;
    if st.strength >= STRENGTH_SECONDARY { n += l2.len + 1; }
    if st.strength >= STRENGTH_TERTIARY { n += l3.len + 1; }
    if n > MAX_OUTPUT { return j - i, true; }
    var scale: i64 = 1000000;
    while scale > 0 {
        l1.push(COLL_NUM_BASE + (count / scale) % 10);
        scale = scale / 10;
    }
    for m in k..j { l1.push(COLL_NUM_BASE + coll_digit_value(cps[m])); }
    st.dropped = 0;
    return j - i, false;
}

// One step of the walk: a run of digits when the numeric order is on,
// else the weights of the unit at cps[i]. Gives the code points used.
fn coll_next(l1: i64[>..]&, l2: i64[>..]&, l3: i64[>..]&, st: CollState&, cps: const i64[:], i: i64) -> i64, bool {
    if st.numeric == 1 && coll_is_digit(cps[i]) {
        return coll_numeric(l1, l2[..], l3[..], st, cps, i);
    }
    return coll_step(l1, l2, l3, st, cps, i), false;
}

// Decodes s and decomposes it to the canonical form into cps. The
// caller checks the options and the length of the text first.
fn coll_prepare(cps: i64[>..]&, s: const u8[:]) -> i64, i64 {
    cps.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var raw: i64[>..] = [];
    let code, off = utf8_decode(raw, s);
    if code != OK { return code, off; }
    let nfd = normalize_cps(cps, raw[..], FORM_NFD);
    if nfd != OK { return nfd, -1; }
    return OK, -1;
}

// True when the level buffers of one text hold more weights than the
// bound allows. The key holds the levels up to the strength, so the
// bound counts those levels only. The extra counts the separators that
// the key adds to the weights.
fn coll_over(l1: const i64[:], l2: const i64[:], l3: const i64[:], strength: i64, extra: i64) -> bool {
    var n = l1.len + extra;
    if strength >= STRENGTH_SECONDARY { n += l2.len + 1; }
    if strength >= STRENGTH_TERTIARY { n += l3.len + 1; }
    return n > MAX_OUTPUT;
}

// Gives the sort key of s under the options o. The key holds the levels
// up to the strength, each ending with the byte 1, and ends with the
// byte 0. The identical strength adds the code points of the canonical
// form after the tertiary level. A code point needs more than 16 bits,
// so a caller that packs the key into 16 bits must not use the
// identical strength. A text with no weight at any level gives
// the empty key. The keys of two texts compare as compare_with orders
// the texts under the same options. Faults as in sort_key; a field
// outside its range gives ERR_BAD_ARG. Any fault leaves out empty.
fn sort_key_with(out: i64[>..]&, s: const u8[:], o: CollOptions) -> i64, i64 {
    out.clear();
    if !coll_options_ok(o) { return ERR_BAD_ARG, -1; }
    var cps: i64[>..] = [];
    let code, off = coll_prepare(cps, s);
    if code != OK { return code, off; }
    var st = CollState { 0, 0, 0, 0, 0 };
    coll_state(st, o);
    var l1: i64[>..] = [];
    var l2: i64[>..] = [];
    var l3: i64[>..] = [];
    var i: i64 = 0;
    while i < cps.len {
        let used, over = coll_next(l1, l2, l3, st, cps[..], i);
        i += used;
        if over { return ERR_TOO_LONG, -1; }
        if coll_over(l1[..], l2[..], l3[..], o.strength, 3) { return ERR_TOO_LONG, -1; }
    }
    // A text with no weight at any level gives the empty key. The
    // identical strength gives the key of the code points, so a text
    // with code points gives a key even without a weight.
    if l1.len == 0 && l2.len == 0 && l3.len == 0
        && !(o.strength == STRENGTH_IDENTICAL && cps.len > 0) {
        return OK, -1;
    }
    out.append(l1[..]);
    if o.strength >= STRENGTH_SECONDARY {
        out.push(1);
        out.append(l2[..]);
    }
    if o.strength >= STRENGTH_TERTIARY {
        out.push(1);
        out.append(l3[..]);
    }
    if o.strength == STRENGTH_IDENTICAL {
        // The code points of the text join the key. The bound counts
        // the separator, the code points and the terminator.
        if out.len + cps.len + 2 > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG, -1;
        }
        out.push(1);
        for k in 0..cps.len { out.push(cps[k] + 2); }
    }
    out.push(0);
    return OK, -1;
}

// Gives the sign of the order of a and b under the options o in out: -1,
// 0 or 1. The call walks both texts at once and stops on the first
// difference of the highest level that decides. A level above the
// strength never decides. Faults as in compare; a field outside its range
// gives ERR_BAD_ARG. Any fault leaves out empty.
fn compare_with(out: i64[>..]&, a: const u8[:], b: const u8[:], o: CollOptions) -> i64, i64 {
    out.clear();
    if !coll_options_ok(o) { return ERR_BAD_ARG, -1; }
    if a.len > MAX_INPUT || b.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var ca: i64[>..] = [];
    var cb: i64[>..] = [];
    let code, off = coll_prepare(ca, a);
    if code != OK { return code, off; }
    let code2, off2 = coll_prepare(cb, b);
    if code2 != OK { return code2, off2; }
    var sa = CollState { 0, 0, 0, 0, 0 };
    var sb = CollState { 0, 0, 0, 0, 0 };
    coll_state(sa, o);
    coll_state(sb, o);
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
            let used, over = coll_next(l1, l2, l3, sa, ca[..], i);
            i += used;
            if over { return ERR_TOO_LONG, -1; }
        }
        if j < cb.len {
            let used, over = coll_next(m1, m2, m3, sb, cb[..], j);
            j += used;
            if over { return ERR_TOO_LONG, -1; }
        }
        if coll_over(l1[..], l2[..], l3[..], o.strength, 0)
            || coll_over(m1[..], m2[..], m3[..], o.strength, 0) {
            return ERR_TOO_LONG, -1;
        }
        if s1 == 0 {
            s1 = coll_region_sign(l1[..], m1[..], p1);
            p1 = coll_min(l1.len, m1.len);
            // The primary level decides the order. The walk stops as
            // soon as the primary region differs.
            if s1 != 0 { break; }
        }
        if s2 == 0 && o.strength >= STRENGTH_SECONDARY {
            s2 = coll_region_sign(l2[..], m2[..], p2);
            p2 = coll_min(l2.len, m2.len);
        }
        if s3 == 0 && o.strength >= STRENGTH_TERTIARY {
            s3 = coll_region_sign(l3[..], m3[..], p3);
            p3 = coll_min(l3.len, m3.len);
        }
    }
    var sign: i64 = s1;
    if sign == 0 { sign = coll_level_sign(l1[..], m1[..]); }
    if sign == 0 && o.strength >= STRENGTH_SECONDARY {
        sign = s2;
        if sign == 0 { sign = coll_level_sign(l2[..], m2[..]); }
    }
    if sign == 0 && o.strength >= STRENGTH_TERTIARY {
        sign = s3;
        if sign == 0 { sign = coll_level_sign(l3[..], m3[..]); }
    }
    if sign == 0 && o.strength == STRENGTH_IDENTICAL {
        sign = coll_level_sign(ca[..], cb[..]);
    }
    out.push(sign);
    return OK, -1;
}
