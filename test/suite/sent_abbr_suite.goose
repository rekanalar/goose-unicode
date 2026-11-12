// The tests of the sentence abbreviations and the line styles. The cases
// replay the breaks of the ICU library, release 79.1. The scenario cases
// pin the shapes that the README states. The fault cases pin the faults
// of the new calls.
namespace suite;

import std;
import unicode from "../..";
import sent_abbr_cases;
import line_style_cases;

// The value at index i of the pool. Each value takes three bytes, low
// byte first.
fn sa_val(pool: const u8[:], i: i64) -> i64 {
    let a = pool[3 * i] as i64;
    let b = pool[3 * i + 1] as i64;
    let c = pool[3 * i + 2] as i64;
    return a | (b << 8) | (c << 16);
}

// Encodes the code points and gives the byte offset of each code point.
// The last entry is the length of the text.
fn sa_encode(out: u8[>..]&, starts: i64[>..]&, cps: const i64[:]) {
    out.clear();
    starts.clear();
    for k in 0..cps.len {
        starts.push(out.len);
        unicode::utf8_encode(out, cps[k]);
    }
    starts.push(out.len);
}

// Replays the cases of the sentence abbreviations. The starts of the
// sentences are the offsets of the code points.
fn sa_battery() -> i64 {
    var bad: i64 = 0;
    var pos: i64 = 0;
    var text: u8[>..] = [];
    var starts: i64[>..] = [];
    for c in 0..SENT_CASES_COUNT[0] {
        let locale = sa_val(SENT_CASES_POOL, pos);
        let n = sa_val(SENT_CASES_POOL, pos + 1);
        var cps: i64[>..] = [];
        for k in 0..n { cps.push(sa_val(SENT_CASES_POOL, pos + 2 + k)); }
        let m = sa_val(SENT_CASES_POOL, pos + 2 + n);
        var want: i64[>..] = [];
        for k in 0..m { want.push(sa_val(SENT_CASES_POOL, pos + 3 + n + k)); }
        pos += 3 + n + m;
        sa_encode(text, starts, cps[..]);
        var got: i64[>..] = [];
        let code = unicode::sentence_offsets_locale(got, text[..], locale);
        if code != unicode::OK {
            print("FAIL: sentence case ", c, " gave the fault ", code, "\n");
            bad += 1;
            continue;
        }
        if got.len != want.len {
            print("FAIL: sentence case ", c, " gave ", got.len, " starts and not ", want.len, "\n");
            bad += 1;
            continue;
        }
        for k in 0..want.len {
            let w = starts[want[k]];
            if got[k] != w {
                print("FAIL: sentence case ", c, " gave the start ", got[k],
                    " and not ", w, "\n");
                bad += 1;
                break;
            }
        }
        if bad > 20 { break; }
    }
    if bad == 0 { print("sentence battery: ", SENT_CASES_COUNT[0], " cases ok\n"); }
    return bad;
}

// Replays the cases of the line styles. The breaks of the three styles
// are the offsets of the code points.
fn sa_line_battery() -> i64 {
    var bad: i64 = 0;
    var pos: i64 = 0;
    var text: u8[>..] = [];
    var starts: i64[>..] = [];
    for c in 0..LINE_STYLE_CASES_COUNT[0] {
        let n = sa_val(LINE_STYLE_CASES_POOL, pos);
        var cps: i64[>..] = [];
        for k in 0..n { cps.push(sa_val(LINE_STYLE_CASES_POOL, pos + 1 + k)); }
        var at = pos + 1 + n;
        var want0: i64[>..] = [];
        var want1: i64[>..] = [];
        var want2: i64[>..] = [];
        let m0 = sa_val(LINE_STYLE_CASES_POOL, at);
        for k in 0..m0 { want0.push(sa_val(LINE_STYLE_CASES_POOL, at + 1 + k)); }
        at += 1 + m0;
        let m1 = sa_val(LINE_STYLE_CASES_POOL, at);
        for k in 0..m1 { want1.push(sa_val(LINE_STYLE_CASES_POOL, at + 1 + k)); }
        at += 1 + m1;
        let m2 = sa_val(LINE_STYLE_CASES_POOL, at);
        for k in 0..m2 { want2.push(sa_val(LINE_STYLE_CASES_POOL, at + 1 + k)); }
        at += 1 + m2;
        pos = at;
        sa_encode(text, starts, cps[..]);
        for style in 0..3 {
            var got: i64[>..] = [];
            let code, _ = unicode::line_breaks_style(got, text[..], style);
            if code != unicode::OK {
                print("FAIL: line style case ", c, " gave the fault ", code, "\n");
                bad += 1;
                break;
            }
            var count = want0.len;
            if style == 1 { count = want1.len; }
            if style == 2 { count = want2.len; }
            if got.len != count {
                print("FAIL: line style case ", c, " style ", style, " gave ",
                    got.len, " breaks and not ", count, "\n");
                bad += 1;
                break;
            }
            for k in 0..count {
                var w: i64 = 0;
                if style == 0 { w = starts[want0[k]]; }
                if style == 1 { w = starts[want1[k]]; }
                if style == 2 { w = starts[want2[k]]; }
                if got[k] >> 1 != w {
                    print("FAIL: line style case ", c, " style ", style, " gave the break ",
                        got[k] >> 1, " and not ", w, "\n");
                    bad += 1;
                    break;
                }
            }
            if bad > 20 { break; }
        }
        if bad > 20 { break; }
    }
    if bad == 0 { print("line style battery: ", LINE_STYLE_CASES_COUNT[0], " cases ok\n"); }
    return bad;
}

