// Tests for the model engine of the word and line calls: the breaks of
// ICU 79.1 with the LSTM models for Thai and Burmese, the choice of the
// engine, the limits and the math of the model.
namespace suite;

import std;
import unicode from "../..";
import lstm_cases;

fn ls_ok(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: lstm ", name, "\n"); return 1; }
    return 0;
}

fn ls_near(a: f64, b: f64) -> bool {
    var d = a - b;
    if d < 0.0 { d = -d; }
    return d < 1.0e-6;
}

// The math of the model against known values.
fn ls_math() -> i64 {
    var bad = 0;
    bad += ls_ok(ls_near(unicode::lstm_exp64(1.0), 2.718281828), "exp 1");
    bad += ls_ok(ls_near(unicode::lstm_exp64(-2.0), 0.135335283), "exp -2");
    bad += ls_ok(unicode::lstm_exp64(0.0) == 1.0, "exp 0");
    bad += ls_ok(ls_near(unicode::lstm_tanh(0.5), 0.462117157), "tanh 0.5");
    bad += ls_ok(ls_near(unicode::lstm_tanh(-3.0), -0.995054754), "tanh -3");
    bad += ls_ok(unicode::lstm_tanh(30.0) == 1.0, "tanh big");
    bad += ls_ok(ls_near(unicode::lstm_sigmoid(0.0), 0.5), "sigmoid 0");
    bad += ls_ok(ls_near(unicode::lstm_sigmoid(2.0), 0.880797078), "sigmoid 2");
    bad += ls_ok(ls_near(unicode::lstm_sigmoid(-2.0), 0.119202922), "sigmoid -2");
    return bad;
}

fn ls_bytes(cps: const i64[:]) -> u8[>..] {
    var s: u8[>..] = [];
    unicode::encode_all(s, cps);
    return s;
}

// The kind of a text list: 0 Thai, 1 Burmese. The texts come from the
// generated file.
fn ls_count(kind: i64) -> i64 {
    if kind == 0 { return LSTM_THAI_TXT_OFF.len - 1; }
    return LSTM_BURMESE_TXT_OFF.len - 1;
}

fn ls_text(kind: i64, k: i64) -> i64[>..] {
    if kind == 0 { return ls_part(LSTM_THAI_TXT, LSTM_THAI_TXT_OFF, k); }
    return ls_part(LSTM_BURMESE_TXT, LSTM_BURMESE_TXT_OFF, k);
}

// The part of a list that belongs to the text k.
fn ls_part(vals: const i64[:], off: const i64[:], k: i64) -> i64[>..] {
    var out: i64[>..] = [];
    for j in off[k]..off[k + 1] { out.push(vals[j]); }
    return out;
}

fn ls_want(kind: i64, line: bool, k: i64) -> i64[>..] {
    if kind == 0 {
        if line { return ls_part(LSTM_THAI_LINE, LSTM_THAI_LINE_OFF, k); }
        return ls_part(LSTM_THAI_WORD, LSTM_THAI_WORD_OFF, k);
    }
    if line { return ls_part(LSTM_BURMESE_LINE, LSTM_BURMESE_LINE_OFF, k); }
    return ls_part(LSTM_BURMESE_WORD, LSTM_BURMESE_WORD_OFF, k);
}

// The breaks of the package as code point indexes with the start 0. Every
// code point of the cases is in the BMP, so three bytes make one index.
fn ls_got(cps: const i64[:], line: bool) -> i64[>..] {
    let s = ls_bytes(cps);
    var br: i64[>..] = [];
    if line {
        let code = unicode::line_breaks_with(br, s[..], unicode::LINE_STYLE_NORMAL, unicode::SEG_MODEL);
        if code != unicode::OK { br.clear(); br.push(-1); }
    } else {
        let code = unicode::word_offsets_with(br, s[..], unicode::SEG_MODEL);
        if code != unicode::OK { br.clear(); br.push(-1); }
    }
    var out: i64[>..] = [0];
    for k in 0..br.len {
        var v = br[k];
        if line { v = v >> 1; }
        let idx = v / 3;
        if idx > 0 && idx < cps.len && idx != out[out.len - 1] { out.push(idx); }
    }
    return out;
}

fn ls_same(a: const i64[:], b: const i64[:]) -> bool {
    if a.len != b.len { return false; }
    for k in 0..a.len { if a[k] != b[k] { return false; } }
    return true;
}

