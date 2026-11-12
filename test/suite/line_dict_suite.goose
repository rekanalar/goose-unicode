// Tests for the dictionary line breaking. The cases replay the breaks of
// the ICU line iterator, release 79.1, over texts of Thai, Lao, Burmese
// and Khmer. The scenario cases pin the shapes that the README states.
// The fault cases pin the faults of the line break call.
namespace suite;

import std;
import os;
import unicode from "../..";
import line_dict_cases;

// The value at index i of the pool. Each value takes three bytes, low
// byte first.
fn ld_val(i: i64) -> i64 {
    let a = LINE_DICT_POOL[3 * i] as i64;
    let b = LINE_DICT_POOL[3 * i + 1] as i64;
    let c = LINE_DICT_POOL[3 * i + 2] as i64;
    return a | (b << 8) | (c << 16);
}

// Encodes the code points of cps and gives the byte offset of each code
// point. The last entry is the length of the text.
fn ld_encode(out: u8[>..]&, starts: i64[>..]&, cps: const i64[:]) {
    out.clear();
    starts.clear();
    for k in 0..cps.len {
        starts.push(out.len);
        unicode::utf8_encode(out, cps[k]);
    }
    starts.push(out.len);
}

// Compares the entries of line_breaks with the wanted breaks. The wanted
// offsets are in code points.
fn ld_compare(label: const u8[:], c: i64, text: const u8[:], starts: const i64[:],
        want_off: const i64[:], want_hard: const i64[:]) -> i64 {
    var got: i64[>..] = [];
    let code, off = unicode::line_breaks(got, text);
    if code != unicode::OK {
        print("FAIL: ", label, " ", c, " gave fault ", code, "\n");
        return 1;
    }
    if got.len != want_off.len {
        print("FAIL: ", label, " ", c, " gave ", got.len, " breaks and not ", want_off.len, ":");
        for k in 0..got.len { print(" ", got[k]); }
        print("\n");
        return 1;
    }
    for k in 0..got.len {
        let w = starts[want_off[k]] * 2 + want_hard[k];
        if got[k] != w {
            print("FAIL: ", label, " ", c, " gave ", got[k], " at ", k, " and not ", w, "\n");
            return 1;
        }
    }
    return 0;
}

// Replays every case of the pool.
fn ld_battery() -> i64 {
    var bad: i64 = 0;
    var pos: i64 = 0;
    var text: u8[>..] = [];
    var starts: i64[>..] = [];
    for c in 0..LINE_DICT_CASES {
        let n = ld_val(pos);
        var cps: i64[>..] = [];
        for k in 0..n { cps.push(ld_val(pos + 1 + k)); }
        let m = ld_val(pos + 1 + n);
        var off: i64[>..] = [];
        var hard: i64[>..] = [];
        for k in 0..m {
            off.push(ld_val(pos + 2 + n + 2 * k));
            hard.push(ld_val(pos + 3 + n + 2 * k));
        }
        pos += 2 + n + 2 * m;
        ld_encode(text, starts, cps[..]);
        bad += ld_compare("line dict case", c, text[..], starts[..], off[..], hard[..]);
        if bad > 20 { break; }
    }
    if bad == 0 { print("line dict battery: ", LINE_DICT_CASES, " cases ok\n"); }
    return bad;
}

// One scenario: the code points and the entries of line_breaks, in bytes
// times two plus the flag.
fn ld_expect(label: const u8[:], cps: const i64[:], want: const i64[:]) -> i64 {
    var text: u8[>..] = [];
    var starts: i64[>..] = [];
    ld_encode(text, starts, cps);
    var got: i64[>..] = [];
    let code, off = unicode::line_breaks(got, text[..]);
    if code != unicode::OK || got.len != want.len {
        print("FAIL: ", label, " gave ", code, " and ", got.len, " entries and not ", want.len, ":");
        for k in 0..got.len { print(" ", got[k]); }
        print("\n");
        return 1;
    }
    for k in 0..want.len {
        if got[k] != want[k] {
            print("FAIL: ", label, " gave ", got[k], " at ", k, " and not ", want[k], "\n");
            return 1;
        }
    }
    return 0;
}

