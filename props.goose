// The script, width, class, mirror, numeric and name lookups.
//
// Every lookup is a binary search over a sorted table. A code point
// outside U+0000 to U+10FFFF takes the default of the property. The name
// of every named code point holds in one table; the lookup is one
// search. The names of the scripts and of the classes hold as packed
// strings with one offset array.
namespace unicode;

import std;

// The script of a code point, as a SCRIPT_ constant.
fn script(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return SCRIPT_UNKNOWN; }
    let i = last_at_or_below(SCRIPT_START[..], cp);
    if i < 0 { return SCRIPT_UNKNOWN; }
    return SCRIPT_INDEX[i];
}

// The name of the script of a code point, such as Latin or Han.
fn script_name(cp: i64) -> const u8[:] {
    let s = script(cp);
    return SCRIPT_NAMES[SCRIPT_OFF[s]..SCRIPT_OFF[s + 1]];
}

// The East Asian width of a code point, as a WIDTH_ constant.
fn width(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return WIDTH_NEUTRAL; }
    let i = run_at(WIDTH_START[..], WIDTH_END[..], cp);
    if i >= 0 { return WIDTH_VAL[i]; }
    return WIDTH_NEUTRAL;
}

// The name of the East Asian width, such as Wide or Neutral.
fn width_name(cp: i64) -> const u8[:] {
    let w = width(cp);
    return WIDTH_NAMES[WIDTH_NAME_OFF[w]..WIDTH_NAME_OFF[w + 1]];
}

// The bidirectional class of a code point, as a BIDI_ constant.
fn bidi_class(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return BIDI_R; }
    let i = run_at(BIDI_START[..], BIDI_END[..], cp);
    if i >= 0 { return BIDI_VAL[i]; }
    return BIDI_R;
}

// The name of the bidirectional class, such as L or AL.
fn bidi_class_name(cp: i64) -> const u8[:] {
    let b = bidi_class(cp);
    return BIDI_NAMES[BIDI_NAME_OFF[b]..BIDI_NAME_OFF[b + 1]];
}

// True when the code point is mirrored.
fn mirrored(cp: i64) -> bool {
    if cp < 0 || cp > 0x10FFFF { return false; }
    return run_at(MIRROR_START[..], MIRROR_END[..], cp) >= 0;
}

// The mirror partner of a code point. A code point that is not mirrored
// gives itself.
fn mirror_of(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return cp; }
    let i = run_at(MIRROR_START[..], MIRROR_END[..], cp);
    if i >= 0 { return cp + MIRROR_DELTA[i]; }
    return cp;
}

// The numeric value of a code point as the numerator and the
// denominator. A denominator of zero means no value.
fn numeric_value(cp: i64) -> i64, i64 {
    if cp < 0 || cp > 0x10FFFF { return 0, 0; }
    let i = run_at(NUM_START[..], NUM_END[..], cp);
    if i >= 0 { return NUM_NUM[i], NUM_DEN[i]; }
    return 0, 0;
}

// The name of a code point in the Character Database, such as LATIN
// CAPITAL LETTER A. A code point with no name gives the empty slice.
fn name(cp: i64) -> const u8[:] {
    if cp < 0 || cp > 0x10FFFF { return NAME_NAMES[0..0]; }
    let i = find_exact(NAME_START[..], cp);
    if i < 0 { return NAME_NAMES[0..0]; }
    return NAME_NAMES[NAME_OFF[i]..NAME_OFF[i + 1]];
}
