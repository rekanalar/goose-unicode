// Tests for the lossy decode, the byte order mark and the calls with a
// fault code. The cases replay the converters of the ICU library, release
// 79.1, over 51,911 byte strings of UTF-8, UTF-16 and UTF-32, and over
// 291 texts that start with a mark or part of a mark.
namespace suite;

import std;
import os;
import unicode from "../..";
import lossy_cases;

// The 3 byte value at byte offset p of a pool. The low byte comes first.
fn lz_val(pool: const u8[:], p: i64) -> i64 {
    return (pool[p] as i64) | ((pool[p + 1] as i64) << 8) | ((pool[p + 2] as i64) << 16);
}

// Decodes one case with the call of its kind.
fn lz_decode(kind: i64, out: i64[>..]&, data: const u8[:]) -> i64, i64 {
    if kind == 0 { return unicode::utf8_decode_lossy(out, data); }
    if kind == 1 { return unicode::utf16_decode_lossy(out, data, false); }
    if kind == 2 { return unicode::utf16_decode_lossy(out, data, true); }
    if kind == 3 { return unicode::utf32_decode_lossy(out, data, false); }
    return unicode::utf32_decode_lossy(out, data, true);
}

// Replays every lossy case of the pool.
fn lz_battery() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    var p: i64 = 0;
    for c in 0..LOSSY_CASES {
        let kind = LOSSY_POOL[p] as i64;
        let n = lz_val(LOSSY_POOL[..], p + 1);
        let data = LOSSY_POOL[p + 4..p + 4 + n];
        p += 4 + n;
        let m = lz_val(LOSSY_POOL[..], p);
        p += 3;
        let code, nbad = lz_decode(kind, out, data);
        var ok = code == unicode::OK && out.len == m;
        if ok {
            for k in 0..m {
                if out[k] != lz_val(LOSSY_POOL[..], p + 3 * k) { ok = false; break; }
            }
        }
        p += 3 * m;
        let want_bad = lz_val(LOSSY_POOL[..], p);
        p += 3;
        if ok && nbad != want_bad { ok = false; }
        if !ok {
            print("FAIL: lossy case ", c, " kind ", kind, " gave ", out.len, " code points and ", nbad, " replacements\n");
            bad += 1;
            if bad > 10 { return bad; }
        }
    }
    if bad == 0 { print("lossy battery ok: ", LOSSY_CASES, " cases\n"); }
    return bad;
}

// Appends the bytes of vals to out.
fn lz_bytes(out: u8[>..]&, vals: const i64[:]) {
    out.clear();
    for k in 0..vals.len { out.push(vals[k] as u8); }
}

// True when the code points of out equal want.
fn lz_same(out: const i64[:], want: const i64[:]) -> bool {
    if out.len != want.len { return false; }
    for k in 0..out.len {
        if out[k] != want[k] { return false; }
    }
    return true;
}

