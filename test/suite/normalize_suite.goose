// Tests for the normalization forms and the quick check.
namespace suite;

import std;
import unicode from "../..";

// The bytes of the code points of a case column.
fn column_bytes(case: i64, col: i64) -> u8[>..] {
    let at = 5 * case + col;
    let start = NT_OFF[at];
    let stop = NT_OFF[at + 1];
    var out: u8[>..] = [];
    for k in start..stop { push_utf8(out, NT_POOL[k]); }
    return out;
}

// The bytes of one column of a mark case.
fn tr_column(case: i64, col: i64) -> u8[>..] {
    let at = 5 * case + col;
    let start = TR_OFF[at];
    let stop = TR_OFF[at + 1];
    var out: u8[>..] = [];
    for k in start..stop { push_utf8(out, TR_POOL[k]); }
    return out;
}

// Checks that the normalization of a column gives another column.
fn same_col(case: i64, form: i64, from: i64, want: i64) -> i64 {
    let text = column_bytes(case, from);
    var got: u8[>..] = [];
    let code, off = unicode::normalize(got, form, text[..]);
    if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); return 1; }
    let expect = column_bytes(case, want);
    if got[..] != expect[..] {
        print("FAIL: a case gave the wrong bytes at ", case, "\n");
        return 1;
    }
    return 0;
}

// The conformance rules of the normalization standard.
fn test_conformance() -> i64 {
    var bad = 0;
    let cases = (NT_OFF.len - 1) / 5;
    for c in 0..cases {
        // The source, the composed form and the decomposed form agree.
        bad += same_col(c, unicode::FORM_NFC, 0, 1);
        bad += same_col(c, unicode::FORM_NFC, 1, 1);
        bad += same_col(c, unicode::FORM_NFC, 2, 1);
        bad += same_col(c, unicode::FORM_NFD, 0, 2);
        bad += same_col(c, unicode::FORM_NFD, 1, 2);
        bad += same_col(c, unicode::FORM_NFD, 2, 2);
        // The compatibility columns agree with the canonical columns.
        bad += same_col(c, unicode::FORM_NFKC, 0, 3);
        bad += same_col(c, unicode::FORM_NFKC, 1, 3);
        bad += same_col(c, unicode::FORM_NFKC, 2, 3);
        bad += same_col(c, unicode::FORM_NFKC, 3, 3);
        bad += same_col(c, unicode::FORM_NFKC, 4, 3);
        bad += same_col(c, unicode::FORM_NFKD, 0, 4);
        bad += same_col(c, unicode::FORM_NFKD, 1, 4);
        bad += same_col(c, unicode::FORM_NFKD, 2, 4);
        bad += same_col(c, unicode::FORM_NFKD, 3, 4);
        bad += same_col(c, unicode::FORM_NFKD, 4, 4);
        if bad > 5 { return bad; }
    }
    return bad;
}

// The quick check must agree with the full conversion.
fn test_quick_check() -> i64 {
    var bad = 0;
    let cases = (NT_OFF.len - 1) / 5;
    let forms: i64[4] = [unicode::FORM_NFC, unicode::FORM_NFD, unicode::FORM_NFKC, unicode::FORM_NFKD];
    let wants: i64[4] = [1, 2, 3, 4];
    for c in 0..cases {
        for f in 0..4 {
            let text = column_bytes(c, 0);
            var got: u8[>..] = [];
            let code, off = unicode::normalize(got, forms[f], text[..]);
            if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); bad += 1; continue; }
            let quick = unicode::is_normalized(forms[f], text[..]);
            if quick != (got[..] == text[..]) {
                print("FAIL: the quick check differs at the case ", c, "\n");
                bad += 1;
            }
            // A column of the form must be in the form.
            let col = column_bytes(c, wants[f]);
            if !unicode::is_normalized(forms[f], col[..]) {
                print("FAIL: the quick check refused a form at the case ", c, "\n");
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The quick check must agree with the full conversion on random text.
fn test_quick_random() -> i64 {
    var bad = 0;
    var st: u64 = 987654321;
    let forms: i64[4] = [unicode::FORM_NFC, unicode::FORM_NFD, unicode::FORM_NFKC, unicode::FORM_NFKD];
    for k in 0..20000 {
        var text: u8[>..] = [];
        let n = rnd(st) % 8;
        for j in 0..n {
            let r = rnd(st);
            var cp: i64 = r % 0x110000;
            if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
            push_utf8(text, cp);
        }
        for f in 0..4 {
            var got: u8[>..] = [];
            let code, off = unicode::normalize(got, forms[f], text[..]);
            if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); bad += 1; continue; }
            let quick = unicode::is_normalized(forms[f], text[..]);
            if quick != (got[..] == text[..]) {
                print("FAIL: the quick check differs on the random text ", k, "\n");
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The cases of combining marks. The four forms must match the reference.
fn test_tricky() -> i64 {
    var bad = 0;
    let forms: i64[4] = [unicode::FORM_NFC, unicode::FORM_NFD, unicode::FORM_NFKC, unicode::FORM_NFKD];
    for c in 0..TR_OFF.len / 5 - 1 {
        let text = tr_column(c, 0);
        for f in 0..4 {
            var got: u8[>..] = [];
            let code, off = unicode::normalize(got, forms[f], text[..]);
            if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); bad += 1; continue; }
            let want = tr_column(c, f + 1);
            if got[..] != want[..] {
                print("FAIL: a mark case gave the wrong bytes at ", c, "\n");
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The composition exclusions of the standard. The pairs that the list
// names must stay apart.
fn test_exclusions() -> i64 {
    var bad = 0;
    for k in 0..EXCL_CASE.len / 3 {
        let a = EXCL_CASE[3 * k];
        let b = EXCL_CASE[3 * k + 1];
        let composite = EXCL_CASE[3 * k + 2];
        var text: u8[>..] = [];
        push_utf8(text, a);
        push_utf8(text, b);
        var got: u8[>..] = [];
        let code, off = unicode::normalize(got, unicode::FORM_NFC, text[..]);
        if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); bad += 1; continue; }
        var cps: i64[>..] = [];
        unicode::utf8_decode(cps, got[..]);
        if cps.len == 1 && cps[0] == composite {
            print("FAIL: an excluded pair composed at ", composite, "\n");
            bad += 1;
            continue;
        }
        // The decomposed form must stay decomposed too.
        var back: u8[>..] = [];
        let c2, o2 = unicode::normalize(back, unicode::FORM_NFC, got[..]);
        if c2 != unicode::OK || back[..] != got[..] {
            print("FAIL: an excluded pair composed again at ", composite, "\n");
            bad += 1;
        }
    }
    return bad;
}

// A mark between two code points blocks the composition of the pair.
// The mark case U+0061 U+0328 U+0301 gives U+0105 U+0301.
fn test_blocked() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    push_utf8(text, 0x61);
    push_utf8(text, 0x328);
    push_utf8(text, 0x301);
    var got: u8[>..] = [];
    let code, off = unicode::normalize(got, unicode::FORM_NFC, text[..]);
    if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); return 1; }
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, got[..]);
    if cps.len != 2 || cps[0] != 0x105 || cps[1] != 0x301 {
        print("FAIL: a blocked pair composed\n");
        bad += 1;
    }
    return bad;
}