fn ls_cases(line: bool, name: const u8[:]) -> i64 {
    var bad = 0;
    for kind in 0..2 {
        for k in 0..ls_count(kind) {
            let t = ls_text(kind, k);
            let want = ls_want(kind, line, k);
            let got = ls_got(t[..], line);
            if !ls_same(got[..], want[..]) {
                bad += 1;
                if bad < 4 { print("FAIL: lstm ", name, " kind ", kind, " text ", k, "\n"); }
            }
        }
    }
    return bad;
}

fn ls_words() -> i64 { return ls_cases(false, "words"); }
fn ls_lines() -> i64 { return ls_cases(true, "lines"); }

// The old calls and the dictionary engine give the same answer, and the
// engine value is checked.
fn ls_engine() -> i64 {
    var bad = 0;
    let t = ls_text(0, 1);
    let s = ls_bytes(t[..]);
    var a: i64[>..] = [];
    var b: i64[>..] = [];
    unicode::word_offsets(a, s[..]);
    unicode::word_offsets_with(b, s[..], unicode::SEG_DICTIONARY);
    bad += ls_ok(ls_same(a[..], b[..]), "default is the dictionary");
    bad += ls_ok(unicode::word_offsets_with(b, s[..], 7) == unicode::ERR_BAD_ARG, "bad engine");
    bad += ls_ok(unicode::word_offsets_with(b, s[..], -1) == unicode::ERR_BAD_ARG, "negative engine");
    return bad;
}

// A text without Thai or Burmese gives no model break. The short runs
// are in the test of the edges.
fn ls_short() -> i64 {
    var bad = 0;
    var br: i64[>..] = [];
    var c: i64[>..] = [];
    let b = ls_bytes([0x61, 0x62, 0x20, 0x63]);
    unicode::word_offsets_with(br, b[..], unicode::SEG_MODEL);
    unicode::word_offsets_with(c, b[..], unicode::SEG_DICTIONARY);
    bad += ls_ok(ls_same(br[..], c[..]), "latin text");
    return bad;
}

// A text above the limit gives a fault and clears the buffer. The other
// limit cases are in the test of the limit.
fn ls_hostile() -> i64 {
    var bad = 0;
    var s: u8[>..] = [];
    var br: i64[>..] = [];
    for k in 0..(unicode::MAX_MODEL_INPUT + 1) { s.push(97); }
    bad += ls_ok(unicode::word_offsets_with(br, s[..], unicode::SEG_MODEL) == unicode::ERR_TOO_LONG, "too long");
    bad += ls_ok(br.len == 0, "too long clears the buffer");
    bad += ls_ok(unicode::line_breaks_with(br, s[..], unicode::LINE_STYLE_NORMAL, unicode::SEG_MODEL) == unicode::ERR_TOO_LONG, "line too long");
    return bad;
}

// A text of the code points of unit, repeated until it holds at least n
// bytes.
fn ls_repeat(unit: const i64[:], n: i64) -> u8[>..] {
    var s: u8[>..] = [];
    while s.len < n { for k in 0..unit.len { unicode::utf8_encode(s, unit[k]); } }
    return s;
}

fn ls_raw_ok(s: const u8[:]) -> bool {
    var br: i64[>..] = [];
    let code = unicode::word_offsets_with(br, s, unicode::SEG_MODEL);
    if code != unicode::OK || br.len == 0 || br[0] != 0 { return false; }
    for k in 1..br.len { if br[k] <= br[k - 1] { return false; } }
    return true;
}

// The class of a cluster is the first largest of four values.
fn ls_class() -> i64 {
    var bad = 0;
    var a: f32[4] = [1.0, 1.0, 0.0, 0.0];
    bad += ls_ok(unicode::lstm_class(a[..]) == 0, "tie of begin and inside");
    var b: f32[4] = [0.0, 2.0, 2.0, 2.0];
    bad += ls_ok(unicode::lstm_class(b[..]) == 1, "tie of three");
    var c: f32[4] = [0.0, 0.0, 0.0, 1.0];
    bad += ls_ok(unicode::lstm_class(c[..]) == 3, "single");
    return bad;
}

