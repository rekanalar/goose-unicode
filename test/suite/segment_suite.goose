// Tests for the word and sentence segments.
namespace suite;

import std;
import unicode from "../..";

// The text of one case: the code points that start at the pool entry.
fn sg_text(pool: const i64[:], start: i64) -> u8[>..] {
    let n = pool[start];
    var out: u8[>..] = [];
    for k in 1..n + 1 { push_utf8(out, pool[start + k]); }
    return out;
}

// Counts the code points of s[a..b].
fn sg_cps(s: const u8[:], a: i64, b: i64) -> i64 {
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, s[a..b]);
    return cps.len;
}

// Walks a text with the next call and checks the sizes and the flags.
// flagged is true for words. Returns the number of faults.
fn sg_check(pool: const i64[:], start: i64, words: bool, label: const u8[:], c: i64) -> i64 {
    let text = sg_text(pool, start);
    let n = pool[start];
    let m = pool[start + n + 1];
    let sizes_at = start + n + 2;
    var offsets: i64[>..] = [];
    var code: i64 = 0;
    if words { code = unicode::word_offsets(offsets, text[..]); } else { code = unicode::sentence_offsets(offsets, text[..]); }
    if code != unicode::OK || offsets.len != m {
        print("FAIL: ", label, " case ", c, " gave ", offsets.len, " segments and not ", m, "\n");
        return 1;
    }
    var at: i64 = 0;
    for k in 0..m {
        var c2: i64 = 0;
        var end: i64 = 0;
        if words { c2, end = unicode::word_next(text[..], at); } else { c2, end = unicode::sentence_next(text[..], at); }
        if c2 != unicode::OK || at != offsets[k] || end <= at || sg_cps(text[..], at, end) != pool[sizes_at + k] {
            print("FAIL: ", label, " case ", c, " differs at segment ", k, "\n");
            return 1;
        }
        if words && unicode::is_word_like(text[..], at, end) != (pool[sizes_at + m + k] == 1) {
            print("FAIL: ", label, " case ", c, " gave a wrong word-like flag at segment ", k, "\n");
            return 1;
        }
        at = end;
    }
    if at != text.len { print("FAIL: ", label, " case ", c, " did not reach the end\n"); return 1; }
    var count: i64 = 0;
    if words { let c3, k3 = unicode::word_count(text[..]); count = k3; } else { let c3, k3 = unicode::sentence_count(text[..]); count = k3; }
    if count != m { print("FAIL: ", label, " case ", c, " gave a wrong count\n"); return 1; }
    return 0;
}

// Every conformance case of both test files, and the random cases that
// Node and an independent version of the rules both split the same way.
fn sg_cases() -> i64 {
    var bad = 0;
    for c in 0..WS_OFF.len - 1 {
        bad += sg_check(WS_POOL[..], WS_OFF[c], true, "word", c);
        if bad > 5 { return bad; }
    }
    for c in 0..SS_OFF.len - 1 {
        bad += sg_check(SS_POOL[..], SS_OFF[c], false, "sentence", c);
        if bad > 5 { return bad; }
    }
    return bad;
}

// The sizes of the segments of a text, in bytes, as a string like "3 1 4".
fn sg_split(s: const u8[:], words: bool) -> u8[>..] {
    var offsets: i64[>..] = [];
    if words { unicode::word_offsets(offsets, s); } else { unicode::sentence_offsets(offsets, s); }
    var out: u8[>..] = [];
    for k in 0..offsets.len {
        var end = s.len;
        if k + 1 < offsets.len { end = offsets[k + 1]; }
        if k > 0 { out.push(' '); }
        format_int(out, end - offsets[k], 10, 0, ' ');
    }
    return out;
}

