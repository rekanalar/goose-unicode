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
fn case_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: case ", name, "\n"); return 1; }
    return 0;
}

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
    if want("case", "case_upper") { bad += case_upper(); }
    if want("case", "case_lower") { bad += case_lower(); }
    if want("case", "case_fold") { bad += case_fold(); }
    if want("case", "case_named") { bad += case_named(); }
    if want("case", "case_fold_equal") { bad += case_fold_equal(); }
    if want("case", "case_faults") { bad += case_faults(); }
    if want("case", "case_bound") { bad += case_bound(); }
    if want("case", "case_nfkc_fold") { bad += case_nfkc_fold(); }
    return bad;
}

// The NFKC case fold: the fixed strings from the ICU library, the rows
// of the NFKC_CF table, and the faults.
fn case_nfkc_fold() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var want: u8[>..] = [];
    // The fixed strings. Each holds the fold of one text, so the fold
    // of the fold is the fold itself.
    for t in 0..CF_FIXED_OFF.len - 1 {
        want.clear();
        unicode::encode_all(want, CF_POOL[CF_FIXED_OFF[t]..CF_FIXED_OFF[t + 1]]);
        let code, off = unicode::nfkc_casefold(out, want[..]);
        if code != unicode::OK || out[..] != want[..] {
            print("FAIL: nfkc fold idempotent at text ", t, " code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    // The rows: the fold of one listed code point is its mapped text.
    for r in 0..CF_CP.len {
        want.clear();
        unicode::encode_all(want, CF_POOL[CF_ROW_OFF[r]..CF_ROW_OFF[r + 1]]);
        var one: u8[>..] = [];
        unicode::utf8_encode(one, CF_CP[r]);
        let code, off = unicode::nfkc_casefold(out, one[..]);
        if code != unicode::OK || out[..] != want[..] {
            print("FAIL: nfkc fold of U+", CF_CP[r], " code ", code, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    // Two spellings of one text fold to the same bytes.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    push_utf8(a, 0x1E9E);
    append_str(b, "SS");
    let c1, _ = unicode::nfkc_casefold(out, a[..]);
    var fa: u8[>..] = [];
    for k in 0..out.len { fa.push(out[k]); }
    let c2, _ = unicode::nfkc_casefold(out, b[..]);
    var fb: u8[>..] = [];
    for k in 0..out.len { fb.push(out[k]); }
    bad += case_check(c1 == unicode::OK && c2 == unicode::OK && fa[..] == fb[..], "sharp s pair");
    // A bad byte gives its offset and an empty buffer.
    var s2: u8[>..] = [];
    append_str(s2, "ab\xFFcd");
    let c3, o3 = unicode::nfkc_casefold(out, s2[..]);
    bad += case_check(c3 == unicode::ERR_BAD_UTF8 && o3 == 2 && out.len == 0, "bad byte");
    // A text above MAX_INPUT gives ERR_TOO_LONG.
    var big: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { big.push('a'); }
    let c4, _ = unicode::nfkc_casefold(out, big[..]);
    bad += case_check(c4 == unicode::ERR_TOO_LONG && out.len == 0, "input above the bound");
    // A hostile text of the longest expansion grows the result above
    // MAX_OUTPUT. U+FDFA folds to five code points.
    var many: u8[>..] = [];
    var i: i64 = 0;
    while i < unicode::MAX_INPUT {
        push_utf8(many, 0xFDFA);
        i += 3;
    }
    let c5, _ = unicode::nfkc_casefold(out, many[..]);
    bad += case_check(c5 == unicode::ERR_TOO_LONG && out.len == 0, "output above the bound");
    // A linear hostile text runs clean.
    var wall: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { wall.push('a'); }
    let c6, _ = unicode::nfkc_casefold(out, wall[..]);
    bad += case_check(c6 == unicode::OK && out.len == unicode::MAX_INPUT, "1 MiB of ASCII");
    // A surrogate is a bad byte.
    var sur: u8[>..] = [];
    append_str(sur, "a\xED\xA0\x80b");
    let c7, o7 = unicode::nfkc_casefold(out, sur[..]);
    bad += case_check(c7 == unicode::ERR_BAD_UTF8 && o7 == 1, "surrogate");
    return bad;
}