// The offsets from the walk calls equal the offsets of the list call.
fn ls_walk() -> i64 {
    var bad = 0;
    for k in 0..6 {
        let t = ls_text(0, k * 7);
        let s = ls_bytes(t[..]);
        var want: i64[>..] = [];
        unicode::word_offsets_with(want, s[..], unicode::SEG_MODEL);
        var ends: i64[>..] = [0];
        var at: i64 = 0;
        while at < s.len {
            let code, end = unicode::word_next_with(s[..], at, unicode::SEG_MODEL);
            if code != unicode::OK { bad += 1; break; }
            ends.push(end);
            at = end;
        }
        var got: i64[>..] = [];
        for j in 0..ends.len - 1 { got.push(ends[j]); }
        bad += ls_ok(ls_same(got[..], want[..]), "walk equals the list");
        var cache: i64[>..] = [];
        var cached: i64[>..] = [];
        at = 0;
        while at < s.len {
            let code, end = unicode::word_next_cached_with(cache, s[..], at, unicode::SEG_MODEL);
            if code != unicode::OK { bad += 1; break; }
            cached.push(at);
            at = end;
        }
        bad += ls_ok(ls_same(cached[..], want[..]), "cached walk equals the list");
        let _, n = unicode::word_count_with(s[..], unicode::SEG_MODEL);
        bad += ls_ok(n == want.len, "count equals the list");
    }
    return bad;
}

// A text of another script gives the same result with both engines.
fn ls_same_engines(s: const u8[:]) -> i64 {
    var bad = 0;
    var a: i64[>..] = [];
    var b: i64[>..] = [];
    unicode::word_offsets_with(a, s, unicode::SEG_DICTIONARY);
    unicode::word_offsets_with(b, s, unicode::SEG_MODEL);
    bad += ls_ok(ls_same(a[..], b[..]), "other script");
    var l1: i64[>..] = [];
    var l2: i64[>..] = [];
    unicode::line_breaks_with(l1, s, unicode::LINE_STYLE_NORMAL, unicode::SEG_DICTIONARY);
    unicode::line_breaks_with(l2, s, unicode::LINE_STYLE_NORMAL, unicode::SEG_MODEL);
    bad += ls_ok(ls_same(l1[..], l2[..]), "other script line");
    return bad;
}

// Lao, Khmer, Chinese and Japanese texts give the same result with both
// engines.
fn ls_other() -> i64 {
    var bad = 0;
    let lao = ls_bytes([0xE81, 0xEB2, 0xE99, 0xEAD, 0xEB2, 0xE8D, 0xEBB, 0xE94, 0xEAA, 0xEB0, 0xE9A]);
    let khmer = ls_bytes([0x1780, 0x17B6, 0x179A, 0x1794, 0x17D2, 0x179A, 0x17BE, 0x1790]);
    let han = ls_bytes([0x4E2D, 0x6587, 0x5206, 0x8BCD, 0x6D4B, 0x8BD5]);
    let kana = ls_bytes([0x3053, 0x3093, 0x306B, 0x3061, 0x306F, 0x4E16, 0x754C]);
    bad += ls_same_engines(lao[..]);
    bad += ls_same_engines(khmer[..]);
    bad += ls_same_engines(han[..]);
    bad += ls_same_engines(kana[..]);
    return bad;
}

// A Thai base letter with n marks, then five code points of a word.
fn ls_marked(n: i64) -> u8[>..] {
    var cps: i64[>..] = [0xE04];
    for k in 0..n { cps.push(0xE48); }
    for k in 0..5 { cps.push([0xE04, 0xE32, 0xE23, 0xE2D, 0xE07][k]); }
    return ls_bytes(cps[..]);
}

// The short runs and the clusters at the limit.
fn ls_edges() -> i64 {
    var bad = 0;
    var br: i64[>..] = [];
    for n in 3..7 {
        var cps: i64[>..] = [];
        for k in 0..n { cps.push([0xE04, 0xE32, 0xE23, 0xE2D, 0xE07, 0xE19][k]); }
        let s = ls_bytes(cps[..]);
        unicode::word_offsets_with(br, s[..], unicode::SEG_MODEL);
        if n < 5 { bad += ls_ok(br.len == 1, "short run has no model break"); }
        bad += ls_ok(ls_raw_ok(s[..]), "offsets rise");
    }
    // A cluster of 10 units and of 11 units: the base letter with marks.
    let s10 = ls_marked(9);
    let s11 = ls_marked(10);
    var d11: i64[>..] = [];
    unicode::word_offsets_with(br, s10[..], unicode::SEG_MODEL);
    unicode::word_offsets_with(d11, s11[..], unicode::SEG_MODEL);
    bad += ls_ok(br.len >= 1, "cluster of 10 units");
    bad += ls_ok(d11.len == 1, "cluster of 11 units stops the model");
    return bad;
}

