// Tests for the locale aware case mapping. The tables hold the texts whose
// result differs from the root locale, and the result of the ICU library.
// A group is one locale and one case.
namespace suite;

import std;
import os;
import unicode from "../..";

fn loc_fail(what: const u8[:], k: i64) {
    print("FAIL: ", what, " row ", k, "\n");
}

// Replays one group. kind: 0 upper, 1 lower, 2 title.
fn replay(pool_in: const i64[:], off_in: const i64[:],
          pool_out: const i64[:], off_out: const i64[:],
          what: const u8[:], kind: i64, locale: i64) -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    var out: u8[>..] = [];
    var got: i64[>..] = [];
    for r in 0..off_in.len - 1 {
        text.clear();
        for j in off_in[r]..off_in[r + 1] {
            unicode::utf8_encode(text, pool_in[j]);
        }
        var code: i64 = 0;
        var at: i64 = 0;
        if kind == 0 {
            code, at = unicode::to_upper_locale(out, text[..], locale);
        } else if kind == 1 {
            code, at = unicode::to_lower_locale(out, text[..], locale);
        } else {
            code, at = unicode::to_title_locale(out, text[..], locale);
        }
        if code != unicode::OK {
            loc_fail(what, r);
            bad += 1;
            continue;
        }
        got.clear();
        unicode::utf8_decode(got, out[..]);
        let n = off_out[r + 1] - off_out[r];
        if got.len != n {
            loc_fail(what, r);
            bad += 1;
            if bad > 5 { return bad; }
            continue;
        }
        for j in 0..n {
            if got[j] != pool_out[off_out[r] + j] {
                loc_fail(what, r);
                bad += 1;
                break;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

fn loc_tr() -> i64 {
    var bad = 0;
    bad += replay(LOC_TR_UP_IN_POOL[..], LOC_TR_UP_IN_OFF[..],
                  LOC_TR_UP_OUT_POOL[..], LOC_TR_UP_OUT_OFF[..],
                  "tr upper", 0, unicode::LOCALE_TR);
    bad += replay(LOC_TR_LO_IN_POOL[..], LOC_TR_LO_IN_OFF[..],
                  LOC_TR_LO_OUT_POOL[..], LOC_TR_LO_OUT_OFF[..],
                  "tr lower", 1, unicode::LOCALE_TR);
    bad += replay(LOC_TR_TI_IN_POOL[..], LOC_TR_TI_IN_OFF[..],
                  LOC_TR_TI_OUT_POOL[..], LOC_TR_TI_OUT_OFF[..],
                  "tr title", 2, unicode::LOCALE_TR);
    return bad;
}

fn loc_az() -> i64 {
    var bad = 0;
    bad += replay(LOC_AZ_UP_IN_POOL[..], LOC_AZ_UP_IN_OFF[..],
                  LOC_AZ_UP_OUT_POOL[..], LOC_AZ_UP_OUT_OFF[..],
                  "az upper", 0, unicode::LOCALE_AZ);
    bad += replay(LOC_AZ_LO_IN_POOL[..], LOC_AZ_LO_IN_OFF[..],
                  LOC_AZ_LO_OUT_POOL[..], LOC_AZ_LO_OUT_OFF[..],
                  "az lower", 1, unicode::LOCALE_AZ);
    bad += replay(LOC_AZ_TI_IN_POOL[..], LOC_AZ_TI_IN_OFF[..],
                  LOC_AZ_TI_OUT_POOL[..], LOC_AZ_TI_OUT_OFF[..],
                  "az title", 2, unicode::LOCALE_AZ);
    return bad;
}

fn loc_lt() -> i64 {
    var bad = 0;
    bad += replay(LOC_LT_UP_IN_POOL[..], LOC_LT_UP_IN_OFF[..],
                  LOC_LT_UP_OUT_POOL[..], LOC_LT_UP_OUT_OFF[..],
                  "lt upper", 0, unicode::LOCALE_LT);
    bad += replay(LOC_LT_LO_IN_POOL[..], LOC_LT_LO_IN_OFF[..],
                  LOC_LT_LO_OUT_POOL[..], LOC_LT_LO_OUT_OFF[..],
                  "lt lower", 1, unicode::LOCALE_LT);
    bad += replay(LOC_LT_TI_IN_POOL[..], LOC_LT_TI_IN_OFF[..],
                  LOC_LT_TI_OUT_POOL[..], LOC_LT_TI_OUT_OFF[..],
                  "lt title", 2, unicode::LOCALE_LT);
    return bad;
}

// The root locale gives the result of the plain calls. The answer of the
// table is the plain call itself, so this checks only the fault paths and
// that the calls run at all.
fn loc_root() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    let c1, _1 = unicode::to_upper_locale(out, "Straße", unicode::LOCALE_ROOT);
    if c1 != unicode::OK || out[..] != "STRASSE" { bad += 1; print("FAIL: root upper\n"); }
    let c2, _2 = unicode::to_lower_locale(out, "ΟΟΣ ΟΣ", unicode::LOCALE_ROOT);
    if c2 != unicode::OK || out[..] != "οος ος" { bad += 1; print("FAIL: root lower\n"); }
    let c3, _3 = unicode::to_title_locale(out, "ǆ straße don't", unicode::LOCALE_ROOT);
    if c3 != unicode::OK || out[..] != "ǅ Straße Don't" { bad += 1; print("FAIL: root title\n"); }
    return bad;
}

// A locale value that is no constant gives ERR_BAD_ARG and an empty buffer.
fn loc_bad_locale() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var text: u8[>..] = [];
    for loc in [-1, 4, 100] {
        let c, o = unicode::to_upper_locale(out, text[..], loc);
        if c != unicode::ERR_BAD_ARG || o != -1 || out.len != 0 {
            print("FAIL: upper locale ", loc, "\n");
            bad += 1;
        }
        let c2, o2 = unicode::to_lower_locale(out, text[..], loc);
        if c2 != unicode::ERR_BAD_ARG || o2 != -1 || out.len != 0 {
            print("FAIL: lower locale ", loc, "\n");
            bad += 1;
        }
        let c3, o3 = unicode::to_title_locale(out, text[..], loc);
        if c3 != unicode::ERR_BAD_ARG || o3 != -1 || out.len != 0 {
            print("FAIL: title locale ", loc, "\n");
            bad += 1;
        }
    }
    return bad;
}

// A bad byte gives ERR_BAD_UTF8, the offset of the byte and an empty
// buffer. The offset is the byte at the cursor.
fn loc_bad_utf8() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var text: u8[>..] = [];
    unicode::utf8_encode(text, 0x131);
    text.push(0xFF);
    unicode::utf8_encode(text, 0x69);
    for loc in [unicode::LOCALE_TR, unicode::LOCALE_LT] {
        let c, o = unicode::to_lower_locale(out, text[..], loc);
        if c != unicode::ERR_BAD_UTF8 || o != 2 || out.len != 0 {
            print("FAIL: lower bad byte gives ", c, " at ", o, "\n");
            bad += 1;
        }
        let c2, _ = unicode::to_upper_locale(out, text[..], loc);
        if c2 != unicode::ERR_BAD_UTF8 || out.len != 0 {
            print("FAIL: upper bad byte gives ", c2, "\n");
            bad += 1;
        }
    }
    return bad;
}

