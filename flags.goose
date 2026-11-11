// The group of the general category, and the emoji and identifier
// properties. One range table gives a bit mask for each code point. Each
// test reads one bit after one binary search.
namespace unicode;

import std;

const FLAG_EMOJI: i64 = 1;
const FLAG_EMOJI_PRESENTATION: i64 = 2;
const FLAG_EMOJI_MODIFIER: i64 = 4;
const FLAG_EMOJI_MODIFIER_BASE: i64 = 8;
const FLAG_EMOJI_COMPONENT: i64 = 16;
const FLAG_EXTENDED_PICTOGRAPHIC: i64 = 32;
const FLAG_ID_START: i64 = 64;
const FLAG_ID_CONTINUE: i64 = 128;
const FLAG_XID_START: i64 = 256;
const FLAG_XID_CONTINUE: i64 = 512;

// The mask of a code point. A value outside the range holds no bit.
fn flags_of(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return 0; }
    let i = run_at(FLAG_START[..], FLAG_END[..], cp);
    if i < 0 { return 0; }
    return FLAG_MASK[i];
}

// The group of the general category of a code point, as a GROUP_
// constant. A value outside the range gives GROUP_OTHER.
fn category_group(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return GROUP_OTHER; }
    let c = category(cp);
    if c >= CAT_LU && c <= CAT_LO { return GROUP_LETTER; }
    if c >= CAT_MN && c <= CAT_ME { return GROUP_MARK; }
    if c >= CAT_ND && c <= CAT_NO { return GROUP_NUMBER; }
    if c >= CAT_PC && c <= CAT_PO { return GROUP_PUNCTUATION; }
    if c >= CAT_SM && c <= CAT_SO { return GROUP_SYMBOL; }
    if c >= CAT_ZS && c <= CAT_ZP { return GROUP_SEPARATOR; }
    return GROUP_OTHER;
}

// True for an upper case, a lower case and a title case letter.
fn is_letter_cased(cp: i64) -> bool {
    let c = category(cp);
    return c >= CAT_LU && c <= CAT_LT;
}

fn is_emoji(cp: i64) -> bool { return (flags_of(cp) & FLAG_EMOJI) != 0; }
fn is_emoji_presentation(cp: i64) -> bool { return (flags_of(cp) & FLAG_EMOJI_PRESENTATION) != 0; }
fn is_emoji_modifier(cp: i64) -> bool { return (flags_of(cp) & FLAG_EMOJI_MODIFIER) != 0; }
fn is_emoji_modifier_base(cp: i64) -> bool { return (flags_of(cp) & FLAG_EMOJI_MODIFIER_BASE) != 0; }
fn is_emoji_component(cp: i64) -> bool { return (flags_of(cp) & FLAG_EMOJI_COMPONENT) != 0; }
fn is_extended_pictographic(cp: i64) -> bool { return (flags_of(cp) & FLAG_EXTENDED_PICTOGRAPHIC) != 0; }
fn is_id_start(cp: i64) -> bool { return (flags_of(cp) & FLAG_ID_START) != 0; }
fn is_id_continue(cp: i64) -> bool { return (flags_of(cp) & FLAG_ID_CONTINUE) != 0; }
fn is_xid_start(cp: i64) -> bool { return (flags_of(cp) & FLAG_XID_START) != 0; }
fn is_xid_continue(cp: i64) -> bool { return (flags_of(cp) & FLAG_XID_CONTINUE) != 0; }

// The zero width joiner.
fn is_zwj(cp: i64) -> bool { return cp == 0x200D; }

// The variation selector 16, which asks for the emoji form.
fn is_emoji_presentation_selector(cp: i64) -> bool { return cp == 0xFE0F; }

// The variation selector 15, which asks for the text form.
fn is_text_presentation_selector(cp: i64) -> bool { return cp == 0xFE0E; }

// One of the 26 regional indicators. A pair of them forms a flag.
fn is_regional_indicator(cp: i64) -> bool { return cp >= 0x1F1E6 && cp <= 0x1F1FF; }

// One of the tag characters, which mark the variants of an emoji.
fn is_tag_character(cp: i64) -> bool { return cp >= 0xE0020 && cp <= 0xE007F; }