// A text of 65,536 bytes of each script ends in time and in order.
fn ls_big() -> i64 {
    var bad = 0;
    let thai = ls_repeat([0xE04, 0xE32, 0xE23, 0xE2D, 0xE07, 0xE19, 0xE49, 0xE33], 65000);
    let burmese = ls_repeat([0x1019, 0x103C, 0x1014, 0x103A, 0x1019, 0x102C], 65000);
    var mix: u8[>..] = [];
    while mix.len < 65000 {
        let part = ls_bytes([0xE04, 0xE32, 0xE23, 0xE2D, 0x20, 0x1019, 0x103C, 0x1014, 0x103A, 0x1019, 0x20]);
        for k in 0..part.len { mix.push(part[k]); }
    }
    bad += ls_ok(ls_raw_ok(thai[..]), "big Thai");
    bad += ls_ok(ls_raw_ok(burmese[..]), "big Burmese");
    bad += ls_ok(ls_raw_ok(mix[..]), "big mix");
    return bad;
}

// Every call refuses a text above the limit.
fn ls_limit() -> i64 {
    var bad = 0;
    let s = ls_repeat([0xE04, 0xE32, 0xE23], unicode::MAX_MODEL_INPUT + 1);
    var br: i64[>..] = [];
    let c1, _ = unicode::word_next_with(s[..], 0, unicode::SEG_MODEL);
    bad += ls_ok(c1 == unicode::ERR_TOO_LONG, "next over the limit");
    let c2, _ = unicode::word_count_with(s[..], unicode::SEG_MODEL);
    bad += ls_ok(c2 == unicode::ERR_TOO_LONG, "count over the limit");
    bad += ls_ok(unicode::word_offsets_with(br, s[..], unicode::SEG_MODEL) == unicode::ERR_TOO_LONG, "offsets over the limit");
    var cache: i64[>..] = [];
    let c4, _ = unicode::word_next_cached_with(cache, s[..], 0, unicode::SEG_MODEL);
    bad += ls_ok(c4 == unicode::ERR_TOO_LONG, "cached over the limit");
    let c5, _ = unicode::line_breaks_with(br, s[..], unicode::LINE_STYLE_NORMAL, unicode::SEG_MODEL);
    bad += ls_ok(c5 == unicode::ERR_TOO_LONG, "line over the limit");
    let c6, _ = unicode::line_breaks_style(br, s[..], unicode::LINE_STYLE_NORMAL, unicode::SEG_MODEL);
    bad += ls_ok(c6 == unicode::ERR_TOO_LONG, "style over the limit");
    return bad;
}

// The decoder of a model refuses bad data, and the float helper is exact.
fn ls_data() -> i64 {
    var bad = 0;
    bad += ls_ok(unicode::lstm_f32(0x3F800000) == 1.0, "f32 one");
    bad += ls_ok(unicode::lstm_f32(0xC0000000) == -2.0, "f32 minus two");
    bad += ls_ok(unicode::lstm_f32(0x3F000000) == 0.5, "f32 half");
    bad += ls_ok(unicode::lstm_f32(0) == 0.0, "f32 zero");
    var junk: u8[>..] = [];
    for k in 0..11 { junk.push(0); }
    bad += ls_ok(!unicode::lstm_decode(junk[..], 0), "short data");
    for k in 0..40 { junk.push(0); }
    bad += ls_ok(!unicode::lstm_decode(junk[..], 0), "zero header");
    junk.clear();
    for k in 0..12 { junk.push(0); }
    junk[0] = 16; junk[4] = 23; junk[8] = 1;
    bad += ls_ok(!unicode::lstm_decode(junk[..], 0), "no strings");
    return bad;
}

fn run_lstm() -> i64 {
    var bad = 0;
    if want("lstm", "ls_math") { bad += ls_math(); }
    if want("lstm", "ls_words") { bad += ls_words(); }
    if want("lstm", "ls_lines") { bad += ls_lines(); }
    if want("lstm", "ls_engine") { bad += ls_engine(); }
    if want("lstm", "ls_short") { bad += ls_short(); }
    if want("lstm", "ls_hostile") { bad += ls_hostile(); }
    if want("lstm", "ls_class") { bad += ls_class(); }
    if want("lstm", "ls_walk") { bad += ls_walk(); }
    if want("lstm", "ls_other") { bad += ls_other(); }
    if want("lstm", "ls_edges") { bad += ls_edges(); }
    if want("lstm", "ls_big") { bad += ls_big(); }
    if want("lstm", "ls_limit") { bad += ls_limit(); }
    if want("lstm", "ls_data") { bad += ls_data(); }
    return bad;
}
