// Tests for the Greek, Dutch and Armenian rules of the locale aware case
// mapping. The tables hold the rows of the ICU library that differ from
// the root locale. The replay of a group reuses the function of the locale
// suite.
namespace suite;

import std;
import os;
import unicode from "../..";

// Checks one text against the wanted code points. It reuses the replay of
// the locale suite. kind: 0 upper, 1 lower, 2 title.
fn grk_check(kind: i64, locale: i64, input: const i64[:], want: const i64[:], what: const u8[:]) -> i64 {
    var off_in: i64[2] = [0, input.len];
    var off_out: i64[2] = [0, want.len];
    return replay(input[..], off_in[..], want[..], off_out[..], what, kind, locale);
}

// The Greek scenarios of the contract.
fn grk_scenarios() -> i64 {
    var bad = 0;
    let el = unicode::LOCALE_EL;
    bad += grk_check(0, el, [0x3B7, 0x303], [0x397, 0x301], "or");
    bad += grk_check(0, el, [0x397, 0x301, 0x20], [0x397, 0x301, 0x20], "or then space");
    bad += grk_check(0, el, [0x397, 0x301, 0x3A3], [0x397, 0x3A3], "eta before sigma");
    bad += grk_check(0, el, [0x3B1, 0x3B7, 0x301], [0x391, 0x397], "eta after alpha");
    bad += grk_check(0, el, [0x3B9, 0x301], [0x399], "iota alone");
    bad += grk_check(0, el, [0x391, 0x342, 0x399, 0x301], [0x391, 0x399, 0x308], "dialytika added");
    bad += grk_check(0, el, [0x1FB3], [0x391, 0x399], "iota subscript");
    bad += grk_check(0, el, [0x390], [0x3AA], "precomposed dialytika");
    bad += grk_check(0, el, [0x3B9, 0x308, 0x301], [0x399, 0x308], "combining dialytika");
    bad += grk_check(0, el, [0x3B1, 0x304], [0x391], "macron");
    bad += grk_check(0, el, [0x397, 0x345, 0x301], [0x397, 0x399], "subscript blocks or");
    bad += grk_check(0, el, [0x397, 0x301, 0x31], [0x397, 0x301, 0x31], "or before digit");
    bad += grk_check(0, el, [0x3A9, 0x3C5, 0x308], [0x3A9, 0x3A5, 0x308], "omega upsilon dialytika");
    bad += grk_check(0, el, [0x345, 0x3B1], [0x399, 0x391], "lone subscript");
    bad += grk_check(0, el, [0x3E2], [0x3E2], "coptic");
    bad += grk_check(0, el, [0x1D26], [0x1D26], "phonetic");
    bad += grk_check(0, el, [0x587], [0x535, 0x552], "ligature under el");
    bad += grk_check(0, el, [0x3B9, 0x307, 0x300], [0x399, 0x307, 0x300], "other mark");
    bad += grk_check(2, el, [0x3B7, 0x303], [0x397, 0x303], "el title");
    bad += grk_check(1, el, [0x397, 0x301], [0x3B7, 0x301], "el lower");
    return bad;
}

