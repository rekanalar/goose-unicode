// Tests for the script, width, class, mirror, numeric and name calls.
namespace suite;

import std;
import unicode from "../..";

// The known scripts of a set of code points.
fn script_samples() -> i64 {
    var bad = 0;
    let cps: i64[8] = [0x41, 0x627, 0x4E00, 0x5D0, 0x3041, 0x1E900, 0x3000, 0xAC00];
    let want: u8[] = "LatinArabicHanHebrewHiraganaAdlamCommonHangul";
    let wo: i64[9] = [0, 5, 11, 14, 20, 28, 33, 39, 45];
    for k in 0..cps.len {
        let n = unicode::script_name(cps[k]);
        if n != want[wo[k]..wo[k + 1]] {
            print("FAIL: the script of ", cps[k], " is ", n, "\n");
            bad += 1;
        }
    }
    if unicode::script_name(-1) != "Unknown" {
        print("FAIL: a code point below zero has a script\n");
        bad += 1;
    }
    if unicode::script_name(0x110000) != "Unknown" {
        print("FAIL: a code point above the range has a script\n");
        bad += 1;
    }
    if unicode::script_name(0x378) != "Unknown" {
        print("FAIL: an unassigned code point has a script\n");
        bad += 1;
    }
    // The arabic letter mark takes the script of the text around it.
    if unicode::script_name(0x61C) != "Arabic" {
        print("FAIL: the arabic letter mark has a wrong script\n");
        bad += 1;
    }
    if unicode::script_name(0x301) != "Inherited" {
        print("FAIL: the combining acute has a wrong script\n");
        bad += 1;
    }
    return bad;
}