// The byte order mark cases: the kind and the length of the mark, the
// strip of the UTF-8 mark and the auto decode against the plain decode.
fn lz_bom_battery() -> i64 {
    var bad: i64 = 0;
    var p: i64 = 0;
    var a: i64[>..] = [];
    var b: i64[>..] = [];
    var stripped: u8[>..] = [];
    for c in 0..BOM_CASES {
        let n = lz_val(BOM_POOL[..], p);
        let data = BOM_POOL[p + 3..p + 3 + n];
        p += 3 + n;
        let want_kind = BOM_POOL[p] as i64;
        let want_len = BOM_POOL[p + 1] as i64;
        p += 2;
        let kind, len = unicode::bom_detect(data);
        if kind != want_kind || len != want_len {
            print("FAIL: bom case ", c, " gave ", kind, " ", len, " and not ", want_kind, " ", want_len, "\n");
            bad += 1;
            continue;
        }
        let code = unicode::utf8_strip_bom(stripped, data);
        var skip8: i64 = 0;
        if kind == unicode::BOM_UTF8 { skip8 = 3; }
        if code != unicode::OK || stripped.len != n - skip8 {
            print("FAIL: bom case ", c, " strip gave ", stripped.len, " bytes\n");
            bad += 1;
        }
        // The UTF-16 decode reads a UTF-16 mark only. The UTF-32 marks
        // start with the bytes of the little endian UTF-16 mark, and
        // the call reads them as that mark.
        var skip16: i64 = 0;
        var be16 = false;
        if n >= 2 && data[0] == 0xFE && data[1] == 0xFF { skip16 = 2; be16 = true; }
        if n >= 2 && data[0] == 0xFF && data[1] == 0xFE { skip16 = 2; }
        let c1, o1 = unicode::utf16_decode_auto(a, data, false);
        let c2, o2 = unicode::utf16_decode(b, data[skip16..n], be16);
        if c1 != c2 || !lz_same(a[..], b[..]) || (o2 >= 0 && o1 != o2 + skip16) || (o2 < 0 && o1 >= 0) {
            print("FAIL: bom case ", c, " utf16 auto differs from the plain decode\n");
            bad += 1;
        }
        var skip32: i64 = 0;
        var be32 = false;
        if kind == unicode::BOM_UTF32BE { skip32 = 4; be32 = true; }
        if kind == unicode::BOM_UTF32LE { skip32 = 4; }
        let c3, o3 = unicode::utf32_decode_auto(a, data, false);
        let c4, o4 = unicode::utf32_decode(b, data[skip32..n], be32);
        if c3 != c4 || !lz_same(a[..], b[..]) || (o4 >= 0 && o3 != o4 + skip32) || (o4 < 0 && o3 >= 0) {
            print("FAIL: bom case ", c, " utf32 auto differs from the plain decode\n");
            bad += 1;
        }
    }
    if bad == 0 { print("bom battery ok: ", BOM_CASES, " cases\n"); }
    return bad;
}

// The scenarios of the byte order mark and of the auto decode.
fn lz_scenarios() -> i64 {
    var bad: i64 = 0;
    var s: u8[>..] = [];
    var out: i64[>..] = [];
    // FF FE 00 00 is a UTF-16 mark and a null for the UTF-16 call.
    lz_bytes(s, [0xFF, 0xFE, 0x00, 0x00]);
    let c1, o1 = unicode::utf16_decode_auto(out, s[..], true);
    if c1 != unicode::OK || !lz_same(out[..], [0]) {
        print("FAIL: utf16 auto on FF FE 00 00 gave ", c1, " and ", out.len, " code points\n");
        bad += 1;
    }
    // No mark: the default byte order applies and nothing is dropped.
    lz_bytes(s, [0x00, 0x41]);
    let c2, o2 = unicode::utf16_decode_auto(out, s[..], true);
    if c2 != unicode::OK || !lz_same(out[..], [0x41]) {
        print("FAIL: utf16 auto without a mark, big endian default\n");
        bad += 1;
    }
    let c3, o3 = unicode::utf16_decode_auto(out, s[..], false);
    if c3 != unicode::OK || !lz_same(out[..], [0x4100]) {
        print("FAIL: utf16 auto without a mark, little endian default\n");
        bad += 1;
    }
    // A second mark stays as U+FEFF.
    lz_bytes(s, [0xFE, 0xFF, 0xFE, 0xFF, 0x00, 0x41]);
    let c4, o4 = unicode::utf16_decode_auto(out, s[..], false);
    if c4 != unicode::OK || !lz_same(out[..], [0xFEFF, 0x41]) {
        print("FAIL: utf16 auto keeps a second mark\n");
        bad += 1;
    }
    // The fault offset counts from the first byte, the mark included.
    lz_bytes(s, [0xFF, 0xFE, 0x41]);
    let c5, o5 = unicode::utf16_decode_auto(out, s[..], false);
    if c5 != unicode::ERR_BAD_UTF16 || o5 != 2 || out.len != 0 {
        print("FAIL: utf16 auto fault gave ", c5, " at ", o5, "\n");
        bad += 1;
    }
    lz_bytes(s, [0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0xD8, 0x00]);
    let c6, o6 = unicode::utf32_decode_auto(out, s[..], false);
    if c6 != unicode::ERR_BAD_UTF32 || o6 != 4 || out.len != 0 {
        print("FAIL: utf32 auto fault gave ", c6, " at ", o6, "\n");
        bad += 1;
    }
    lz_bytes(s, [0xFF, 0xFE, 0x00, 0x00, 0x41, 0x00, 0x00, 0x00]);
    let c7, o7 = unicode::utf32_decode_auto(out, s[..], true);
    if c7 != unicode::OK || !lz_same(out[..], [0x41]) {
        print("FAIL: utf32 auto little endian mark\n");
        bad += 1;
    }
    // The lossy scenarios of the spec.
    lz_bytes(s, [0x41, 0x80, 0x42]);
    let c8, n8 = unicode::utf8_decode_lossy(out, s[..]);
    if c8 != unicode::OK || n8 != 1 || !lz_same(out[..], [0x41, 0xFFFD, 0x42]) {
        print("FAIL: lossy 41 80 42\n");
        bad += 1;
    }
    // A real U+FFFD in the input is no replacement.
    lz_bytes(s, [0xEF, 0xBF, 0xBD]);
    let c9, n9 = unicode::utf8_decode_lossy(out, s[..]);
    if c9 != unicode::OK || n9 != 0 || !lz_same(out[..], [0xFFFD]) {
        print("FAIL: lossy counts a real U+FFFD\n");
        bad += 1;
    }
    return bad;
}