// The Dutch and Armenian scenarios of the contract.
fn grk_other() -> i64 {
    var bad = 0;
    let nl = unicode::LOCALE_NL;
    let hy = unicode::LOCALE_HY;
    bad += grk_check(2, nl, [0x69, 0x6A], [0x49, 0x4A], "nl ij");
    bad += grk_check(2, nl, [0x49, 0x6A], [0x49, 0x4A], "nl Ij");
    bad += grk_check(2, nl, [0x69, 0x4A], [0x49, 0x4A], "nl iJ");
    bad += grk_check(2, nl, [0x49, 0x4A], [0x49, 0x4A], "nl IJ");
    bad += grk_check(2, nl, [0x69, 0x301, 0x6A, 0x301], [0x49, 0x301, 0x4A, 0x301], "nl acute");
    bad += grk_check(2, nl, [0x69, 0x301, 0x6A], [0x49, 0x301, 0x6A], "nl acute no second");
    bad += grk_check(2, nl, [0xED, 0x6A, 0x301], [0xCD, 0x4A, 0x301], "nl precomposed");
    bad += grk_check(2, nl, [0xCD, 0x6A], [0xCD, 0x6A], "nl precomposed no second");
    bad += grk_check(2, nl, [0x69, 0x301, 0x6A, 0x308], [0x49, 0x301, 0x6A, 0x308], "nl mark after");
    bad += grk_check(2, nl, [0x69, 0x307, 0x6A], [0x49, 0x307, 0x6A], "nl dot above");
    bad += grk_check(2, nl, [0x27, 0x69, 0x6A], [0x27, 0x49, 0x4A], "nl apostrophe");
    bad += grk_check(2, nl, [0x49, 0x4A, 0x20, 0x69, 0x6A], [0x49, 0x4A, 0x20, 0x49, 0x4A], "nl two words");
    bad += grk_check(2, nl, [0x49], [0x49], "nl lone i");
    bad += grk_check(2, nl, [0x131, 0x6A], [0x49, 0x4A], "nl dotless i");
    bad += grk_check(2, unicode::LOCALE_ROOT, [0x69, 0x6A], [0x49, 0x6A], "root ij");
    bad += grk_check(0, hy, [0x587], [0x535, 0x54E], "hy upper");
    bad += grk_check(2, hy, [0x587], [0x535, 0x57E], "hy title");
    bad += grk_check(1, hy, [0x587], [0x587], "hy lower");
    bad += grk_check(0, unicode::LOCALE_ROOT, [0x587], [0x535, 0x552], "root upper");
    bad += grk_check(2, unicode::LOCALE_ROOT, [0x587], [0x535, 0x582], "root title");
    bad += grk_check(0, nl, [0x587], [0x535, 0x552], "nl upper of the ligature");
    return bad;
}

// Over every scalar value: the Greek upper case equals the stored rows and
// the root case everywhere else. The other calls under el, nl and hy equal
// the root case, except U+0587 under hy.
fn grk_scalars() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    var row: i64 = 0;
    var want: u8[>..] = [];
    let rows = GRK_ONE_IN_OFF.len - 1;
    for cp in 0..0x110000 {
        if cp >= 0xD800 && cp <= 0xDFFF { continue; }
        text.clear();
        unicode::utf8_encode(text, cp);
        let stored = row < rows && GRK_ONE_IN_POOL[row] == cp;
        unicode::to_upper_locale(a, text[..], unicode::LOCALE_EL);
        if stored {
            want.clear();
            for j in GRK_ONE_OUT_OFF[row]..GRK_ONE_OUT_OFF[row + 1] { unicode::utf8_encode(want, GRK_ONE_OUT_POOL[j]); }
            row += 1;
        } else {
            unicode::to_upper_full(want, text[..]);
        }
        if a[..] != want[..] {
            print("FAIL: el upper of ", cp, "\n");
            bad += 1;
        }
        unicode::to_lower_full(b, text[..]);
        for loc in [unicode::LOCALE_EL, unicode::LOCALE_NL, unicode::LOCALE_HY] {
            unicode::to_lower_locale(a, text[..], loc);
            if a[..] != b[..] { print("FAIL: lower of ", cp, " in ", loc, "\n"); bad += 1; }
        }
        unicode::to_title(b, text[..]);
        for loc in [unicode::LOCALE_EL, unicode::LOCALE_NL, unicode::LOCALE_HY] {
            unicode::to_title_locale(a, text[..], loc);
            if cp == 0x587 && loc == unicode::LOCALE_HY { continue; }
            if a[..] != b[..] { print("FAIL: title of ", cp, " in ", loc, "\n"); bad += 1; }
        }
        unicode::to_upper_full(b, text[..]);
        for loc in [unicode::LOCALE_NL, unicode::LOCALE_HY] {
            unicode::to_upper_locale(a, text[..], loc);
            if cp == 0x587 && loc == unicode::LOCALE_HY { continue; }
            if a[..] != b[..] { print("FAIL: upper of ", cp, " in ", loc, "\n"); bad += 1; }
        }
        if bad > 5 { return bad; }
    }
    if row != rows { print("FAIL: ", rows - row, " stored Greek rows were not reached\n"); bad += 1; }
    return bad;
}

