// Tests for the confusable calls.
namespace suite;

import std;
import unicode from "../..";

fn cf_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: confusable ", name, "\n"); return 1; }
    return 0;
}

// Appends the bytes of one text to out.
fn cf_append(out: u8[>..]&, s: const u8[:]) {
    for k in 0..s.len { out.push(s[k]); }
}

// The skeleton of every source of the table, against the skeleton of
// the rule of the standard. Where the table of ICU holds the same
// row, the skeleton must equal the skeleton of ICU too.
fn cf_rows() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var want: u8[>..] = [];
    var icu: u8[>..] = [];
    var src: u8[>..] = [];
    for r in 0..CS_SRC_OFF.len - 1 {
        src.clear();
        want.clear();
        icu.clear();
        unicode::encode_all(src, CS_SRC_POOL[CS_SRC_OFF[r]..CS_SRC_OFF[r + 1]]);
        unicode::encode_all(want, CS_WANT_POOL[CS_WANT_OFF[r]..CS_WANT_OFF[r + 1]]);
        unicode::encode_all(icu, CS_ICU_POOL[CS_ICU_OFF[r]..CS_ICU_OFF[r + 1]]);
        let code, off = unicode::skeleton(out, src[..]);
        if code != unicode::OK || out[..] != want[..] {
            print("FAIL: skeleton of source ", r, " code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if want[..] == icu[..] && out[..] != icu[..] {
            print("FAIL: the skeleton of source ", r, " differs from ICU\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The skeleton of texts of several code points, against the rule of
// the standard and against ICU.
fn cf_strings() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var want: u8[>..] = [];
    var icu: u8[>..] = [];
    var src: u8[>..] = [];
    for r in 0..CS_TXT_OFF.len - 1 {
        src.clear();
        want.clear();
        icu.clear();
        unicode::encode_all(src, CS_TXT_POOL[CS_TXT_OFF[r]..CS_TXT_OFF[r + 1]]);
        unicode::encode_all(want, CS_TXT_WANT_POOL[CS_TXT_WANT_OFF[r]..CS_TXT_WANT_OFF[r + 1]]);
        unicode::encode_all(icu, CS_TXT_ICU_POOL[CS_TXT_ICU_OFF[r]..CS_TXT_ICU_OFF[r + 1]]);
        let code, off = unicode::skeleton(out, src[..]);
        if code != unicode::OK || out[..] != want[..] {
            print("FAIL: skeleton of text ", r, " code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
        if want[..] == icu[..] && out[..] != icu[..] {
            print("FAIL: the skeleton of text ", r, " differs from ICU\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The well known look alike pairs.
fn cf_pairs() -> i64 {
    var bad = 0;
    var cyr: u8[>..] = [];
    var lat: u8[>..] = [];
    push_utf8(cyr, 0x0430);
    push_utf8(cyr, 0x0062);
    push_utf8(cyr, 0x0063);
    push_utf8(lat, 0x0061);
    push_utf8(lat, 0x0062);
    push_utf8(lat, 0x0063);
    bad += cf_check(unicode::confusable(cyr[..], lat[..]), "cyrillic a");
    bad += cf_check(!unicode::confusable(cyr[..], "abd"), "cyrillic a and abd");
    // The m and the rn.
    var m: u8[>..] = [];
    push_utf8(m, 0x006D);
    bad += cf_check(unicode::confusable(m[..], "rn"), "m and rn");
    // The kelvin sign and the K.
    var kelvin: u8[>..] = [];
    push_utf8(kelvin, 0x212A);
    bad += cf_check(unicode::confusable(kelvin[..], "K"), "kelvin and K");
    // The case stays in the skeleton, so the two cases differ.
    bad += cf_check(!unicode::confusable("a", "A"), "case stays");
    // The skeleton of a text is the skeleton of the skeleton.
    var out: u8[>..] = [];
    var out2: u8[>..] = [];
    let c1, _ = unicode::skeleton(out, "abc");
    let c2, _ = unicode::skeleton(out2, out[..]);
    bad += cf_check(c1 == unicode::OK && c2 == unicode::OK && out[..] == out2[..], "stable");
    return bad;
}

// The faults and the bounds.
fn cf_faults() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var s: u8[>..] = [];
    cf_append(s, "ab\xFFcd");
    let c1, o1 = unicode::skeleton(out, s[..]);
    bad += cf_check(c1 == unicode::ERR_BAD_UTF8 && o1 == 2 && out.len == 0, "bad byte");
    // A bad byte gives false in the compare.
    bad += cf_check(!unicode::confusable(s[..], "abc"), "bad byte in compare");
    // A text above MAX_INPUT gives ERR_TOO_LONG.
    var big: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { big.push('a'); }
    let c2, _ = unicode::skeleton(out, big[..]);
    bad += cf_check(c2 == unicode::ERR_TOO_LONG && out.len == 0, "input above the bound");
    // A hostile text of the longest mapping grows the result above
    // MAX_OUTPUT. The Arabic ligature U+FDFA maps to 18 code points.
    var many: u8[>..] = [];
    var i2: i64 = 0;
    while i2 < unicode::MAX_INPUT {
        push_utf8(many, 0xFDFA);
        i2 += 3;
    }
    let c3, _ = unicode::skeleton(out, many[..]);
    bad += cf_check(c3 == unicode::ERR_TOO_LONG && out.len == 0, "output above the bound");
    // A linear hostile text runs clean.
    var wall: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { wall.push('a'); }
    let c4, _ = unicode::skeleton(out, wall[..]);
    bad += cf_check(c4 == unicode::OK && out.len > 0, "1 MiB of ASCII");
    // A surrogate is a bad byte.
    var sur: u8[>..] = [];
    cf_append(sur, "a\xED\xA0\x80b");
    let c5, o5 = unicode::skeleton(out, sur[..]);
    bad += cf_check(c5 == unicode::ERR_BAD_UTF8 && o5 == 1, "surrogate");
    // An empty text gives an empty skeleton.
    let c6, _ = unicode::skeleton(out, "");
    bad += cf_check(c6 == unicode::OK && out.len == 0, "empty text");
    return bad;
}

fn run_confusable() -> i64 {
    var bad = 0;
    if want("confusable", "cf_rows") { bad += cf_rows(); }
    if want("confusable", "cf_strings") { bad += cf_strings(); }
    if want("confusable", "cf_pairs") { bad += cf_pairs(); }
    if want("confusable", "cf_faults") { bad += cf_faults(); }
    return bad;
}
