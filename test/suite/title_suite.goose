// Tests for the title case calls.
namespace suite;

import std;
import unicode from "../..";

// The title case of the text, or the fault code as text.
fn tt_of(text: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    let code, off = unicode::to_title(out, text);
    if code != unicode::OK { out.clear(); out.push(63); }
    return out;
}

fn tt_check(text: const u8[:], want: const u8[:], name: const u8[:]) -> i64 {
    let got = tt_of(text);
    if got[..] != want {
        print("FAIL: title ", name, ", got ", got, "\n");
        return 1;
    }
    return 0;
}

fn title_samples() -> i64 {
    var bad = 0;
    bad += tt_check("hello world", "Hello World", "words");
    bad += tt_check("don't stop", "Don't Stop", "apostrophe");
    bad += tt_check("STRASSE", "Strasse", "upper case");
    bad += tt_check("straße", "Straße", "sharp s inside");
    bad += tt_check("ßa", "Ssa", "sharp s first");
    bad += tt_check("ǆ ǳ", "ǅ ǲ", "digraphs");
    bad += tt_check("ǅ", "ǅ", "title digraph");
    bad += tt_check("ﬁ sh", "Fi Sh", "ligature");
    bad += tt_check("ΟΟΣ ΟΣ", "Οος Ος", "final sigma");
    bad += tt_check("1st", "1St", "digit first");
    bad += tt_check("e.g. the", "E.g. The", "full stop");
    bad += tt_check("", "", "empty");
    bad += tt_check("   ", "   ", "spaces");
    bad += tt_check("中文 abc", "中文 Abc", "ideographs");
    return bad;
}

// The title case mapping of every code point, against the table of the
// Rust crate and the Go library, which agree with the tables.
fn title_every_cp() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var want: u8[>..] = [];
    var k: i64 = 0;
    for cp in 0..0x110000 {
        if cp >= 0xD800 && cp <= 0xDFFF { continue; }
        want.clear();
        if k < TC_CP.len && TC_CP[k] == cp {
            for j in TC_OFF[k]..TC_OFF[k + 1] { unicode::utf8_encode(want, TC_POOL[j]); }
            k += 1;
        } else {
            unicode::utf8_encode(want, cp);
        }
        let code = unicode::titlecase_cp(out, cp);
        if code != unicode::OK || out != want[..] {
            print("FAIL: the title case of U+", cp, " differs\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    if k != TC_CP.len {
        print("FAIL: the table holds code points that the walk missed\n");
        bad += 1;
    }
    return bad;
}

fn title_bad_cp() -> i64 {
    var bad = 0;
    var out: u8[>..] = [0x41];
    if unicode::titlecase_cp(out, 0xD800) != unicode::ERR_BAD_CODEPOINT || out.len != 0 {
        print("FAIL: title of a surrogate\n");
        bad += 1;
    }
    out.push(0x41);
    if unicode::titlecase_cp(out, 0x110000) != unicode::ERR_BAD_CODEPOINT || out.len != 0 {
        print("FAIL: title of a value above U+10FFFF\n");
        bad += 1;
    }
    out.push(0x41);
    if unicode::titlecase_cp(out, -1) != unicode::ERR_BAD_CODEPOINT || out.len != 0 {
        print("FAIL: title of a negative value\n");
        bad += 1;
    }
    return bad;
}

// The texts of the Go library, in the generated set.
fn title_texts() -> i64 {
    var bad = 0;
    for k in 0..TT_IN_OFF.len - 1 {
        var inb: u8[>..] = [];
        var wantb: u8[>..] = [];
        for j in TT_IN_OFF[k]..TT_IN_OFF[k + 1] { unicode::utf8_encode(inb, TT_IN_POOL[j]); }
        for j in TT_OUT_OFF[k]..TT_OUT_OFF[k + 1] { unicode::utf8_encode(wantb, TT_OUT_POOL[j]); }
        let got = tt_of(inb[..]);
        if got[..] != wantb[..] {
            print("FAIL: title of text ", k, " differs: ", got, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

fn title_faults() -> i64 {
    var bad = 0;
    var out: u8[>..] = [0x41];
    let code, off = unicode::to_title(out, "abc\xffdef");
    if code != unicode::ERR_BAD_UTF8 || off != 3 || out.len != 0 {
        print("FAIL: title bad byte ", code, " ", off, "\n");
        bad += 1;
    }
    out.push(0x41);
    let c2, o2 = unicode::to_title(out, "ab\xE0\x80");
    if c2 != unicode::ERR_BAD_UTF8 || o2 != 2 || out.len != 0 {
        print("FAIL: title cut sequence\n");
        bad += 1;
    }
    var long: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { long.push(0x61); }
    out.push(0x41);
    let c3, o3 = unicode::to_title(out, long[..]);
    if c3 != unicode::ERR_TOO_LONG || o3 != -1 || out.len != 0 {
        print("FAIL: title input bound\n");
        bad += 1;
    }
    return bad;
}

// Hostile texts of the largest size. Each call runs in one pass.
fn title_hostile() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var one: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { one.push(0x61); }
    let c1, o1 = unicode::to_title(out, one[..]);
    if c1 != unicode::OK || out.len != unicode::MAX_INPUT || out[0] != 0x41 || out[1] != 0x61 {
        print("FAIL: title of one long word\n");
        bad += 1;
    }
    // The longest growth: U+0390 gives three code points of two bytes.
    var grow: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT / 2 { unicode::utf8_encode(grow, 0x390); }
    let c2, o2 = unicode::to_title(out, grow[..]);
    if c2 != unicode::OK || out.len > unicode::MAX_OUTPUT {
        print("FAIL: title of the longest growth\n");
        bad += 1;
    }
    // A sigma after a long run of case ignorable marks reads back over the run once.
    var marks: u8[>..] = [0x61];
    for i in 0..unicode::MAX_INPUT / 4 { unicode::utf8_encode(marks, 0x301); }
    unicode::utf8_encode(marks, 0x3A3);
    let c3, o3 = unicode::to_title(out, marks[..]);
    if c3 != unicode::OK {
        print("FAIL: title of a sigma after marks\n");
        bad += 1;
    }
    // Many short words.
    var words: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT / 3 { words.push(0x61); words.push(0x62); words.push(0x20); }
    let c4, o4 = unicode::to_title(out, words[..]);
    if c4 != unicode::OK || out.len != words.len || out[0] != 0x41 || out[3] != 0x41 {
        print("FAIL: title of many words\n");
        bad += 1;
    }
    return bad;
}

fn run_title() -> i64 {
    var bad = 0;
    bad += title_samples();
    bad += title_bad_cp();
    bad += title_faults();
    bad += title_texts();
    bad += title_every_cp();
    bad += title_hostile();
    return bad;
}