// The checked calls give the old result and add a fault code.
fn lz_checked() -> i64 {
    var bad: i64 = 0;
    var q: u8[>..] = [];
    let names = ["LATIN SMALL LETTER A", "latin small letter a", "NO SUCH NAME", "", "SPACE",
        "ZERO WIDTH NO-BREAK SPACE", "BYTE ORDER MARK"];
    for k in 0..names.len {
        lz_bytes_text(q, names[k]);
        let code, cp = unicode::lookup_checked(q[..]);
        if code != unicode::OK || cp != unicode::lookup(q[..]) {
            print("FAIL: lookup_checked differs from lookup on ", names[k], "\n");
            bad += 1;
        }
    }
    lz_bytes_text(q, "LATIN SMALL LETTER A");
    let ca, cpa = unicode::lookup_checked(q[..]);
    if ca != unicode::OK || cpa != 0x61 {
        print("FAIL: lookup_checked on the name of a gave ", ca, " and ", cpa, "\n");
        bad += 1;
    }
    q.clear();
    for k in 0..129 { q.push(0x41); }
    let cb, cpb = unicode::lookup_checked(q[..]);
    if cb != unicode::ERR_TOO_LONG || cpb != -1 {
        print("FAIL: lookup_checked on 129 bytes gave ", cb, "\n");
        bad += 1;
    }
    lz_bytes(q, [0x41, 0xFF]);
    let cc, cpc = unicode::lookup_checked(q[..]);
    if cc != unicode::ERR_BAD_UTF8 || cpc != -1 {
        print("FAIL: lookup_checked on a bad byte gave ", cc, "\n");
        bad += 1;
    }
    // is_word_like_checked.
    var t: u8[>..] = [];
    lz_bytes_text(t, "ab, 12");
    let s = t[..];
    let ranges = [[0, 2], [2, 4], [4, 6], [3, 3], [0, 6]];
    for k in 0..ranges.len {
        let code, flag = unicode::is_word_like_checked(s, ranges[k][0], ranges[k][1]);
        let want = unicode::is_word_like(s, ranges[k][0], ranges[k][1]);
        if code != unicode::OK || flag != want {
            print("FAIL: is_word_like_checked range ", k, " gave ", code, "\n");
            bad += 1;
        }
    }
    let bad_ranges = [[-1, 2], [0, 7], [4, 2]];
    for k in 0..bad_ranges.len {
        let code, flag = unicode::is_word_like_checked(s, bad_ranges[k][0], bad_ranges[k][1]);
        if code != unicode::ERR_BAD_ARG || flag {
            print("FAIL: is_word_like_checked bad range ", k, " gave ", code, "\n");
            bad += 1;
        }
    }
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x61); }
    let cd, fd = unicode::is_word_like_checked(big[..], 0, 1);
    if cd != unicode::ERR_TOO_LONG || fd {
        print("FAIL: is_word_like_checked on a long text gave ", cd, "\n");
        bad += 1;
    }
    return bad;
}

