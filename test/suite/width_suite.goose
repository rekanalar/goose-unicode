// Tests for the width calls.
namespace suite;

import std;
import unicode from "../..";

// The code points of one case of the case file.
fn w_case(case: i64) -> i64[>..] {
    let start = W_OFF[case];
    let n = W_POOL[start];
    var out: i64[>..] = [];
    for k in 1..n + 1 { out.push(W_POOL[start + k]); }
    return out;
}

// The UTF-8 bytes of the code points.
fn w_bytes(cps: const i64[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..cps.len {
        unicode::utf8_encode(out, cps[k]);
    }
    return out;
}

// Pins of char_width: the rule examples, the bounds and the refusals.
fn w_chars() -> i64 {
    var bad = 0;
    let pins: i64[>..] = [
        0x41, 0x7E, 0x20, 0xA0, 0x4E2D, 0x17D8, 0x115F, 0x17A4, 0x2D7F,
        0xFE0F, 0xFE0E, 0xFE01, 0xFE00, 0x0300, 0x1160, 0xA8FA, 0x0605,
        0x0600, 0x110F, 0x1F1E9, 0x1F1EA, 0x1F3FB, 0x1F3FF, 0x1F600,
        0x231A, 0x2764, 0x00A9, 0x10FFFF, 0x10C03, 0x16D67, 0x1A10,
        0x05DC, 0x0622, 0x1780, 0x2D6F, 0xA4FC,
        -1, 0x110000, 0xD800, 0xDBFF, 0xDC00, 0xDFFF, 0x1F, 0x00, 0x7F, 0x9F,
    ];
    let want: i64[>..] = [
        1, 1, 1, 1, 2, 3, 2, 2, 1,
        0, 0, 0, 0, 0, 0, 0, 0,
        1, 2, 1, 1, 2, 2, 2,
        2, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    ];
    if pins.len != want.len {
        print("FAIL: the width pins do not match\n");
        return 1;
    }
    for k in 0..pins.len {
        let got = unicode::char_width(pins[k]);
        if got != want[k] {
            print("FAIL: char_width(", pins[k], ") = ", got, ", want ", want[k], "\n");
            bad += 1;
        }
    }
    return bad;
}

// Every case of the case file: the width of the text, from the crate.
fn w_string_cases() -> i64 {
    var bad = 0;
    var buf: u8[>..] = [];
    for c in 0..W_EXP.len {
        let cps = w_case(c);
        buf.clear();
        for k in 0..cps.len {
            unicode::utf8_encode(buf, cps[k]);
        }
        let code, w = unicode::string_width(buf[..]);
        if code != unicode::OK {
            print("FAIL: case ", c, " gave fault ", code, "\n");
            bad += 1;
            continue;
        }
        if w != W_EXP[c] {
            print("FAIL: case ", c, " width ", w, ", want ", W_EXP[c], "\n");
            bad += 1;
            if bad > 20 { print("FAIL: too many wrong widths\n"); return bad; }
        }
    }
    if W_EXP.len != 50040 {
        print("FAIL: the case file holds ", W_EXP.len, " cases\n");
        bad += 1;
    }
    return bad;
}

// The faults: a bad byte and an input above the bound.
fn w_faults() -> i64 {
    var bad = 0;
    // A bad byte in the middle of a flag.
    var s: u8[>..] = [];
    s.push(0xF0);
    s.push(0x9F);
    s.push(0x87);   // start of a regional indicator, then a broken byte
    s.push(0xFF);
    let code1, w1 = unicode::string_width(s[..]);
    if code1 != unicode::ERR_BAD_UTF8 || w1 != 0 {
        print("FAIL: a bad byte gave ", code1, ", ", w1, "\n");
        bad += 1;
    }
    // A lone continuation byte.
    var lone: u8[>..] = [];
    lone.push(0x80);
    let code2, w2 = unicode::string_width(lone[..]);
    if code2 != unicode::ERR_BAD_UTF8 {
        print("FAIL: a lone continuation byte gave ", code2, "\n");
        bad += 1;
    }
    // A truncated sequence.
    var cut: u8[>..] = [];
    cut.push(0xE2);
    cut.push(0x82);
    let code3, w3 = unicode::string_width(cut[..]);
    if code3 != unicode::ERR_BAD_UTF8 {
        print("FAIL: a truncated sequence gave ", code3, "\n");
        bad += 1;
    }
    // A text of one byte above the bound.
    var big: u8[>..] = [];
    for k in 0..1048577 { big.push(0x61); }
    let code4, w4 = unicode::string_width(big[..]);
    if code4 != unicode::ERR_TOO_LONG || w4 != 0 {
        print("FAIL: a long text gave ", code4, ", ", w4, "\n");
        bad += 1;
    }
    return bad;
}

// Hostile texts of the largest size. Each call must run in one pass, so
// the run holds a few repeats of the same text.
fn w_hostile() -> i64 {
    var bad = 0;
    // Regional indicators: half of them pair, and the width counts them.
    var ris: u8[>..] = [];
    for k in 0..262144 {
        unicode::utf8_encode(ris, 0x1F1E6 + (k % 26));
    }
    if ris.len != 1048576 {
        print("FAIL: the regional indicator text holds ", ris.len, " bytes\n");
        bad += 1;
    }
    for r in 0..3 {
        let code, w = unicode::string_width(ris[..]);
        if code != unicode::OK || w != 262144 {
            print("FAIL: the flag run gave ", code, ", ", w, "\n");
            bad += 1;
        }
    }
    // Joiner runs: the joiners chain into one sequence, so the whole
    // run counts as 2. The group holds 14 bytes, so the count of groups
    // fills the bound.
    var zwj: u8[>..] = [];
    let groups = 74898;
    for k in 0..groups {
        unicode::utf8_encode(zwj, 0x1F468);
        unicode::utf8_encode(zwj, 0x200D);
        unicode::utf8_encode(zwj, 0x1F469);
        unicode::utf8_encode(zwj, 0x200D);
    }
    for r in 0..3 {
        let code, w = unicode::string_width(zwj[..]);
        if code != unicode::OK || w != 2 {
            print("FAIL: the joiner run gave ", code, ", ", w, "\n");
            bad += 1;
        }
    }
    // Variation selectors after every letter. A letter that takes no
    // emoji form keeps its width of 1. A pair holds 4 bytes.
    var vs: u8[>..] = [];
    for k in 0..262144 {
        unicode::utf8_encode(vs, 0x61);
        unicode::utf8_encode(vs, 0xFE0F);
    }
    for r in 0..3 {
        let code, w = unicode::string_width(vs[..]);
        if code != unicode::OK || w != 262144 {
            print("FAIL: the selector run gave ", code, ", ", w, "\n");
            bad += 1;
        }
    }
    return bad;
}

fn run_width() -> i64 {
    var bad = 0;
    bad += w_chars();
    bad += w_string_cases();
    bad += w_faults();
    bad += w_hostile();
    return bad;
}