// Text that a user knows.
fn sg_named() -> i64 {
    var bad = 0;
    if sg_split("Hello, world!", true)[..] != "5 1 1 5 1" { print("FAIL: the greeting split differs\n"); bad += 1; }
    if sg_split("it's 3.14", true)[..] != "4 1 4" { print("FAIL: the apostrophe or the decimal point split\n"); bad += 1; }
    if sg_split("foo_bar", true)[..] != "7" { print("FAIL: the connector split\n"); bad += 1; }
    // A capital letter after a full stop and a space starts a sentence, so the rules split "Mr. Smith".
    if sg_split("Mr. Smith left. Then he came back.", false)[..] != "4 12 18" {
        print("FAIL: the sentence split differs: ", sg_split("Mr. Smith left. Then he came back.", false)[..], "\n");
        bad += 1;
    }
    if sg_split("He said \"Go.\" She went.", false)[..] != "14 9" { print("FAIL: the closer split: ", sg_split("He said \"Go.\" She went.", false)[..], "\n"); bad += 1; }
    if sg_split("e.g. this one", false)[..] != "13" { print("FAIL: the lower case after a full stop split\n"); bad += 1; }
    if sg_split("What? Yes!\nNo.", false)[..] != "6 5 3" { print("FAIL: the question split: ", sg_split("What? Yes!\nNo.", false)[..], "\n"); bad += 1; }
    let w = "a b";
    if !unicode::is_word_like(w, 0, 1) || unicode::is_word_like(w, 1, 2) { print("FAIL: the word-like flag\n"); bad += 1; }
    if unicode::is_word_like("_", 0, 1) || !unicode::is_word_like("__", 0, 2) { print("FAIL: the connector flag\n"); bad += 1; }
    if unicode::is_word_like("a", 1, 1) || unicode::is_word_like("a", 0, 5) { print("FAIL: a bad range was word-like\n"); bad += 1; }
    return bad;
}

// A malformed byte forms a segment of its own, and the segments cover the text.
fn sg_malformed() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    text.push(0x61);
    text.push(0x80);
    text.push(0x62);
    if sg_split(text[..], true)[..] != "1 1 1" { print("FAIL: the malformed byte joined a word\n"); bad += 1; }
    if sg_split(text[..], false)[..] != "1 1 1" {
        print("FAIL: the malformed byte split a sentence: ", sg_split(text[..], false)[..], "\n");
        bad += 1;
    }
    return bad;
}

// The faults of the calls.
fn sg_faults() -> i64 {
    var bad = 0;
    let code, _ = unicode::word_next("abc", -1);
    if code != unicode::ERR_BAD_ARG { print("FAIL: the word offset was not checked\n"); bad += 1; }
    let code2, _ = unicode::word_next("abc", 3);
    if code2 != unicode::ERR_BAD_ARG { print("FAIL: the word offset was not checked\n"); bad += 1; }
    let code3, _ = unicode::sentence_next("", 0);
    if code3 != unicode::ERR_BAD_ARG { print("FAIL: the sentence offset was not checked\n"); bad += 1; }
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x61); }
    let code4, count = unicode::word_count(big[..]);
    if code4 != unicode::ERR_TOO_LONG { print("FAIL: a long text was accepted\n"); bad += 1; }
    var offsets: i64[>..] = [1];
    let code5 = unicode::sentence_offsets(offsets, big[..]);
    if code5 != unicode::ERR_TOO_LONG || offsets.len != 0 { print("FAIL: the long sentence text gave offsets\n"); bad += 1; }
    return bad;
}

