// Tests for UTF-8 decode, encode and validation.
namespace suite;

import std;
import unicode from "../..";

// The bytes of one code point, as a literal.
fn cp_bytes(cp: i64) -> u8[>..] {
    var out: u8[>..] = [];
    push_utf8(out, cp);
    return out;
}

// A byte string from a list of byte values.
fn raw(values: const i64[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..values.len { out.push(values[k] as u8); }
    return out;
}

// Checks that a byte string is rejected, and that the offset of the
// first bad byte is the one that the standard gives.
fn bad_at(values: const i64[:], at: i64) -> i64 {
    var s = raw(values);
    if unicode::utf8_valid(s[..]) { print("FAIL: the bytes were accepted\n"); return 1; }
    var cps: i64[>..] = [];
    let code, off = unicode::utf8_decode(cps, s[..]);
    if code != unicode::ERR_BAD_UTF8 {
        print("FAIL: the bytes gave the code ", code, "\n");
        return 1;
    }
    if off != at {
        print("FAIL: the offset was ", off, " and not ", at, "\n");
        return 1;
    }
    if cps.len != 0 { print("FAIL: the decode kept code points\n"); return 1; }
    return 0;
}

// Checks that a byte string is accepted and gives the code points.
fn good_cps(values: const i64[:], want: const i64[:]) -> i64 {
    var s = raw(values);
    if !unicode::utf8_valid(s[..]) { print("FAIL: the bytes were rejected\n"); return 1; }
    var cps: i64[>..] = [];
    let code, off = unicode::utf8_decode(cps, s[..]);
    if code != unicode::OK { print("FAIL: the decode gave the code ", code, "\n"); return 1; }
    if off != -1 { print("FAIL: the offset was ", off, "\n"); return 1; }
    if cps.len != want.len { print("FAIL: the count was ", cps.len, "\n"); return 1; }
    for k in 0..want.len {
        if cps[k] != want[k] {
            print("FAIL: the code point ", k, " was ", cps[k], "\n");
            return 1;
        }
    }
    return 0;
}

// The boundary code points of the UTF-8 forms.
fn utf8_boundaries() -> i64 {
    var bad = 0;
    let cps: i64[8] = [0, 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x10000, 0x10FFFF];
    for k in 0..cps.len {
        var out: u8[>..] = [];
        let code = unicode::utf8_encode(out, cps[k]);
        if code != unicode::OK { print("FAIL: the encode refused a code point\n"); bad += 1; continue; }
        var back: i64[>..] = [];
        let c2, off = unicode::utf8_decode(back, out[..]);
        if c2 != unicode::OK || back.len != 1 || back[0] != cps[k] {
            print("FAIL: the round trip failed for ", cps[k], "\n");
            bad += 1;
        }
    }
    // The length of each form.
    let lens: i64[8] = [1, 1, 2, 2, 3, 3, 4, 4];
    for k in 0..cps.len {
        var out: u8[>..] = [];
        unicode::utf8_encode(out, cps[k]);
        if out.len != lens[k] {
            print("FAIL: the form of ", cps[k], " had ", out.len, " bytes\n");
            bad += 1;
        }
    }
    return bad;
}

// The malformed corpus.
fn test_malformed() -> i64 {
    var bad = 0;
    // A continuation byte at the start.
    bad += bad_at([0x80], 0);
    bad += bad_at([0xBF], 0);
    // An overlong form of two bytes.
    bad += bad_at([0xC0, 0x80], 0);
    bad += bad_at([0xC1, 0xBF], 0);
    // An overlong form of three bytes.
    bad += bad_at([0xE0, 0x80, 0x80], 0);
    bad += bad_at([0xE0, 0x9F, 0xBF], 0);
    // An overlong form of four bytes.
    bad += bad_at([0xF0, 0x80, 0x80, 0x80], 0);
    bad += bad_at([0xF0, 0x8F, 0xBF, 0xBF], 0);
    // A surrogate.
    bad += bad_at([0xED, 0xA0, 0x80], 0);
    bad += bad_at([0xED, 0xBF, 0xBF], 0);
    // A value above 0x10FFFF.
    bad += bad_at([0xF4, 0x90, 0x80, 0x80], 0);
    bad += bad_at([0xF5, 0x80, 0x80, 0x80], 0);
    bad += bad_at([0xFE], 0);
    bad += bad_at([0xFF], 0);
    // A lead byte above 0xF4.
    bad += bad_at([0xF7, 0x80, 0x80, 0x80], 0);
    // A truncated sequence.
    bad += bad_at([0xC3], 0);
    bad += bad_at([0xE2, 0x82], 0);
    bad += bad_at([0xF0, 0x9F, 0x98], 0);
    // A bad byte after good text.
    bad += bad_at([0x41, 0x42, 0x80], 2);
    bad += bad_at([0x41, 0xE2, 0x82], 1);
    bad += bad_at([0x41, 0x42, 0x43, 0xED, 0xA0, 0x80], 3);
    // A bad continuation byte.
    bad += bad_at([0xE2, 0x28, 0xA1], 0);
    bad += bad_at([0xF0, 0x28, 0x8C, 0x28], 0);
    return bad;
}

// The text of one name, in two forms.
const TWO_FORMS: u8[] = "caf\xC3\xA9";

// Cuts the text at every position. A cut at a boundary gives two pieces
// that are well formed. A cut inside a sequence gives a piece that the
// standard rejects.
fn test_truncation() -> i64 {
    var bad = 0;
    // The boundaries of the text: every byte that starts a sequence.
    let bounds: i64[5] = [0, 1, 2, 3, 5];
    for k in 0..bounds.len {
        let cut = bounds[k];
        var piece: u8[>..] = [];
        piece.append(TWO_FORMS[0..cut]);
        if !unicode::utf8_valid(piece[..]) {
            print("FAIL: a cut of the text was rejected at ", cut, "\n");
            bad += 1;
        }
        var rest: u8[>..] = [];
        rest.append(TWO_FORMS[cut..TWO_FORMS.len]);
        if !unicode::utf8_valid(rest[..]) {
            print("FAIL: a tail of the text was rejected at ", cut, "\n");
            bad += 1;
        }
    }
    // A cut inside the two byte sequence.
    var piece: u8[>..] = [];
    piece.append(TWO_FORMS[0..4]);
    if unicode::utf8_valid(piece[..]) {
        print("FAIL: a cut inside a sequence was accepted\n");
        bad += 1;
    }
    return bad;
}

// The good corpus, with the code points that each byte string holds.
fn test_good() -> i64 {
    var bad = 0;
    bad += good_cps([0x41], [0x41]);
    bad += good_cps([0x7F], [0x7F]);
    bad += good_cps([0xC2, 0xA2], [0xA2]);
    bad += good_cps([0xE2, 0x82, 0xAC], [0x20AC]);
    bad += good_cps([0xF0, 0x9F, 0x98, 0x80], [0x1F600]);
    bad += good_cps([0xF4, 0x8F, 0xBF, 0xBF], [0x10FFFF]);
    bad += good_cps([0x61, 0x62, 0x63], [0x61, 0x62, 0x63]);
    bad += good_cps([], []);
    return bad;
}

// The encode faults.
fn test_encode_faults() -> i64 {
    var bad = 0;
    let bad_cp: i64[5] = [-1, 0xD800, 0xDFFF, 0x110000, 0x7FFFFFFF];
    for k in 0..bad_cp.len {
        var out: u8[>..] = [];
        out.push(0x41);
        let code = unicode::utf8_encode(out, bad_cp[k]);
        if code != unicode::ERR_BAD_CODEPOINT {
            print("FAIL: the encode gave the code ", code, "\n");
            bad += 1;
        }
        if out.len != 1 { print("FAIL: the encode wrote bytes\n"); bad += 1; }
    }
    return bad;
}

// The round trip over 100,000 seeded random texts of code points.
fn test_round_trip() -> i64 {
    var bad = 0;
    var st: u64 = 12345;
    for k in 0..100000 {
        var text: u8[>..] = [];
        let n = rnd(st) % 6;
        for j in 0..n {
            let r = rnd(st);
            var cp: i64 = r % 0x110000;
            if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
            push_utf8(text, cp);
        }
        var cps: i64[>..] = [];
        let code, off = unicode::utf8_decode(cps, text[..]);
        if code != unicode::OK { print("FAIL: the decode refused a good text\n"); bad += 1; continue; }
        var back: u8[>..] = [];
        for j in 0..cps.len {
            let c3 = unicode::utf8_encode(back, cps[j]);
            if c3 != unicode::OK { print("FAIL: the encode refused a code point\n"); bad += 1; break; }
        }
        if back[..] != text[..] {
            print("FAIL: the round trip changed the bytes at ", k, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The input bound. An input above MAX_INPUT gives ERR_TOO_LONG.
fn test_input_bound() -> i64 {
    var bad = 0;
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x41); }
    if unicode::utf8_valid(big[..]) { print("FAIL: the bound was not checked\n"); bad += 1; }
    var cps: i64[>..] = [];
    let code, off = unicode::utf8_decode(cps, big[..]);
    if code != unicode::ERR_TOO_LONG { print("FAIL: the decode gave the code ", code, "\n"); bad += 1; }
    if cps.len != 0 { print("FAIL: the decode kept code points\n"); bad += 1; }
    return bad;
}

fn run_utf8() -> i64 {
    var bad = 0;
    bad += test_good();
    bad += test_malformed();
    bad += test_truncation();
    bad += utf8_boundaries();
    bad += test_encode_faults();
    bad += test_round_trip();
    bad += test_input_bound();
    return bad;
}