// Copies the bytes of a text into out.
fn lz_bytes_text(out: u8[>..]&, text: const u8[:]) {
    out.clear();
    for k in 0..text.len { out.push(text[k]); }
}

// The bound and the hostile texts.
fn lz_faults() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x41); }
    out.push(1);
    let c1, n1 = unicode::utf8_decode_lossy(out, big[..]);
    let c2, n2 = unicode::utf16_decode_lossy(out, big[..], false);
    let c3, n3 = unicode::utf32_decode_lossy(out, big[..], false);
    if c1 != unicode::ERR_TOO_LONG || c2 != unicode::ERR_TOO_LONG || c3 != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: lossy calls above the bound gave ", c1, " ", c2, " ", c3, "\n");
        bad += 1;
    }
    var empty: u8[>..] = [];
    let c4, n4 = unicode::utf8_decode_lossy(out, empty[..]);
    if c4 != unicode::OK || n4 != 0 || out.len != 0 {
        print("FAIL: lossy decode of empty input gave ", c4, "\n");
        bad += 1;
    }
    // One mebibyte of bad bytes: one U+FFFD for each byte.
    var junk: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT { junk.push(0xFF); }
    let t0 = clock_ns();
    let c5, n5 = unicode::utf8_decode_lossy(out, junk[..]);
    let t1 = clock_ns();
    if c5 != unicode::OK || out.len != unicode::MAX_INPUT || n5 != unicode::MAX_INPUT || (t1 - t0) / 1000000 > 5000 {
        print("FAIL: lossy decode of bad bytes gave ", c5, " ", out.len, " in ", (t1 - t0) / 1000000, " ms\n");
        bad += 1;
    }
    // One mebibyte that alternates a truncated lead and a letter.
    junk.clear();
    while junk.len + 2 <= unicode::MAX_INPUT { junk.push(0xE2); junk.push(0x41); }
    let t2 = clock_ns();
    let c6, n6 = unicode::utf8_decode_lossy(out, junk[..]);
    let t3 = clock_ns();
    if c6 != unicode::OK || out.len != junk.len || (t3 - t2) / 1000000 > 5000 {
        print("FAIL: lossy decode of leads and letters gave ", c6, " ", out.len, " in ", (t3 - t2) / 1000000, " ms\n");
        bad += 1;
    }
    // UTF-16 with a lone surrogate before every letter.
    junk.clear();
    while junk.len + 4 <= unicode::MAX_INPUT { junk.push(0x00); junk.push(0xD8); junk.push(0x41); junk.push(0x00); }
    let t4 = clock_ns();
    let c7, n7 = unicode::utf16_decode_lossy(out, junk[..], false);
    let t5 = clock_ns();
    if c7 != unicode::OK || out.len != junk.len / 2 || (t5 - t4) / 1000000 > 5000 {
        print("FAIL: lossy utf16 hostile text gave ", c7, " ", out.len, " in ", (t5 - t4) / 1000000, " ms\n");
        bad += 1;
    }
    if bad == 0 {
        print("lossy faults ok: bad bytes ", (t1 - t0) / 1000000, " ms, leads ", (t3 - t2) / 1000000, " ms, utf16 ", (t5 - t4) / 1000000, " ms\n");
    }
    return bad;
}

fn run_lossy() -> i64 {
    var bad: i64 = 0;
    bad += lz_battery();
    bad += lz_bom_battery();
    bad += lz_scenarios();
    bad += lz_checked();
    bad += lz_faults();
    return bad;
}