// Binary properties. The number of a property is its bit in the mask.
const PROP_EMOJI: i64 = 0;
const PROP_EMOJI_PRESENTATION: i64 = 1;
const PROP_EMOJI_MODIFIER: i64 = 2;
const PROP_EMOJI_MODIFIER_BASE: i64 = 3;
const PROP_EMOJI_COMPONENT: i64 = 4;
const PROP_EXTENDED_PICTOGRAPHIC: i64 = 5;
const PROP_ID_START: i64 = 6;
const PROP_ID_CONTINUE: i64 = 7;
const PROP_XID_START: i64 = 8;
const PROP_XID_CONTINUE: i64 = 9;
const PROP_ALPHABETIC: i64 = 10;
const PROP_CASE_IGNORABLE: i64 = 11;
const PROP_CASED: i64 = 12;
const PROP_CHANGES_WHEN_CASEFOLDED: i64 = 13;
const PROP_CHANGES_WHEN_CASEMAPPED: i64 = 14;
const PROP_CHANGES_WHEN_LOWERCASED: i64 = 15;
const PROP_CHANGES_WHEN_TITLECASED: i64 = 16;
const PROP_CHANGES_WHEN_UPPERCASED: i64 = 17;
const PROP_DEFAULT_IGNORABLE_CODE_POINT: i64 = 18;
const PROP_GRAPHEME_BASE: i64 = 19;
const PROP_GRAPHEME_EXTEND: i64 = 20;
const PROP_LOWERCASE: i64 = 21;
const PROP_MATH: i64 = 22;
const PROP_UPPERCASE: i64 = 23;
const PROP_ASCII_HEX_DIGIT: i64 = 24;
const PROP_BIDI_CONTROL: i64 = 25;
const PROP_DASH: i64 = 26;
const PROP_DEPRECATED: i64 = 27;
const PROP_DIACRITIC: i64 = 28;
const PROP_EXTENDER: i64 = 29;
const PROP_HEX_DIGIT: i64 = 30;
const PROP_IDS_BINARY_OPERATOR: i64 = 31;
const PROP_IDS_TRINARY_OPERATOR: i64 = 32;
const PROP_IDEOGRAPHIC: i64 = 33;
const PROP_JOIN_CONTROL: i64 = 34;
const PROP_LOGICAL_ORDER_EXCEPTION: i64 = 35;
const PROP_NONCHARACTER_CODE_POINT: i64 = 36;
const PROP_PATTERN_SYNTAX: i64 = 37;
const PROP_PATTERN_WHITE_SPACE: i64 = 38;
const PROP_QUOTATION_MARK: i64 = 39;
const PROP_RADICAL: i64 = 40;
const PROP_SENTENCE_TERMINAL: i64 = 41;
const PROP_SOFT_DOTTED: i64 = 42;
const PROP_TERMINAL_PUNCTUATION: i64 = 43;
const PROP_UNIFIED_IDEOGRAPH: i64 = 44;
const PROP_VARIATION_SELECTOR: i64 = 45;
const PROP_WHITE_SPACE: i64 = 46;
const PROP_CHANGES_WHEN_NFKC_CASEFOLDED: i64 = 47;
const PROP_IDS_UNARY_OPERATOR: i64 = 48;
const PROP_PREPENDED_CONCATENATION_MARK: i64 = 49;
const PROP_MODIFIER_COMBINING_MARK: i64 = 50;
const PROP_ID_COMPAT_MATH_START: i64 = 51;
const PROP_ID_COMPAT_MATH_CONTINUE: i64 = 52;
// The number of binary properties.
const PROP_COUNT: i64 = 53;

// True when the code point holds the binary property prop, a PROP_
// constant. A code point outside the range and a value that is no
// property give false.
fn has_property(cp: i64, prop: i64) -> bool {
    if prop < 0 || prop >= PROP_COUNT { return false; }
    return ((flags_of(cp) >> prop) & 1) != 0;
}

// The name of a property, such as White_Space. A value that is no
// property gives the empty slice.
fn property_name(prop: i64) -> const u8[:] {
    if prop < 0 || prop >= PROP_COUNT { return PROP_NAMES[0..0]; }
    return PROP_NAMES[PROP_OFF[prop]..PROP_OFF[prop + 1]];
}

// The lower case form of one ASCII letter. Other bytes stay.
fn prop_lower(b: u8) -> i64 {
    if b >= 'A' && b <= 'Z' { return b + 32; }
    return b;
}

// True when the two texts match, ignoring the case of ASCII letters.
fn prop_name_equal(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    for i in 0..a.len {
        if prop_lower(a[i]) != prop_lower(b[i]) { return false; }
    }
    return true;
}

// The constant of a property name. The match ignores the case of ASCII
// letters and nothing else. A name that no property holds gives -1.
// The longest name holds 28 bytes, so a long query stops at once.
fn property_by_name(name: const u8[:]) -> i64 {
    if name.len == 0 || name.len > 28 { return -1; }
    for p in 0..PROP_COUNT {
        if prop_name_equal(name, property_name(p)) { return p; }
    }
    return -1;
}
