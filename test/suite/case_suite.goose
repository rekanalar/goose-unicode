// Tests for the upper case, the lower case and the case folding.
namespace suite;

import std;
import unicode from "../..";

// The bytes of one code point.
fn one(cp: i64) -> u8[>..] {
    var out: u8[>..] = [];
    push_utf8(out, cp);
    return out;
}

// The code points of a byte string.
fn cps_of(s: const u8[:]) -> i64[>..] {
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, s);
    return cps;
}

// The simple upper case of every code point of the table.
fn case_upper() -> i64 {
    var bad = 0;
    for k in 0..PC_UP.len / 2 {
        let cp = PC_UP[2 * k];
        let want = PC_UP[2 * k + 1];
        var out: u8[>..] = [];
        let code, off = unicode::to_upper(out, one(cp)[..]);
        if code != unicode::OK { print("FAIL: the upper case gave the code ", code, "\n"); bad += 1; continue; }
        let got = cps_of(out[..]);
        if got.len != 1 || got[0] != want {
            print("FAIL: the upper case of ", cp, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The simple lower case of every code point of the table.
fn case_lower() -> i64 {
    var bad = 0;
    for k in 0..PC_LO.len / 2 {
        let cp = PC_LO[2 * k];
        let want = PC_LO[2 * k + 1];
        var out: u8[>..] = [];
        let code, off = unicode::to_lower(out, one(cp)[..]);
        if code != unicode::OK { print("FAIL: the lower case gave the code ", code, "\n"); bad += 1; continue; }
        let got = cps_of(out[..]);
        if got.len != 1 || got[0] != want {
            print("FAIL: the lower case of ", cp, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The full case folding of every code point of the table.
fn case_fold() -> i64 {
    var bad = 0;
    var k: i64 = 0;
    while k < PC_FOLD.len {
        let cp = PC_FOLD[k];
        let n = PC_FOLD[k + 1];
        var want: i64[>..] = [];
        for j in 0..n { want.push(PC_FOLD[k + 2 + j]); }
        k += 2 + n;
        var out: u8[>..] = [];
        let code, off = unicode::fold_case(out, one(cp)[..]);
        if code != unicode::OK { print("FAIL: the fold gave the code ", code, "\n"); bad += 1; continue; }
        let got = cps_of(out[..]);
        if got.len != want.len {
            print("FAIL: the fold of ", cp, " has a wrong count\n");
            bad += 1;
            continue;
        }
        for j in 0..want.len {
            if got[j] != want[j] {
                print("FAIL: the fold of ", cp, " differs\n");
                bad += 1;
                break;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The cases that the references name.
fn case_named() -> i64 {
    var bad = 0;
    // The German sharp s folds to "ss".
    var out: u8[>..] = [];
    unicode::fold_case(out, "Straße");
    if out[..] != "strasse" {
        print("FAIL: the fold of the sharp s differs\n");
        bad += 1;
    }
    // The Greek sigma folds to the final sigma.
    out.clear();
    unicode::fold_case(out, "Σ");
    if out[..] != "σ" {
        print("FAIL: the fold of the sigma differs\n");
        bad += 1;
    }
    // The Cherokee small letter folds to the capital letter.
    out.clear();
    unicode::fold_case(out, "ꭰ");
    if out[..] != "Ꭰ" {
        print("FAIL: the fold of the Cherokee letter differs\n");
        bad += 1;
    }
    // The upper case of the small Greek letter gives the capital.
    out.clear();
    unicode::to_upper(out, "α");
    if out[..] != "Α" {
        print("FAIL: the upper case of the alpha differs\n");
        bad += 1;
    }
    // The lower case of the capital Greek letter gives the small letter.
    out.clear();
    unicode::to_lower(out, "Α");
    if out[..] != "α" {
        print("FAIL: the lower case of the alpha differs\n");
        bad += 1;
    }
    // The Turkish dotless i keeps its value in the simple mapping.
    out.clear();
    unicode::to_lower(out, "I");
    if out[..] != "i" {
        print("FAIL: the lower case of the I differs\n");
        bad += 1;
    }
    return bad;
}

// The fold of a text must not change when the text is folded again.
fn case_fold_equal() -> i64 {
    var bad = 0;
    var st: u64 = 24680;
    for k in 0..2000 {
        var text: u8[>..] = [];
        let n = rnd(st) % 6;
        for j in 0..n {
            let r = rnd(st);
            var cp: i64 = r % 0x110000;
            if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
            push_utf8(text, cp);
        }
        var once: u8[>..] = [];
        var twice: u8[>..] = [];
        let c1, o1 = unicode::fold_case(once, text[..]);
        let c2, o2 = unicode::fold_case(twice, once[..]);
        if c1 != unicode::OK || c2 != unicode::OK {
            print("FAIL: the fold gave a fault\n");
            bad += 1;
            continue;
        }
        if once[..] != twice[..] {
            print("FAIL: the fold changed the text again at ", k, "\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The faults of the case calls.
fn case_faults() -> i64 {
    var bad = 0;
    var bad_text: u8[>..] = [];
    bad_text.push(0x41);
    bad_text.push(0x80);
    var out: u8[>..] = [];
    let code, off = unicode::to_upper(out, bad_text[..]);
    if code != unicode::ERR_BAD_UTF8 { print("FAIL: the text was not checked\n"); bad += 1; }
    if off != 1 { print("FAIL: the offset was ", off, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    out.clear();
    let code2, off2 = unicode::to_lower(out, bad_text[..]);
    if code2 != unicode::ERR_BAD_UTF8 { print("FAIL: the text was not checked\n"); bad += 1; }
    out.clear();
    let code3, off3 = unicode::fold_case(out, bad_text[..]);
    if code3 != unicode::ERR_BAD_UTF8 { print("FAIL: the text was not checked\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    return bad;
}

// The input bound.
fn case_bound() -> i64 {
    var bad = 0;
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x41); }
    var out: u8[>..] = [];
    let code, off = unicode::to_upper(out, big[..]);
    if code != unicode::ERR_TOO_LONG { print("FAIL: the bound was not checked\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    return bad;
}

fn run_case() -> i64 {
    var bad = 0;
    bad += case_upper();
    bad += case_lower();
    bad += case_fold();
    bad += case_named();
    bad += case_fold_equal();
    bad += case_faults();
    bad += case_bound();
    return bad;
}