// The language tags of the three new locales.
fn grk_tags() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    text.append("el\nEL-fr\nell\nell_GR\nnl\nNL_BE\nnld\nhy\nhye\nhy-AM\nhyw\nelx\nn\nnlx");
    var want: i64[14] = [4, 4, 4, 4, 5, 5, 5, 6, 6, 6, 0, 0, 0, 0];
    var k: i64 = 0;
    for tag in split(text[..], '\n') {
        if unicode::locale_of(tag) != want[k] {
            print("FAIL: locale_of row ", k, " gives ", unicode::locale_of(tag), "\n");
            bad += 1;
        }
        k += 1;
    }
    return bad;
}

// A bad byte, a text above MAX_INPUT and a locale that is no constant.
// A result above MAX_OUTPUT cannot happen: no Greek letter grows a text of
// MAX_INPUT bytes by a third, so the check of the walk is a guard only.
fn grk_faults() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var text: u8[>..] = [];
    unicode::utf8_encode(text, 0x2AA);
    text.push(0xFF);
    for loc in [unicode::LOCALE_EL, unicode::LOCALE_NL, unicode::LOCALE_HY] {
        let c1, o1 = unicode::to_upper_locale(out, text[..], loc);
        if c1 != unicode::ERR_BAD_UTF8 || o1 != 2 || out.len != 0 { print("FAIL: upper bad byte ", loc, "\n"); bad += 1; }
        let c2, o2 = unicode::to_lower_locale(out, text[..], loc);
        if c2 != unicode::ERR_BAD_UTF8 || o2 != 2 || out.len != 0 { print("FAIL: lower bad byte ", loc, "\n"); bad += 1; }
        let c3, o3 = unicode::to_title_locale(out, text[..], loc);
        if c3 != unicode::ERR_BAD_UTF8 || o3 != 2 || out.len != 0 { print("FAIL: title bad byte ", loc, "\n"); bad += 1; }
    }
    // A bad byte after Greek letters, inside the skip loop and the scan.
    text.clear();
    unicode::utf8_encode(text, 0x397);
    unicode::utf8_encode(text, 0x301);
    text.push(0xFF);
    let c4, o4 = unicode::to_upper_locale(out, text[..], unicode::LOCALE_EL);
    if c4 != unicode::ERR_BAD_UTF8 || o4 != 4 || out.len != 0 { print("FAIL: Greek bad byte after the marks gives ", c4, " at ", o4, "\n"); bad += 1; }
    text.clear();
    for k in 0..1048577 { text.push(97); }
    let c5, _ = unicode::to_upper_locale(out, text[..], unicode::LOCALE_EL);
    if c5 != unicode::ERR_TOO_LONG || out.len != 0 { print("FAIL: Greek too long gives ", c5, "\n"); bad += 1; }
    let c6, _ = unicode::to_title_locale(out, text[..], unicode::LOCALE_NL);
    if c6 != unicode::ERR_TOO_LONG || out.len != 0 { print("FAIL: Dutch too long gives ", c6, "\n"); bad += 1; }
    text.clear();
    for loc in [-1, 7, 100] {
        let c7, _ = unicode::to_upper_locale(out, text[..], loc);
        if c7 != unicode::ERR_BAD_ARG { print("FAIL: bad locale ", loc, "\n"); bad += 1; }
    }
    return bad;
}