// The texts of the scenarios of the spec.
fn sa_sent_expect(label: const u8[:], text: const u8[:], locale: i64,
        want: const i64[:]) -> i64 {
    var got: i64[>..] = [];
    let code = unicode::sentence_offsets_locale(got, text, locale);
    if code != unicode::OK || got.len != want.len {
        print("FAIL: ", label, " gave the fault ", code, " and ", got.len,
            " starts and not ", want.len, "\n");
        return 1;
    }
    for k in 0..want.len {
        if got[k] != want[k] {
            print("FAIL: ", label, " gave the start ", got[k], " and not ", want[k], "\n");
            return 1;
        }
    }
    return 0;
}

// The code points of one text, as bytes.
fn sa_text(cps: const i64[:]) -> u8[>..] {
    var out: u8[>..] = [];
    unicode::encode_all(out, cps);
    return out;
}

// The shapes of the sentences that the README states.
fn sa_scenarios() -> i64 {
    var bad: i64 = 0;
    bad += sa_sent_expect("mr smith en",
        sa_text([0x4D, 0x72, 0x2E, 0x20, 0x53, 0x6D, 0x69, 0x74, 0x68, 0x20, 0x77,
                 0x65, 0x6E, 0x74, 0x20, 0x68, 0x6F, 0x6D, 0x65, 0x2E, 0x20, 0x44,
                 0x72, 0x2E, 0x20, 0x4A, 0x6F, 0x6E, 0x65, 0x73, 0x20, 0x73, 0x74,
                 0x61, 0x79, 0x65, 0x64, 0x2E]),
        unicode::SENT_LOCALE_EN, [0, 21, 25]);
    bad += sa_sent_expect("mr smith root",
        sa_text([0x4D, 0x72, 0x2E, 0x20, 0x53, 0x6D, 0x69, 0x74, 0x68, 0x20, 0x77,
                 0x65, 0x6E, 0x74, 0x20, 0x68, 0x6F, 0x6D, 0x65, 0x2E, 0x20, 0x44,
                 0x72, 0x2E, 0x20, 0x4A, 0x6F, 0x6E, 0x65, 0x73, 0x20, 0x73, 0x74,
                 0x61, 0x79, 0x65, 0x64, 0x2E]),
        unicode::SENT_LOCALE_ROOT, [0, 4, 21, 25]);
    bad += sa_sent_expect("phd",
        sa_text([0x50, 0x68, 0x2E, 0x44, 0x2E, 0x20, 0x61, 0x6E, 0x64, 0x20,
                 0x4D, 0x2E, 0x53, 0x63, 0x2E, 0x20, 0x64, 0x65, 0x67, 0x72, 0x65,
                 0x65, 0x73, 0x2E, 0x20, 0x4E, 0x6F, 0x2E, 0x20, 0x35, 0x20, 0x61,
                 0x6E, 0x64, 0x20, 0x56, 0x6F, 0x6C, 0x2E, 0x20, 0x32, 0x2E]),
        unicode::SENT_LOCALE_EN, [0, 25, 40]);
    bad += sa_sent_expect("prof",
        sa_text([0x50, 0x72, 0x6F, 0x66, 0x2E, 0x20, 0x41, 0x2E, 0x20, 0x42, 0x2E,
                 0x20, 0x43, 0x2E, 0x20, 0x53, 0x6D, 0x69, 0x74, 0x68, 0x20, 0x65,
                 0x74, 0x20, 0x61, 0x6C, 0x2E, 0x20, 0x77, 0x72, 0x6F, 0x74, 0x65,
                 0x20, 0x69, 0x74, 0x2E]),
        unicode::SENT_LOCALE_EN, [0, 9, 12, 15]);
    bad += sa_sent_expect("vol",
        sa_text([0x56, 0x6F, 0x6C, 0x2E, 0x20, 0x32, 0x2E, 0x20, 0x4E, 0x6F, 0x2E,
                 0x20, 0x35, 0x20, 0x61, 0x6E, 0x64, 0x20, 0x4D, 0x72, 0x2E, 0x20,
                 0x53, 0x6D, 0x69, 0x74, 0x68, 0x20, 0x77, 0x65, 0x6E, 0x74, 0x20,
                 0x68, 0x6F, 0x6D, 0x65, 0x2E]),
        unicode::SENT_LOCALE_EN, [0, 5, 8]);
    // The locale of a language tag.
    if unicode::sentence_locale_of("en") != unicode::SENT_LOCALE_EN
        || unicode::sentence_locale_of("EN") != unicode::SENT_LOCALE_EN
        || unicode::sentence_locale_of("de-DE") != unicode::SENT_LOCALE_DE
        || unicode::sentence_locale_of("de_DE") != unicode::SENT_LOCALE_DE
        || unicode::sentence_locale_of("ru") != unicode::SENT_LOCALE_RU
        || unicode::sentence_locale_of("ja") != unicode::SENT_LOCALE_ROOT
        || unicode::sentence_locale_of("e") != unicode::SENT_LOCALE_ROOT
        || unicode::sentence_locale_of("engl") != unicode::SENT_LOCALE_ROOT
        || unicode::sentence_locale_of("en1") != unicode::SENT_LOCALE_ROOT {
        print("FAIL: the locale of a tag is wrong\n");
        bad += 1;
    }
    if bad == 0 { print("sentence scenarios ok\n"); }
    return bad;
}

