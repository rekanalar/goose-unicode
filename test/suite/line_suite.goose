// Tests for the line break calls.
namespace suite;

import std;
import unicode from "../..";

fn ln_offsets(s: const u8[:]) -> i64[>..] {
    var out: i64[>..] = [];
    let code, off = unicode::line_breaks(out, s);
    if code != unicode::OK { out.clear(); out.push(-1); }
    return out;
}

fn ln_check(s: const u8[:], want: const i64[:], name: const u8[:]) -> i64 {
    let got = ln_offsets(s);
    if got[..] != want {
        print("FAIL: line ", name, ", got ", got, "\n");
        return 1;
    }
    return 0;
}

// Every case of the conformance file of the standard.
fn line_conformance() -> i64 {
    var bad = 0;
    let cases = LT_OFF.len - 1;
    for t in 0..cases {
        let lo = LT_OFF[t];
        let hi = LT_OFF[t + 1];
        var text: u8[>..] = [];
        var at: i64[>..] = [];       // the byte offset of each boundary, by code point index
        at.push(0);
        for j in lo..hi {
            push_utf8_cp(text, LT_CP[j]);
            at.push(text.len);
        }
        var want: i64[>..] = [];
        for b in LT_BRK_OFF[t]..LT_BRK_OFF[t + 1] {
            let idx = LT_BRK[b];
            let cls = unicode::line_break_class(LT_CP[lo + idx - 1]);
            var kind: i64 = 0;
            if idx == hi - lo || cls == unicode::LB_BK || cls == unicode::LB_LF || cls == unicode::LB_NL
                || cls == unicode::LB_CR { kind = 1; }
            want.push(at[idx] * 2 + kind);
        }
        if hi == lo { continue; }
        let got = ln_offsets(text[..]);
        if got[..] != want[..] {
            bad += 1;
            if bad <= 5 { print("FAIL: line case ", t, ", got ", got, ", want ", want, "\n"); }
        }
    }
    return bad;
}

fn push_utf8_cp(out: u8[>..]&, cp: i64) {
    unicode::utf8_encode(out, cp);
}

fn line_samples() -> i64 {
    var bad = 0;
    bad += ln_check("", [], "empty");
    bad += ln_check("a b", [4, 7], "space");
    bad += ln_check("a\nb", [5, 7], "line feed");
    bad += ln_check("a\r\nb", [7, 9], "carriage return and line feed");
    bad += ln_check("a\rb", [5, 7], "carriage return");
    bad += ln_check("a  b", [6, 9], "two spaces");
    bad += ln_check("ab", [5], "one word");
    bad += ln_check("中文", [6, 13], "ideographs");
    bad += ln_check("a\xE2\x80\x8Bb", [8, 11], "zero width space");
    var cls: i64 = unicode::line_break_class(0x20);
    if cls != unicode::LB_SP { print("FAIL: class of a space\n"); bad += 1; }
    if unicode::line_break_class(0x41) != unicode::LB_AL { print("FAIL: class of A\n"); bad += 1; }
    if unicode::line_break_class(0xE01) != unicode::LB_SA { print("FAIL: class of a Thai letter\n"); bad += 1; }
    if unicode::line_break_class(0x4E2D) != unicode::LB_ID { print("FAIL: class of an ideograph\n"); bad += 1; }
    if unicode::line_break_class(-1) != unicode::LB_XX || unicode::line_break_class(0x110000) != unicode::LB_XX {
        print("FAIL: class outside the range\n");
        bad += 1;
    }
    return bad;
}

fn line_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [1, 2, 3];
    let code, off = unicode::line_breaks(out, "a\xFFb");
    if code != unicode::ERR_BAD_UTF8 || off != 1 || out.len != 0 { print("FAIL: line bad byte\n"); bad += 1; }
    var long: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { long.push(0x61); }
    out = [1];
    let c2, o2 = unicode::line_breaks(out, long[..]);
    if c2 != unicode::ERR_TOO_LONG || out.len != 0 { print("FAIL: line long text\n"); bad += 1; }
    return bad;
}

// Texts of the largest size that stress each state of the pass.
fn line_hostile() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    let unit: i64[8] = [0x20, 0x301, 0x1F1E6, 0x22, 0x31, 0x2C, 0x28, 0x61];
    for u in 0..8 {
        var t: u8[>..] = [];
        let w = if unit[u] < 0x80 { 1 } else if unit[u] < 0x800 { 2 } else { 4 };
        for i in 0..unicode::MAX_INPUT / w { unicode::utf8_encode(t, unit[u]); }
        let code, off = unicode::line_breaks(out, t[..]);
        if code != unicode::OK || out.len < 1 { print("FAIL: line hostile ", u, "\n"); bad += 1; }
    }
    var ab: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT / 2 { ab.push(0x61); ab.push(0x20); }
    let c3, o3 = unicode::line_breaks(out, ab[..]);
    if c3 != unicode::OK || out.len != unicode::MAX_INPUT / 2 { print("FAIL: line many breaks\n"); bad += 1; }
    return bad;
}

fn run_line() -> i64 {
    var bad = 0;
    if want("line", "line_samples") { bad += line_samples(); }
    if want("line", "line_faults") { bad += line_faults(); }
    if want("line", "line_hostile") { bad += line_hostile(); }
    if want("line", "line_conformance") { bad += line_conformance(); }
    return bad;
}
