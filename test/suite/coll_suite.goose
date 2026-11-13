// Tests for the root collation.
namespace suite;

import std;
import unicode from "../..";

fn co_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: collation ", name, "\n"); return 1; }
    return 0;
}

fn co_min(a: i64, b: i64) -> i64 {
    if a < b { return a; }
    return b;
}

// The byte order of two keys: -1, 0 or 1. A shorter key that is a
// prefix of the other orders first.
fn co_key_sign(a: const i64[:], b: const i64[:]) -> i64 {
    let n = co_min(a.len, b.len);
    for k in 0..n {
        if a[k] != b[k] {
            if a[k] < b[k] { return -1; }
            return 1;
        }
    }
    if a.len < b.len { return -1; }
    if a.len > b.len { return 1; }
    return 0;
}

// One compare call against the wanted sign.
fn co_sign(out: i64[>..]&, a: const u8[:], b: const u8[:], want: i64, name: const u8[:]) -> i64 {
    let code, off = unicode::compare(out, a, b);
    if code != unicode::OK {
        print("FAIL: collation ", name, " fault ", code, "\n");
        return 1;
    }
    if out.len != 1 || out[0] != want {
        print("FAIL: collation ", name, " sign ", out[0], " want ", want, "\n");
        return 1;
    }
    return 0;
}

// The fixed samples: the order of well known texts, the empty text and
// the agreement of sort_key with compare.
fn co_samples() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var k1: i64[>..] = [];
    var k2: i64[>..] = [];
    bad += co_sign(out, "a", "b", -1, "a before b");
    bad += co_sign(out, "b", "a", 1, "b after a");
    bad += co_sign(out, "a", "A", -1, "lower case first");
    bad += co_sign(out, "a", "ä", -1, "accent after base");
    bad += co_sign(out, "ä", "b", -1, "accent before next letter");
    bad += co_sign(out, "a-b", "ab", -1, "dash before plain");
    bad += co_sign(out, "a", "ab", -1, "prefix first");
    bad += co_sign(out, "", "", 0, "two empty texts");
    bad += co_sign(out, "a", "a", 0, "equal texts");
    bad += co_sign(out, "Straße", "Strasse", 1, "sharp s after ss");
    bad += co_sign(out, "ABC", "abc", 1, "case of a word");
    bad += co_sign(out, "abc", "abd", -1, "third letter");
    // sort_key agrees with compare: the sign of the keys gives the sign
    // of the compare. The samples cover a letter, an accent, a case
    // pair, a Cyrillic pair, a face pair, the longest expansion, an
    // unassigned code point and a variable character.
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    for p in 0..CO_SAMPLE_A.len {
        ta.clear();
        tb.clear();
        unicode::utf8_encode(ta, CO_SAMPLE_A[p]);
        unicode::utf8_encode(tb, CO_SAMPLE_B[p]);
        let c1, _ = unicode::sort_key(k1, ta[..]);
        let c2, _ = unicode::sort_key(k2, tb[..]);
        let code, _ = unicode::compare(out, ta[..], tb[..]);
        if c1 != unicode::OK || c2 != unicode::OK || code != unicode::OK {
            bad += co_check(false, "sample fault");
            continue;
        }
        let ks = co_key_sign(k1[..], k2[..]);
        if ks != out[0] {
            bad += co_check(false, "key and compare disagree");
        }
    }
    // The empty key: a text with no code point gives no bytes.
    let c3, _ = unicode::sort_key(k1, "");
    bad += co_check(c3 == unicode::OK && k1.len == 0, "empty key");
    // The key of one letter holds one weight per level and three level
    // bytes.
    let c4, _ = unicode::sort_key(k2, "a");
    bad += co_check(c4 == unicode::OK && k2.len == 6, "key of a");
    return bad;
}

// The code points of the key and compare agreement samples.
const CO_SAMPLE_A: i64[] = [0x61, 0xE4, 0x61, 0x443, 0x1F600, 0x62, 0xFDFA, 0xE9, 0x378, 0xA0, 0x41, 0x20];
const CO_SAMPLE_B: i64[] = [0x62, 0x62, 0x41, 0x441, 0x1F601, 0x62, 0x61, 0x65, 0x379, 0x20, 0x61, 0xA0];