// The first and the last code point of every run of the script table.
// The runs cover the whole range, so the last run ends at U+10FFFF.
fn script_boundaries() -> i64 {
    var bad = 0;
    for k in 0..unicode::SCRIPT_START.len {
        if unicode::script(unicode::SCRIPT_START[k]) != unicode::SCRIPT_INDEX[k] {
            print("FAIL: the script of the first code point of run ", k, " differs\n");
            bad += 1;
        }
        var last: i64 = 0x10FFFF;
        if k + 1 < unicode::SCRIPT_START.len { last = unicode::SCRIPT_START[k + 1] - 1; }
        if unicode::script(last) != unicode::SCRIPT_INDEX[k] {
            print("FAIL: the script of the last code point of run ", k, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The six widths and the defaults.
fn width_samples() -> i64 {
    var bad = 0;
    let cps: i64[7] = [0x41, 0x4E00, 0xFF21, 0x3041, 0x2020, 0x61, 0x378];
    let want: u8[] = "NarrowWideFullwidthWideAmbiguousNarrowNeutral";
    let wo: i64[8] = [0, 6, 10, 19, 23, 32, 38, 45];
    for k in 0..cps.len {
        let n = unicode::width_name(cps[k]);
        if n != want[wo[k]..wo[k + 1]] {
            print("FAIL: the width of ", cps[k], " is ", n, "\n");
            bad += 1;
        }
    }
    if unicode::width(-1) != unicode::WIDTH_NEUTRAL {
        print("FAIL: a code point below zero has a width\n");
        bad += 1;
    }
    if unicode::width_name(0x110000) != "Neutral" {
        print("FAIL: a code point above the range has a width\n");
        bad += 1;
    }
    return bad;
}

// The first and the last code point of every run of the width table.
fn width_boundaries() -> i64 {
    var bad = 0;
    for k in 0..unicode::WIDTH_START.len {
        if unicode::width(unicode::WIDTH_START[k]) != unicode::WIDTH_VAL[k] {
            print("FAIL: the width of the first code point of run ", k, " differs\n");
            bad += 1;
        }
        if unicode::width(unicode::WIDTH_END[k]) != unicode::WIDTH_VAL[k] {
            print("FAIL: the width of the last code point of run ", k, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The known classes and the defaults.
fn bidi_samples() -> i64 {
    var bad = 0;
    let cps: i64[6] = [0x41, 0x627, 0x30, 0x20, 0x202A, 0x2069];
    let want: u8[] = "LALENWSLREPDI";
    let wo: i64[7] = [0, 1, 3, 5, 7, 10, 13];
    for k in 0..cps.len {
        let n = unicode::bidi_class_name(cps[k]);
        if n != want[wo[k]..wo[k + 1]] {
            print("FAIL: the class of ", cps[k], " is ", n, "\n");
            bad += 1;
        }
    }
    if unicode::bidi_class(-1) != unicode::BIDI_R {
        print("FAIL: a code point below zero has no right to left class\n");
        bad += 1;
    }
    if unicode::bidi_class_name(0x110000) != "R" {
        print("FAIL: a code point above the range has a class name\n");
        bad += 1;
    }
    return bad;
}

// The known mirror partners.
fn mirror_samples() -> i64 {
    var bad = 0;
    let cps: i64[6] = [0x28, 0x29, 0x3C, 0x3E, 0xAB, 0xBB];
    let want: i64[6] = [0x29, 0x28, 0x3E, 0x3C, 0xBB, 0xAB];
    for k in 0..cps.len {
        if !unicode::mirrored(cps[k]) {
            print("FAIL: ", cps[k], " is not mirrored\n");
            bad += 1;
        }
        if unicode::mirror_of(cps[k]) != want[k] {
            print("FAIL: the partner of ", cps[k], " differs\n");
            bad += 1;
        }
    }
    if unicode::mirrored(0x41) {
        print("FAIL: the letter A is mirrored\n");
        bad += 1;
    }
    if unicode::mirror_of(0x41) != 0x41 {
        print("FAIL: the partner of the letter A differs\n");
        bad += 1;
    }
    if unicode::mirrored(-1) || unicode::mirrored(0x110000) {
        print("FAIL: a code point outside the range is mirrored\n");
        bad += 1;
    }
    return bad;
}

// The first and the last code point of every run of the class and the
// mirror tables. A run with a delta of zero holds the code points that
// are their own partner.
fn bidi_boundaries() -> i64 {
    var bad = 0;
    for k in 0..unicode::BIDI_START.len {
        if unicode::bidi_class(unicode::BIDI_START[k]) != unicode::BIDI_VAL[k] {
            print("FAIL: the class of the first code point of run ", k, " differs\n");
            bad += 1;
        }
        if unicode::bidi_class(unicode::BIDI_END[k]) != unicode::BIDI_VAL[k] {
            print("FAIL: the class of the last code point of run ", k, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    for k in 0..unicode::MIRROR_START.len {
        if !unicode::mirrored(unicode::MIRROR_START[k]) {
            print("FAIL: the first code point of run ", k, " is not mirrored\n");
            bad += 1;
        }
        if unicode::mirror_of(unicode::MIRROR_START[k]) != unicode::MIRROR_START[k] + unicode::MIRROR_DELTA[k] {
            print("FAIL: the partner of the first code point of run ", k, " differs\n");
            bad += 1;
        }
        if unicode::mirror_of(unicode::MIRROR_END[k]) != unicode::MIRROR_END[k] + unicode::MIRROR_DELTA[k] {
            print("FAIL: the partner of the last code point of run ", k, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The whole numbers, the fractions and the code points with no value.
fn numeric_samples() -> i64 {
    var bad = 0;
    let cps: i64[5] = [0x30, 0xBD, 0x136B, 0x1369, 0x41];
    let want: i64[10] = [0, 1, 1, 2, 3, 1, 1, 1, 0, 0];
    for k in 0..cps.len {
        let num, den = unicode::numeric_value(cps[k]);
        if num != want[2 * k] || den != want[2 * k + 1] {
            print("FAIL: the value of ", cps[k], " differs\n");
            bad += 1;
        }
    }
    let num, den = unicode::numeric_value(-1);
    if num != 0 || den != 0 {
        print("FAIL: a code point below zero has a value\n");
        bad += 1;
    }
    let num2, den2 = unicode::numeric_value(0x110000);
    if num2 != 0 || den2 != 0 {
        print("FAIL: a code point above the range has a value\n");
        bad += 1;
    }
    return bad;
}

// Every code point with a value, against the values of the ICU library.
fn numeric_full() -> i64 {
    var bad = 0;
    for k in 0..NUM_CASE_CP.len {
        let num, den = unicode::numeric_value(NUM_CASE_CP[k]);
        if num != NUM_CASE_NUM[k] || den != NUM_CASE_DEN[k] {
            print("FAIL: the value of ", NUM_CASE_CP[k], " differs\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The known names and the code points with no name.
fn name_samples() -> i64 {
    var bad = 0;
    if unicode::name(0x41) != "LATIN CAPITAL LETTER A" {
        print("FAIL: the name of the letter A differs\n");
        bad += 1;
    }
    if unicode::name(0x20) != "SPACE" {
        print("FAIL: the name of the space differs\n");
        bad += 1;
    }
    if unicode::name(0xAC00) != "HANGUL SYLLABLE GA" {
        print("FAIL: the name of the hangul syllable differs\n");
        bad += 1;
    }
    if unicode::name(0xD7A3) != "HANGUL SYLLABLE HIH" {
        print("FAIL: the name of the last hangul syllable differs\n");
        bad += 1;
    }
    if unicode::name(0x4E00) != "CJK UNIFIED IDEOGRAPH-4E00" {
        print("FAIL: the name of the cjk ideograph differs\n");
        bad += 1;
    }
    if unicode::name(0x20000) != "CJK UNIFIED IDEOGRAPH-20000" {
        print("FAIL: the name of the wide cjk ideograph differs\n");
        bad += 1;
    }
    if unicode::name(0x17000) != "TANGUT IDEOGRAPH-17000" {
        print("FAIL: the name of the tangut ideograph differs\n");
        bad += 1;
    }
    if unicode::name(0x18B00) != "KHITAN SMALL SCRIPT CHARACTER-18B00" {
        print("FAIL: the name of the khitan character differs\n");
        bad += 1;
    }
    if unicode::name(0x1B170) != "NUSHU CHARACTER-1B170" {
        print("FAIL: the name of the nushu character differs\n");
        bad += 1;
    }
    if unicode::name(0xD800).len != 0 {
        print("FAIL: the surrogate has a name\n");
        bad += 1;
    }
    if unicode::name(0xE000).len != 0 {
        print("FAIL: the private use code point has a name\n");
        bad += 1;
    }
    if unicode::name(-1).len != 0 || unicode::name(0x110000).len != 0 {
        print("FAIL: a code point outside the range has a name\n");
        bad += 1;
    }
    if unicode::name(0x378).len != 0 {
        print("FAIL: an unassigned code point has a name\n");
        bad += 1;
    }
    return bad;
}

// Every code point with a name, against the names of the ICU library.
fn name_full() -> i64 {
    var bad = 0;
    for k in 0..NAME_CASE_CP.len {
        if unicode::name(NAME_CASE_CP[k]) != NAME_EXPECT[NAME_CASE_OFF[k]..NAME_CASE_OFF[k + 1]] {
            print("FAIL: the name of ", NAME_CASE_CP[k], " differs\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

fn run_props() -> i64 {
    var bad = 0;
    if want("props", "script_samples") { bad += script_samples(); }
    if want("props", "script_boundaries") { bad += script_boundaries(); }
    if want("props", "width_samples") { bad += width_samples(); }
    if want("props", "width_boundaries") { bad += width_boundaries(); }
    if want("props", "bidi_samples") { bad += bidi_samples(); }
    if want("props", "mirror_samples") { bad += mirror_samples(); }
    if want("props", "bidi_boundaries") { bad += bidi_boundaries(); }
    if want("props", "numeric_samples") { bad += numeric_samples(); }
    if want("props", "numeric_full") { bad += numeric_full(); }
    if want("props", "name_samples") { bad += name_samples(); }
    if want("props", "name_full") { bad += name_full(); }
    return bad;
}