// The styles of the lines that the README states.
fn sa_line_expect(label: const u8[:], cps: const i64[:], style: i64,
        want: const i64[:]) -> i64 {
    let text = sa_text(cps);
    var got: i64[>..] = [];
    let code, _ = unicode::line_breaks_style(got, text[..], style);
    if code != unicode::OK || got.len != want.len {
        print("FAIL: ", label, " gave the fault ", code, " and ", got.len,
            " breaks and not ", want.len, "\n");
        return 1;
    }
    for k in 0..want.len {
        if got[k] != want[k] {
            print("FAIL: ", label, " gave the break ", got[k], " and not ", want[k], "\n");
            return 1;
        }
    }
    return 0;
}

// The shapes of the lines that the README states.
fn sa_line_scenarios() -> i64 {
    var bad: i64 = 0;
    // The text of the spec: ten code points.
    let jp = [0x65E5, 0x672C, 0x8A9E, 0x309D, 0x30C6, 0x30B9, 0x30C8, 0x30FC,
        0x3067, 0x3059];
    bad += sa_line_expect("japanese strict", jp, unicode::LINE_STYLE_STRICT,
        [6, 12, 24, 30, 36, 48, 54, 61]);
    bad += sa_line_expect("japanese normal", jp, unicode::LINE_STYLE_NORMAL,
        [6, 12, 24, 30, 36, 42, 48, 54, 61]);
    bad += sa_line_expect("japanese loose", jp, unicode::LINE_STYLE_LOOSE,
        [6, 12, 18, 24, 30, 36, 42, 48, 54, 61]);
    // The marks of the spec.
    let marks = [0x30FD, 0x30FE, 0x30FC, 0x3005, 0x303B];
    bad += sa_line_expect("marks loose", marks, unicode::LINE_STYLE_LOOSE,
        [6, 12, 18, 24, 31]);
    bad += sa_line_expect("marks normal", marks, unicode::LINE_STYLE_NORMAL,
        [12, 31]);
    bad += sa_line_expect("marks strict", marks, unicode::LINE_STYLE_STRICT,
        [31]);
    if bad == 0 { print("line style scenarios ok\n"); }
    return bad;
}