// The shapes that the README states, with the entries measured on this
// machine from the ICU line iterator.
fn ld_scenarios() -> i64 {
    var bad: i64 = 0;
    bad += ld_expect("thai two words", [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22], [24, 43]);
    bad += ld_expect("thai one word", [0x0E17, 0x0E35, 0x0E48, 0x0E21, 0x0E32], [31]);
    bad += ld_expect("thai letters with no word", [0x0E2D, 0x0E2D, 0x0E2D, 0x0E2D, 0x0E2D], [12, 31]);
    bad += ld_expect("khmer", [0x1780, 0x17B6, 0x1781, 0x17B6], [12, 25]);
    bad += ld_expect("lao", [0x0EA5, 0x0EB2, 0x0EA7, 0x0EB5], [12, 25]);
    bad += ld_expect("burmese", [0x1000, 0x1005, 0x1015, 0x1001, 0x102D], [6, 12, 18, 31]);
    bad += ld_expect("thai with a space", [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x20, 0x0E44, 0x0E17, 0x0E22], [26, 45]);
    bad += ld_expect("latin around thai", [0x41, 0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22, 0x42], [26, 47]);
    bad += ld_expect("han keeps its rule breaks", [0x4E2D, 0x6587, 0x6D4B, 0x8BD5], [6, 12, 18, 25]);
    bad += ld_expect("full stop between thai words", [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x2E, 0x0E44, 0x0E17, 0x0E22], [45]);
    // One SA letter gives the end entry only.
    bad += ld_expect("one thai letter", [0x0E20], [7]);
    // A script of the class SA with no word list.
    bad += ld_expect("tai tham alone", [0x1A20, 0x1A21, 0x1A22, 0x1A23], [25]);
    bad += ld_expect("tai tham before thai",
        [0x1A20, 0x1A21, 0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22], [36, 55]);
    // A line feed inside a run ends the rule segment.
    bad += ld_expect("line feed inside a run",
        [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E0A, 0x0E44, 0x0E17, 0x0E22, 0x0A, 0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22],
        [24, 30, 51, 74, 93]);
    if bad == 0 { print("line dict scenarios ok\n"); }
    return bad;
}

// The faults and the hostile texts.
fn ld_faults() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    // A bad byte after a Thai run: the fault names the offset and clears
    // the buffer.
    var s: u8[>..] = [];
    for k in 0..3 { unicode::utf8_encode(s, 0x0E20); }
    s.push(0xFF);
    out.push(1);
    let code, off = unicode::line_breaks(out, s[..]);
    if code != unicode::ERR_BAD_UTF8 || off != 9 || out.len != 0 {
        print("FAIL: line dict bad byte gave ", code, " at ", off, " with ", out.len, " entries\n");
        bad += 1;
    }
    // A text above the bound.
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x20); }
    out.push(1);
    let code2, off2 = unicode::line_breaks(out, big[..]);
    if code2 != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: line dict too long gave ", code2, " with ", out.len, " entries\n");
        bad += 1;
    }
    // One mebibyte of one Thai letter.
    var thai: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT / 3 { thai.push(0xE0); thai.push(0xB8); thai.push(0xA0); }
    let t0 = clock_ns();
    let code3, off3 = unicode::line_breaks(out, thai[..]);
    let t1 = clock_ns();
    if code3 != unicode::OK { print("FAIL: line dict hostile letter gave ", code3, "\n"); bad += 1; }
    if (t1 - t0) / 1000000 > 5000 {
        print("FAIL: line dict hostile letter took ", (t1 - t0) / 1000000, " ms\n");
        bad += 1;
    }
    for k in 0..out.len {
        if (out[k] >> 1) % 3 != 0 {
            print("FAIL: line dict hostile letter break at ", out[k] >> 1, "\n");
            bad += 1;
            break;
        }
    }
    // One mebibyte of Thai words: the shape with many breaks.
    var words: u8[>..] = [];
    let unit = [0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22];
    while words.len + 21 <= unicode::MAX_INPUT {
        for k in 0..unit.len { unicode::utf8_encode(words, unit[k]); }
    }
    let w0 = clock_ns();
    let code4, off4 = unicode::line_breaks(out, words[..]);
    let w1 = clock_ns();
    if code4 != unicode::OK || (w1 - w0) / 1000000 > 5000 {
        print("FAIL: line dict hostile words gave ", code4, " in ", (w1 - w0) / 1000000, " ms\n");
        bad += 1;
    }
    for k in 0..out.len {
        if (out[k] >> 1) % 3 != 0 {
            print("FAIL: line dict hostile words break at ", out[k] >> 1, "\n");
            bad += 1;
            break;
        }
    }
    if bad == 0 {
        print("line dict faults ok: letter ", (t1 - t0) / 1000000, " ms, words ", (w1 - w0) / 1000000, " ms\n");
    }
    return bad;
}

fn run_line_dict() -> i64 {
    var bad: i64 = 0;
    bad += ld_battery();
    bad += ld_scenarios();
    bad += ld_faults();
    return bad;
}