// Hostile Greek text stays linear: a text of MAX_INPUT bytes of the three
// shapes that exercise the scan after an eta.
fn grk_hostile() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var text: u8[>..] = [];
    // Eta, perispomeni and a space, repeated.
    while text.len + 5 <= 1048576 {
        unicode::utf8_encode(text, 0x3B7);
        unicode::utf8_encode(text, 0x303);
        text.push(0x20);
    }
    let t0 = clock_ns();
    let c1, _ = unicode::to_upper_locale(out, text[..], unicode::LOCALE_EL);
    let t1 = clock_ns();
    if c1 != unicode::OK || t1 - t0 > 5000000000 { print("FAIL: hostile eta text\n"); bad += 1; }
    // One eta with an accent, then a run of case ignorable marks.
    text.clear();
    unicode::utf8_encode(text, 0x397);
    unicode::utf8_encode(text, 0x301);
    while text.len + 2 <= 1048576 { unicode::utf8_encode(text, 0x307); }
    let t2 = clock_ns();
    let c2, _ = unicode::to_upper_locale(out, text[..], unicode::LOCALE_EL);
    let t3 = clock_ns();
    if c2 != unicode::OK || t3 - t2 > 5000000000 { print("FAIL: hostile run of marks\n"); bad += 1; }
    // Many etas, each with its own run of marks, split by a full stop.
    text.clear();
    while text.len + 120 <= 1048576 {
        unicode::utf8_encode(text, 0x397);
        unicode::utf8_encode(text, 0x301);
        for k in 0..50 { unicode::utf8_encode(text, 0x307); }
        text.push(0x2E);
    }
    let t4 = clock_ns();
    let c3, _ = unicode::to_upper_locale(out, text[..], unicode::LOCALE_EL);
    let t5 = clock_ns();
    if c3 != unicode::OK || t5 - t4 > 5000000000 { print("FAIL: hostile eta runs\n"); bad += 1; }
    // Dutch: many digraph starts with marks.
    text.clear();
    while text.len + 6 <= 1048576 {
        text.push(0x69);
        text.push(0x6A);
        unicode::utf8_encode(text, 0x301);
        unicode::utf8_encode(text, 0x301);
        text.push(0x20);
    }
    let t6 = clock_ns();
    let c4, _ = unicode::to_title_locale(out, text[..], unicode::LOCALE_NL);
    let t7 = clock_ns();
    if c4 != unicode::OK || t7 - t6 > 5000000000 { print("FAIL: hostile Dutch text\n"); bad += 1; }
    print("hostile Greek texts: ", (t1 - t0) / 1000000, ", ", (t3 - t2) / 1000000, ", ", (t5 - t4) / 1000000, ", ", (t7 - t6) / 1000000, " ms\n");
    return bad;
}

fn run_greek() -> i64 {
    var bad = 0;
    bad += replay(GRK_UP_IN_POOL[..], GRK_UP_IN_OFF[..], GRK_UP_OUT_POOL[..], GRK_UP_OUT_OFF[..], "el upper", 0, unicode::LOCALE_EL);
    bad += replay(GRK_ONE_IN_POOL[..], GRK_ONE_IN_OFF[..], GRK_ONE_OUT_POOL[..], GRK_ONE_OUT_OFF[..], "el upper single", 0, unicode::LOCALE_EL);
    bad += replay(DUT_TI_IN_POOL[..], DUT_TI_IN_OFF[..], DUT_TI_OUT_POOL[..], DUT_TI_OUT_OFF[..], "nl title", 2, unicode::LOCALE_NL);
    bad += grk_scenarios();
    bad += grk_other();
    bad += grk_tags();
    bad += grk_faults();
    bad += grk_hostile();
    bad += grk_scalars();
    if bad > 0 { print("FAIL: Greek suite holds ", bad, " errors\n"); }
    return bad;
}