// The faults and the hostile texts.
fn sa_faults() -> i64 {
    var bad: i64 = 0;
    var out: i64[>..] = [];
    // A text above the bound.
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x20); }
    let code = unicode::sentence_offsets_locale(out, big[..], unicode::SENT_LOCALE_EN);
    if code != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: the sentence locale call gave ", code, " with ", out.len, " starts\n");
        bad += 1;
    }
    let code2, _ = unicode::line_breaks_style(out, big[..], unicode::LINE_STYLE_LOOSE);
    if code2 != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: the line style call gave ", code2, " with ", out.len, " breaks\n");
        bad += 1;
    }
    // A bad byte after "ab ": the line call names its offset and clears
    // the buffer. The sentence call keeps the plain call: the bad byte
    // is a segment of its own and the call gives the same starts.
    let badtext = [0x61, 0x62, 0x20, 0xFF, 0x63];
    var bt: u8[>..] = [];
    for k in 0..badtext.len { bt.push(badtext[k] as u8); }
    out.push(7);
    let code5, off5 = unicode::line_breaks_style(out, bt[..], unicode::LINE_STYLE_LOOSE);
    if code5 != unicode::ERR_BAD_UTF8 || off5 != 3 || out.len != 0 {
        print("FAIL: the line style call on a bad byte gave ", code5, " at ", off5,
            " with ", out.len, " breaks\n");
        bad += 1;
    }
    var plain: i64[>..] = [];
    let code6 = unicode::sentence_offsets(plain, bt[..]);
    let code7 = unicode::sentence_offsets_locale(out, bt[..], unicode::SENT_LOCALE_EN);
    var same = code6 == code7 && plain.len == out.len;
    if same { for k in 0..plain.len { if plain[k] != out[k] { same = false; } } }
    if !same {
        print("FAIL: the sentence locale call differs from the plain call on a bad byte\n");
        bad += 1;
    }
    // One mebibyte of English text with many abbreviations.
    var text: u8[>..] = [];
    let unit = [0x4D, 0x72, 0x2E, 0x20, 0x53, 0x6D, 0x69, 0x74, 0x68, 0x20,
        0x77, 0x65, 0x6E, 0x74, 0x20, 0x68, 0x6F, 0x6D, 0x65, 0x2E, 0x20];
    while text.len + unit.len <= unicode::MAX_INPUT {
        for k in 0..unit.len { text.push(unit[k] as u8); }
    }
    let t0 = clock_ns();
    let code3 = unicode::sentence_offsets_locale(out, text[..], unicode::SENT_LOCALE_EN);
    let t1 = clock_ns();
    if code3 != unicode::OK {
        print("FAIL: the hostile sentence text gave the fault ", code3, "\n");
        bad += 1;
    }
    if (t1 - t0) / 1000000 > 5000 {
        print("FAIL: the hostile sentence text took ", (t1 - t0) / 1000000, " ms\n");
        bad += 1;
    }
    // One mebibyte with the six marks.
    var marks: u8[>..] = [];
    while marks.len + 4 <= unicode::MAX_INPUT {
        marks.push(0xE3);
        marks.push(0x80);
        marks.push(0x85);
        marks.push(0x41);
    }
    let t2 = clock_ns();
    let code4, _ = unicode::line_breaks_style(out, marks[..], unicode::LINE_STYLE_LOOSE);
    let t3 = clock_ns();
    if code4 != unicode::OK {
        print("FAIL: the hostile mark text gave the fault ", code4, "\n");
        bad += 1;
    }
    if (t3 - t2) / 1000000 > 5000 {
        print("FAIL: the hostile mark text took ", (t3 - t2) / 1000000, " ms\n");
        bad += 1;
    }
    if bad == 0 {
        print("sentence and line faults ok: sentences ", (t1 - t0) / 1000000,
            " ms, marks ", (t3 - t2) / 1000000, " ms\n");
    }
    return bad;
}

fn run_sent_abbr() -> i64 {
    var bad: i64 = 0;
    bad += sa_battery();
    bad += sa_line_battery();
    bad += sa_scenarios();
    bad += sa_line_scenarios();
    bad += sa_faults();
    return bad;
}