// Every pair of neighbor lines of the conformance file. Each line
// orders strictly above the line before it. Every eighth line also
// checks the byte order of the sort keys.
fn co_replay() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var k1: i64[>..] = [];
    var k2: i64[>..] = [];
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    var ca: i64[>..] = [];
    var cb: i64[>..] = [];
    for i in 1..CC_OFF.len / 3 - 1 {
        ta.clear();
        tb.clear();
        let o0 = pool_val(CC_OFF, i - 1);
        let o1 = pool_val(CC_OFF, i);
        let o2 = pool_val(CC_OFF, i + 1);
        pool_load(ca, CC_POOL, o0, o1);
        pool_load(cb, CC_POOL, o1, o2);
        unicode::encode_all(ta, ca[..]);
        unicode::encode_all(tb, cb[..]);
        let code, off = unicode::compare(out, ta[..], tb[..]);
        if code != unicode::OK {
            bad += 1;
            if bad <= 5 { print("FAIL: conformance line ", i, " fault ", code, " lens ", ta.len, " ", tb.len, "\n"); }
            continue;
        }
        let want = -(CC_REL[i] as i64);
        if out.len != 1 || out[0] != want {
            bad += 1;
            if bad <= 5 { print("FAIL: conformance line ", i, " sign ", out[0], " want ", want, "\n"); }
        }
        if i % 8 == 0 {
            let c1, _ = unicode::sort_key(k1, ta[..]);
            let c2, _ = unicode::sort_key(k2, tb[..]);
            if c1 != unicode::OK || c2 != unicode::OK {
                bad += 1;
                if bad <= 5 { print("FAIL: key fault at line ", i, "\n"); }
            } else if co_key_sign(k1[..], k2[..]) != -(CC_REL[i] as i64) {
                bad += 1;
                if bad <= 5 { print("FAIL: key order at line ", i, "\n"); }
            }
        }
    }
    return bad;
}

// The random pairs of the whole range. The sign of the package equals
// the sign of the ICU collator on the und locale.
fn co_pairs() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var a: i64[>..] = [];
    var b: i64[>..] = [];
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    for p in 0..RP_SIGN.len {
        pool_load(a, RP_POOL, 2 * p, 2 * p + 1);
        pool_load(b, RP_POOL, 2 * p + 1, 2 * p + 2);
        ta.clear();
        tb.clear();
        unicode::encode_all(ta, a[..]);
        unicode::encode_all(tb, b[..]);
        let code, off = unicode::compare(out, ta[..], tb[..]);
        if code != unicode::OK {
            bad += 1;
            if bad <= 5 { print("FAIL: pair ", p, " fault ", code, "\n"); }
            continue;
        }
        if out.len != 1 || out[0] != (RP_SIGN[p] as i64) - 1 {
            bad += 1;
            if bad <= 5 { print("FAIL: pair ", p, " sign ", out[0], " want ", (RP_SIGN[p] as i64) - 1, "\n"); }
        }
    }
    return bad;
}

// The faults: a bad byte, a long text and a key above the bound.
fn co_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var k: i64[>..] = [];
    // A bad byte in sort_key gives its offset and an empty key.
    var s: u8[>..] = [];
    append_str(s, "ab\xFFcd");
    let c1, o1 = unicode::sort_key(k, s[..]);
    bad += co_check(c1 == unicode::ERR_BAD_UTF8 && o1 == 2 && k.len == 0, "bad byte offset");
    // A bad byte in the first text of compare gives the offset in it.
    var t: u8[>..] = [];
    append_str(t, "ok");
    let c2, o2 = unicode::compare(out, s[..], t[..]);
    bad += co_check(c2 == unicode::ERR_BAD_UTF8 && o2 == 2 && out.len == 0, "bad byte in a");
    // A bad byte in the second text gives the offset in it.
    let c3, o3 = unicode::compare(out, t[..], s[..]);
    bad += co_check(c3 == unicode::ERR_BAD_UTF8 && o3 == 2 && out.len == 0, "bad byte in b");
    // A text above MAX_INPUT gives ERR_TOO_LONG.
    var big: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { big.push('a'); }
    let c4, _ = unicode::sort_key(k, big[..]);
    bad += co_check(c4 == unicode::ERR_TOO_LONG && k.len == 0, "input above the bound");
    // A hostile text of expansions grows the key above MAX_OUTPUT. The
    // Arabic ligature U+FDFA holds the longest expansion of the table.
    var many: u8[>..] = [];
    var i: i64 = 0;
    while i < unicode::MAX_INPUT {
        push_utf8(many, 0xFDFA);
        i += 3;
    }
    let c5, _ = unicode::sort_key(k, many[..]);
    bad += co_check(c5 == unicode::ERR_TOO_LONG && k.len == 0, "key above the bound");
    let c6, _ = unicode::compare(out, many[..], big[..0]);
    bad += co_check(c6 == unicode::ERR_TOO_LONG && out.len == 0, "pair key above the bound");
    // A linear hostile text: 1 MiB of ASCII runs clean.
    var wall: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { wall.push('a'); }
    let c7, _ = unicode::sort_key(k, wall[..]);
    bad += co_check(c7 == unicode::OK && k.len > 0, "1 MiB of ASCII");
    // A surrogate is a bad byte.
    var sur: u8[>..] = [];
    append_str(sur, "a\xED\xA0\x80b");
    let c8, o8 = unicode::sort_key(k, sur[..]);
    bad += co_check(c8 == unicode::ERR_BAD_UTF8 && o8 == 1, "surrogate");
    return bad;
}

// Appends the bytes of one text to out.
fn append_str(out: u8[>..]&, s: const u8[:]) {
    for k in 0..s.len { out.push(s[k]); }
}

fn run_coll() -> i64 {
    var bad = 0;
    if want("coll", "co_samples") { bad += co_samples(); }
    if want("coll", "co_pairs") { bad += co_pairs(); }
    if want("coll", "co_replay") { bad += co_replay(); }
    if want("coll", "co_faults") { bad += co_faults(); }
    return bad;
}
