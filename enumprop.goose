// Seven enumerated properties. Each call gives the value of a code point
// as its position in PropertyValueAliases.txt, counted from zero for that
// property. Each `_name` call gives the short name of the value. A code
// point outside U+0000 to U+10FFFF gives the default value of the
// property. Every call is one binary search.
//
// A later release of the standard can add a value to the alias file and
// move a number. Compare the name when the program must outlive a release.
namespace unicode;

import std;

// The grapheme break of a code point.
fn grapheme_break(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_GCB_DEFAULT[0]; }
    return ENUM_GCB_MAP[grapheme_props(cp) & 15];
}

// The short name of the grapheme break of a code point.
fn grapheme_break_name(cp: i64) -> const u8[:] {
    let v = grapheme_break(cp);
    return ENUM_GCB_NAMES[ENUM_GCB_NAME_OFF[v]..ENUM_GCB_NAME_OFF[v + 1]];
}

// The word break of a code point.
fn word_break(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_WB_DEFAULT[0]; }
    return ENUM_WB_MAP[word_props_raw(cp) & 31];
}

// The short name of the word break of a code point.
fn word_break_name(cp: i64) -> const u8[:] {
    let v = word_break(cp);
    return ENUM_WB_NAMES[ENUM_WB_NAME_OFF[v]..ENUM_WB_NAME_OFF[v + 1]];
}

// The sentence break of a code point.
fn sentence_break(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_SB_DEFAULT[0]; }
    return ENUM_SB_MAP[sentence_class(cp)];
}

// The short name of the sentence break of a code point.
fn sentence_break_name(cp: i64) -> const u8[:] {
    let v = sentence_break(cp);
    return ENUM_SB_NAMES[ENUM_SB_NAME_OFF[v]..ENUM_SB_NAME_OFF[v + 1]];
}

// The hangul syllable type of a code point.
fn hangul_syllable_type(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_HST_DEFAULT[0]; }
    return ENUM_HST_VAL[last_at_or_below(ENUM_HST_START[..], cp)];
}

// The short name of the hangul syllable type of a code point.
fn hangul_syllable_type_name(cp: i64) -> const u8[:] {
    let v = hangul_syllable_type(cp);
    return ENUM_HST_NAMES[ENUM_HST_NAME_OFF[v]..ENUM_HST_NAME_OFF[v + 1]];
}

// The indic syllabic category of a code point.
fn indic_syllabic_category(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_INSC_DEFAULT[0]; }
    return ENUM_INSC_VAL[last_at_or_below(ENUM_INSC_START[..], cp)];
}

// The short name of the indic syllabic category of a code point.
fn indic_syllabic_category_name(cp: i64) -> const u8[:] {
    let v = indic_syllabic_category(cp);
    return ENUM_INSC_NAMES[ENUM_INSC_NAME_OFF[v]..ENUM_INSC_NAME_OFF[v + 1]];
}

// The indic positional category of a code point.
fn indic_positional_category(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_INPC_DEFAULT[0]; }
    return ENUM_INPC_VAL[last_at_or_below(ENUM_INPC_START[..], cp)];
}

// The short name of the indic positional category of a code point.
fn indic_positional_category_name(cp: i64) -> const u8[:] {
    let v = indic_positional_category(cp);
    return ENUM_INPC_NAMES[ENUM_INPC_NAME_OFF[v]..ENUM_INPC_NAME_OFF[v + 1]];
}

// The vertical orientation of a code point.
fn vertical_orientation(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return ENUM_VO_DEFAULT[0]; }
    return ENUM_VO_VAL[last_at_or_below(ENUM_VO_START[..], cp)];
}

// The short name of the vertical orientation of a code point.
fn vertical_orientation_name(cp: i64) -> const u8[:] {
    let v = vertical_orientation(cp);
    return ENUM_VO_NAMES[ENUM_VO_NAME_OFF[v]..ENUM_VO_NAME_OFF[v + 1]];
}
