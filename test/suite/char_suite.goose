// Tests for the numeric type, decomposition, joining and bracket calls.
namespace suite;

import std;
import unicode from "../..";

fn ch_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: char ", name, "\n"); return 1; }
    return 0;
}

// Checks the first, the last and every code point of each run of ICU.
fn ch_runs(start: const i64[:], end: const i64[:], val: const i64[:], kind: i64) -> i64 {
    var bad = 0;
    for r in 0..start.len {
        for cp in start[r]..end[r] + 1 {
            var got: i64 = 0;
            if kind == 0 { got = unicode::numeric_type(cp); }
            else if kind == 1 { got = unicode::decomposition_type(cp); }
            else if kind == 2 { got = unicode::joining_type(cp); }
            else { got = unicode::joining_group(cp); }
            if got != val[r] {
                bad += 1;
                if bad <= 5 { print("FAIL: char property ", kind, " of ", cp, " is ", got, ", want ", val[r], "\n"); }
            }
        }
    }
    return bad;
}

fn char_values() -> i64 {
    var bad = 0;
    for k in 0..CV_CP.len {
        if unicode::decimal_value(CV_CP[k]) != CV_DEC[k] || unicode::digit_value(CV_CP[k]) != CV_DIG[k] {
            bad += 1;
            if bad <= 5 { print("FAIL: digit values of ", CV_CP[k], "\n"); }
        }
    }
    return bad;
}

fn char_samples() -> i64 {
    var bad = 0;
    bad += ch_check(unicode::numeric_type(0x35) == unicode::NUMTYPE_DECIMAL, "decimal");
    bad += ch_check(unicode::numeric_type(0xB2) == unicode::NUMTYPE_DIGIT, "digit");
    bad += ch_check(unicode::numeric_type(0xBD) == unicode::NUMTYPE_NUMERIC, "numeric");
    bad += ch_check(unicode::numeric_type(0x41) == unicode::NUMTYPE_NONE, "none");
    bad += ch_check(unicode::numeric_type_name(0xBD) == "Numeric", "numeric name");
    bad += ch_check(unicode::decimal_value(0x665) == 5, "arabic five");
    bad += ch_check(unicode::decimal_value(0xB2) == -1 && unicode::digit_value(0xB2) == 2, "superscript two");
    bad += ch_check(unicode::decimal_value(0xBD) == -1 && unicode::digit_value(0xBD) == -1, "one half");
    bad += ch_check(unicode::decomposition_type(0xE9) == unicode::DECOMP_CANONICAL, "canonical");
    bad += ch_check(unicode::decomposition_type(0xA0) == unicode::DECOMP_NOBREAK, "no break");
    bad += ch_check(unicode::decomposition_type_name(0xFB01) == "Compat", "ligature name");
    bad += ch_check(unicode::decomposition_type(0x61) == unicode::DECOMP_NONE, "no mapping");
    var m: i64[>..] = [];
    unicode::decomposition(m, 0xE9);
    bad += ch_check(m.len == 2 && m[0] == 0x65 && m[1] == 0x301, "mapping of e acute");
    unicode::decomposition(m, 0xFB01);
    bad += ch_check(m.len == 2 && m[0] == 0x66 && m[1] == 0x69, "mapping of fi");
    unicode::decomposition(m, 0x61);
    bad += ch_check(m.len == 0, "empty mapping");
    unicode::decomposition(m, 0xAC01);
    bad += ch_check(m.len == 3 && m[0] == 0x1100 && m[1] == 0x1161 && m[2] == 0x11A8, "syllable");
    unicode::decomposition(m, 0xAC00);
    bad += ch_check(m.len == 2, "syllable without final");
    unicode::decomposition(m, 0x110000);
    bad += ch_check(m.len == 0, "mapping outside the range");
    bad += ch_check(unicode::joining_type(0x628) == unicode::JOINING_DUAL, "beh");
    bad += ch_check(unicode::joining_type(0x627) == unicode::JOINING_RIGHT, "alef");
    bad += ch_check(unicode::joining_type(0x300) == unicode::JOINING_TRANSPARENT, "mark");
    bad += ch_check(unicode::joining_type(0x41) == unicode::JOINING_NONE, "A");
    bad += ch_check(unicode::joining_type_name(0x640) == "Join_Causing", "tatweel");
    bad += ch_check(unicode::joining_group_name(0x628) == "Beh", "beh group");
    bad += ch_check(unicode::joining_group_name(0x41) == "No_Joining_Group", "no group");
    bad += ch_check(unicode::bidi_bracket_type(0x28) == unicode::BRACKET_OPEN, "open");
    bad += ch_check(unicode::bidi_bracket_type(0x29) == unicode::BRACKET_CLOSE, "close");
    bad += ch_check(unicode::bidi_bracket_type(0x41) == unicode::BRACKET_NONE, "no bracket");
    bad += ch_check(unicode::bidi_paired_bracket(0x28) == 0x29 && unicode::bidi_paired_bracket(0x5D) == 0x5B, "partner");
    bad += ch_check(unicode::bidi_paired_bracket(0x41) == 0x41, "no partner");
    bad += ch_check(unicode::numeric_type(-1) == 0 && unicode::decimal_value(0x110000) == -1
        && unicode::decomposition_type(-5) == 0 && unicode::joining_type(0x7FFFFFFF) == 0
        && unicode::bidi_paired_bracket(-1) == -1, "outside the range");
    return bad;
}

fn run_char() -> i64 {
    var bad = 0;
    if want("char", "char_samples") { bad += char_samples(); }
    if want("char", "char_values") { bad += char_values(); }
    bad += ch_runs(CT_START[..], CT_END[..], CT_VAL[..], 0);
    bad += ch_runs(CD_START[..], CD_END[..], CD_VAL[..], 1);
    bad += ch_runs(CJ_START[..], CJ_END[..], CJ_VAL[..], 2);
    bad += ch_runs(CG_START[..], CG_END[..], CG_VAL[..], 3);
    return bad;
}