// A text above MAX_INPUT gives ERR_TOO_LONG and an empty buffer.
fn loc_too_long() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var text: u8[>..] = [];
    for k in 0..1048577 { text.push(97); }
    let c, _ = unicode::to_upper_locale(out, text[..], unicode::LOCALE_TR);
    if c != unicode::ERR_TOO_LONG || out.len != 0 {
        print("FAIL: too long gives ", c, "\n");
        bad += 1;
    }
    return bad;
}

// The language tags of the contract. want: 0 root, 1 tr, 2 az, 3 lt.
fn loc_tags() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    text.append("tr\nTR\ntr-TR\ntr_TR\ntur\ntr-\naz\naz-Latn-AZ\naz_Latn\naze\nlt\nLT\nlt-LT\nlit\n\nen\nt\ntu\ntrx\nturk\ntr.UTF-8");
    var want: i64[21] = [1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0];
    var k: i64 = 0;
    for tag in split(text[..], '\n') {
        let got = unicode::locale_of(tag);
        if got != want[k] {
            print("FAIL: locale_of row ", k, " gives ", got, "\n");
            bad += 1;
        }
        k += 1;
    }
    // tr@x=y
    var odd: u8[>..] = [];
    odd.append("tr@x=y");
    if unicode::locale_of(odd[..]) != unicode::LOCALE_ROOT {
        print("FAIL: locale_of of tr@x=y\n");
        bad += 1;
    }
    // A byte above 127.
    var high: u8[>..] = [];
    high.push(0xC3); high.push(0xA9);
    if unicode::locale_of(high[..]) != unicode::LOCALE_ROOT {
        print("FAIL: locale_of of a high byte\n");
        bad += 1;
    }
    return bad;
}

// A hostile text stays linear. The text of MAX_INPUT bytes holds the
// pattern I, mark of class 220, repeated: each letter scans forward over
// the run of marks to its next trigger.
fn loc_hostile() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    while text.len + 5 <= 1048576 {
        text.push(0x49);
        text.push(0xCC); text.push(0x96);
        text.push(0xCC); text.push(0x81);
    }
    var out: u8[>..] = [];
    let t0 = clock_ns();
    let c, _ = unicode::to_lower_locale(out, text[..], unicode::LOCALE_LT);
    let t1 = clock_ns();
    if c != unicode::OK { print("FAIL: hostile gives ", c, "\n"); bad += 1; }
    print("hostile text of ", text.len, " bytes: ", (t1 - t0) / 1000000, " ms\n");
    if t1 - t0 > 5000000000 { print("FAIL: hostile text is too slow\n"); bad += 1; }
    return bad;
}

fn run_locale() -> i64 {
    var bad = 0;
    bad += loc_tr();
    bad += loc_az();
    bad += loc_lt();
    bad += loc_root();
    bad += loc_bad_locale();
    bad += loc_bad_utf8();
    bad += loc_too_long();
    bad += loc_tags();
    bad += loc_hostile();
    if bad > 0 {
        print("FAIL: locale suite holds ", bad, " errors\n");
    }
    return bad;
}