// The Hangul syllables. The jamo must compose, and the syllable must
// decompose again.
fn test_hangul() -> i64 {
    var bad = 0;
    // The syllable U+AC01 is L, V and T. The jamo are U+1100, U+1161, U+11A8.
    var jamo: u8[>..] = [];
    push_utf8(jamo, 0x1100);
    push_utf8(jamo, 0x1161);
    push_utf8(jamo, 0x11A8);
    var got: u8[>..] = [];
    let code, off = unicode::normalize(got, unicode::FORM_NFC, jamo[..]);
    if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); return 1; }
    var want: u8[>..] = [];
    push_utf8(want, 0xAC01);
    if got[..] != want[..] {
        print("FAIL: the jamo did not compose\n");
        bad += 1;
    }
    var back: u8[>..] = [];
    let c2, off2 = unicode::normalize(back, unicode::FORM_NFD, want[..]);
    if c2 != unicode::OK { print("FAIL: the normalize gave the code ", c2, "\n"); return 1; }
    if back[..] != jamo[..] {
        print("FAIL: the syllable did not decompose\n");
        bad += 1;
    }
    return bad;
}

// A long run of combining marks. The order must be right, and the work
// must stay short.
fn test_long_run() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    push_utf8(text, 0x61);
    // The marks in the wrong order: the class 230 mark first, then the
    // class 202 mark.
    for k in 0..100 {
        push_utf8(text, 0x301);
        push_utf8(text, 0x316);
    }
    var got: u8[>..] = [];
    let code, off = unicode::normalize(got, unicode::FORM_NFD, text[..]);
    if code != unicode::OK { print("FAIL: the normalize gave the code ", code, "\n"); return 1; }
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, got[..]);
    if cps.len != 201 { print("FAIL: the count of the run was ", cps.len, "\n"); bad += 1; }
    if cps[1] != 0x316 { print("FAIL: the run is not in the canonical order\n"); bad += 1; }
    return bad;
}

// The faults of the normalize call.
fn norm_faults() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    let code, off = unicode::normalize(out, 4, "abc");
    if code != unicode::ERR_BAD_FORM { print("FAIL: the form was not checked\n"); bad += 1; }
    let code2, off2 = unicode::normalize(out, -1, "abc");
    if code2 != unicode::ERR_BAD_FORM { print("FAIL: the form was not checked\n"); bad += 1; }
    var bad_text: u8[>..] = [];
    bad_text.push(0x41);
    bad_text.push(0x80);
    let code3, off3 = unicode::normalize(out, unicode::FORM_NFC, bad_text[..]);
    if code3 != unicode::ERR_BAD_UTF8 { print("FAIL: the text was not checked\n"); bad += 1; }
    if off3 != 1 { print("FAIL: the offset was ", off3, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    if unicode::is_normalized(4, "abc") { print("FAIL: the form was not checked\n"); bad += 1; }
    if unicode::is_normalized(unicode::FORM_NFC, bad_text[..]) { print("FAIL: the text was not checked\n"); bad += 1; }
    return bad;
}

// Two spellings of one name must give the same bytes after the compose.
fn test_equality() -> i64 {
    var bad = 0;
    var one: u8[>..] = [];
    push_utf8(one, 0x63);
    push_utf8(one, 0x61);
    push_utf8(one, 0x66);
    push_utf8(one, 0x65);
    push_utf8(one, 0x301);
    var two: u8[>..] = [];
    push_utf8(two, 0x63);
    push_utf8(two, 0x61);
    push_utf8(two, 0x66);
    push_utf8(two, 0xE9);
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    unicode::normalize(a, unicode::FORM_NFC, one[..]);
    unicode::normalize(b, unicode::FORM_NFC, two[..]);
    if a[..] != b[..] { print("FAIL: two spellings differ\n"); bad += 1; }
    return bad;
}

fn run_normalize() -> i64 {
    var bad = 0;
    bad += test_conformance();
    bad += test_quick_check();
    bad += test_tricky();
    bad += test_exclusions();
    bad += test_blocked();
    bad += test_hangul();
    bad += test_long_run();
    bad += norm_faults();
    bad += test_equality();
    bad += test_quick_random();
    return bad;
}
