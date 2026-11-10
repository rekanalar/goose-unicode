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