// Hostile texts of the largest size. A call that scans back or ahead
// without a bound takes minutes on them. The run finishes only if the
// work is linear.
fn sg_hostile() -> i64 {
    var bad = 0;
    let n = 200000;
    // Apostrophes between letters, each followed by a long run of marks.
    var marks: u8[>..] = [];
    for k in 0..n / 4 { marks.push(0x61); marks.push(0x27); push_utf8(marks, 0x301); push_utf8(marks, 0x301); }
    let c1, _ = unicode::word_count(marks[..]);
    if c1 != unicode::OK { print("FAIL: the mark run gave the code ", c1, "\n"); bad += 1; }
    // One apostrophe and a million marks after it.
    var one: u8[>..] = [];
    one.push(0x61);
    one.push(0x27);
    for k in 0..n { push_utf8(one, 0x301); }
    let c2, w2 = unicode::word_count(one[..]);
    // The letter stands alone, and the apostrophe takes the marks.
    if c2 != unicode::OK || w2 != 2 { print("FAIL: the long run of marks gave ", w2, " segments\n"); bad += 1; }
    // A full stop, then digits to the end: one read ahead of the full size.
    var digits: u8[>..] = [];
    for k in 0..n / 4 { digits.push(0x61); digits.push(0x2E); digits.push(0x20); for j in 0..3 { digits.push(0x31); } }
    let c3, _ = unicode::sentence_count(digits[..]);
    if c3 != unicode::OK { print("FAIL: the digit text gave the code ", c3, "\n"); bad += 1; }
    // Full stops with no terminator in the text after them, only commas.
    var commas: u8[>..] = [];
    commas.push(0x61);
    commas.push(0x2E);
    commas.push(0x20);
    for k in 0..n { commas.push(0x2C); }
    let c4, s4 = unicode::sentence_count(commas[..]);
    if c4 != unicode::OK || s4 != 1 { print("FAIL: the comma run gave ", s4, " sentences\n"); bad += 1; }
    // A full stop and a long run of spaces: a read ahead for each space takes quadratic time.
    var spaces: u8[>..] = [];
    spaces.push(0x61);
    spaces.push(0x2E);
    for k in 0..n { spaces.push(0x20); }
    spaces.push(0x62);
    let c6, s6 = unicode::sentence_count(spaces[..]);
    if c6 != unicode::OK || s6 != 1 { print("FAIL: the space run gave ", s6, " sentences\n"); bad += 1; }
    // A full stop, a long run of closers and a lower case letter: one sentence.
    var closers: u8[>..] = [];
    closers.push(0x61);
    closers.push(0x2E);
    for k in 0..n { closers.push(0x29); }
    closers.push(0x20);
    closers.push(0x62);
    let c7, s7 = unicode::sentence_count(closers[..]);
    if c7 != unicode::OK || s7 != 1 { print("FAIL: the closer run gave ", s7, " sentences\n"); bad += 1; }
    // The same with a capital letter at the end: two sentences.
    closers[closers.len - 1] = 0x42;
    let c8, s8 = unicode::sentence_count(closers[..]);
    if c8 != unicode::OK || s8 != 2 { print("FAIL: the closer run with a capital gave ", s8, " sentences\n"); bad += 1; }
    // A million regional indicators split in pairs.
    var flags: u8[>..] = [];
    for k in 0..n { push_utf8(flags, 0x1F1E6); }
    let c5, w5 = unicode::word_count(flags[..]);
    if c5 != unicode::OK || w5 != n / 2 { print("FAIL: the flag run gave ", w5, " words\n"); bad += 1; }
    return bad;
}

// The count must equal the number of the offsets for random bytes.
fn sg_random() -> i64 {
    var bad = 0;
    var st: u64 = 424242;
    for k in 0..20000 {
        var text: u8[>..] = [];
        let n = rnd(st) % 10;
        for j in 0..n {
            let r = rnd(st);
            if r % 5 == 0 {
                text.push(0x80 + (r % 0x40) as u8);
            } else {
                var cp: i64 = r % 0x110000;
                if r % 3 == 0 { cp = 0x20 + r % 0x60; }
                if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
                push_utf8(text, cp);
            }
        }
        let c1, w = unicode::word_count(text[..]);
        let c2, s = unicode::sentence_count(text[..]);
        var wo: i64[>..] = [];
        var so: i64[>..] = [];
        unicode::word_offsets(wo, text[..]);
        unicode::sentence_offsets(so, text[..]);
        if c1 != unicode::OK || c2 != unicode::OK || wo.len != w || so.len != s || s > w {
            print("FAIL: the counts differ at ", k, "\n");
            bad += 1;
        }
        if text.len > 0 && (w < 1 || s < 1 || wo[0] != 0 || so[0] != 0) { print("FAIL: the first offset differs at ", k, "\n"); bad += 1; }
        if bad > 5 { return bad; }
    }
    return bad;
}

fn run_segment() -> i64 {
    var bad = 0;
    if want("segment", "sg_cases") { bad += sg_cases(); }
    if want("segment", "sg_named") { bad += sg_named(); }
    if want("segment", "sg_malformed") { bad += sg_malformed(); }
    if want("segment", "sg_faults") { bad += sg_faults(); }
    if want("segment", "sg_hostile") { bad += sg_hostile(); }
    if want("segment", "sg_random") { bad += sg_random(); }
    return bad;
}
