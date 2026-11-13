// Tests for the seven enumerated property calls. Each table holds the runs
// of the ICU library: first code point, last code point, position of the
// value in the alias file.
namespace suite;

import std;
import unicode from "../..";

fn en_fail(what: const u8[:], cp: i64, got: i64, want: i64) {
    print("FAIL: ", what, " of ", cp, " gives ", got, ", want ", want, "\n");
}
// The first, the middle and the last code point of every run.
fn en_grapheme_break() -> i64 {
    var bad = 0;
    for k in 0..EN_GCB.len / 3 {
        let a = EN_GCB[3 * k];
        let b = EN_GCB[3 * k + 1];
        let want = EN_GCB[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::grapheme_break(cp);
            if got != want {
                en_fail("grapheme_break", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_word_break() -> i64 {
    var bad = 0;
    for k in 0..EN_WB.len / 3 {
        let a = EN_WB[3 * k];
        let b = EN_WB[3 * k + 1];
        let want = EN_WB[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::word_break(cp);
            if got != want {
                en_fail("word_break", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_sentence_break() -> i64 {
    var bad = 0;
    for k in 0..EN_SB.len / 3 {
        let a = EN_SB[3 * k];
        let b = EN_SB[3 * k + 1];
        let want = EN_SB[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::sentence_break(cp);
            if got != want {
                en_fail("sentence_break", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_hangul_syllable_type() -> i64 {
    var bad = 0;
    for k in 0..EN_HST.len / 3 {
        let a = EN_HST[3 * k];
        let b = EN_HST[3 * k + 1];
        let want = EN_HST[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::hangul_syllable_type(cp);
            if got != want {
                en_fail("hangul_syllable_type", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_indic_syllabic_category() -> i64 {
    var bad = 0;
    for k in 0..EN_INSC.len / 3 {
        let a = EN_INSC[3 * k];
        let b = EN_INSC[3 * k + 1];
        let want = EN_INSC[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::indic_syllabic_category(cp);
            if got != want {
                en_fail("indic_syllabic_category", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_indic_positional_category() -> i64 {
    var bad = 0;
    for k in 0..EN_INPC.len / 3 {
        let a = EN_INPC[3 * k];
        let b = EN_INPC[3 * k + 1];
        let want = EN_INPC[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::indic_positional_category(cp);
            if got != want {
                en_fail("indic_positional_category", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The first, the middle and the last code point of every run.
fn en_vertical_orientation() -> i64 {
    var bad = 0;
    for k in 0..EN_VO.len / 3 {
        let a = EN_VO[3 * k];
        let b = EN_VO[3 * k + 1];
        let want = EN_VO[3 * k + 2];
        for cp in [a, (a + b) / 2, b] {
            let got = unicode::vertical_orientation(cp);
            if got != want {
                en_fail("vertical_orientation", cp, got, want);
                bad += 1;
            }
        }
        if bad > 5 { return bad; }
    }
    return bad;
}
// The default value for a code point outside the range, and the names.
fn en_edges() -> i64 {
    var bad = 0;
    for cp in [-1, 0x110000, 0x7FFFFFFF] {
        if unicode::grapheme_break_name(cp) != "XX" { bad += 1; print("FAIL: grapheme_break default\n"); }
        if unicode::word_break_name(cp) != "XX" { bad += 1; print("FAIL: word_break default\n"); }
        if unicode::sentence_break_name(cp) != "XX" { bad += 1; print("FAIL: sentence_break default\n"); }
        if unicode::hangul_syllable_type_name(cp) != "NA" { bad += 1; print("FAIL: hangul default\n"); }
        if unicode::indic_syllabic_category_name(cp) != "Other" { bad += 1; print("FAIL: insc default\n"); }
        if unicode::indic_positional_category_name(cp) != "NA" { bad += 1; print("FAIL: inpc default\n"); }
        if unicode::vertical_orientation_name(cp) != "R" { bad += 1; print("FAIL: vo default\n"); }
    }
    if unicode::sentence_break_name(0x41) != "UP" { bad += 1; print("FAIL: sentence_break A\n"); }
    if unicode::word_break_name(0x41) != "LE" { bad += 1; print("FAIL: word_break A\n"); }
    if unicode::grapheme_break_name(0x300) != "EX" { bad += 1; print("FAIL: grapheme_break mark\n"); }
    if unicode::hangul_syllable_type_name(0xAC00) != "LV" { bad += 1; print("FAIL: hangul LV\n"); }
    if unicode::hangul_syllable_type_name(0xAC01) != "LVT" { bad += 1; print("FAIL: hangul LVT\n"); }
    if unicode::indic_syllabic_category_name(0x94D) != "Virama" { bad += 1; print("FAIL: insc virama\n"); }
    if unicode::indic_positional_category_name(0x93F) != "Left" { bad += 1; print("FAIL: inpc left\n"); }
    if unicode::vertical_orientation_name(0x4E00) != "U" { bad += 1; print("FAIL: vo ideograph\n"); }
    if unicode::vertical_orientation_name(0x41) != "R" { bad += 1; print("FAIL: vo letter\n"); }
    return bad;
}

fn run_enum() -> i64 {
    var bad = 0;
    if want("enum", "en_edges") { bad += en_edges(); }
    if want("enum", "en_grapheme_break") { bad += en_grapheme_break(); }
    if want("enum", "en_word_break") { bad += en_word_break(); }
    if want("enum", "en_sentence_break") { bad += en_sentence_break(); }
    if want("enum", "en_hangul_syllable_type") { bad += en_hangul_syllable_type(); }
    if want("enum", "en_indic_syllabic_category") { bad += en_indic_syllabic_category(); }
    if want("enum", "en_indic_positional_category") { bad += en_indic_positional_category(); }
    if want("enum", "en_vertical_orientation") { bad += en_vertical_orientation(); }
    return bad;
}
