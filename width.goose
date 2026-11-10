// The width of a character and of a text, in terminal columns. The rules
// follow the Rust unicode-width crate, the only reference that documents
// a full rule set. The walk of a text runs from the end and holds one
// small state, so the width of a text is linear in its bytes.
//
// The package does not apply the script ligature rules of the crate, and
// it holds no East Asian context form. The README names both limits.
//
// The script test/make_width_data.py checks the tables against the crate
// over the whole code point range. The suite holds 50,040 texts of the
// sequence characters, with the width of each from the crate.
namespace unicode;

import std;

// ---- the state of the walk ------------------------------------------
// A copy of the bit layout of the crate. The walk reads the state of the
// code points to the right, so the states join by bits.
const ST_DEFAULT: i64 = 0;
const ST_LINE_FEED: i64 = 0x0001;
const ST_EMOJI_MODIFIER: i64 = 0x0002;
const ST_REGIONAL_INDICATOR: i64 = 0x0003;
const ST_SEVERAL_RI: i64 = 0x0004;
const ST_EMOJI_PRESENTATION: i64 = 0x0005;
const ST_ZWJ_EMOJI: i64 = 0x1006;
const ST_KEYCAP_ZWJ: i64 = 0x1007;
const ST_VS16_ZWJ_EMOJI: i64 = 0x9006;
const ST_VS16_KEYCAP_ZWJ: i64 = 0x9007;
const ST_RI_ZWJ: i64 = 0x0009;
const ST_EVEN_RI_ZWJ: i64 = 0x000A;
const ST_ODD_RI_ZWJ: i64 = 0x000B;
const ST_TAG_END_ZWJ: i64 = 0x0010;
const ST_TAG_D1: i64 = 0x0011;
const ST_TAG_D2: i64 = 0x0012;
const ST_TAG_D3: i64 = 0x0013;
const ST_TAG_A1: i64 = 0x0019;
const ST_TAG_A2: i64 = 0x001A;
const ST_TAG_A3: i64 = 0x001B;
const ST_TAG_A4: i64 = 0x001C;
const ST_TAG_A5: i64 = 0x001D;
const ST_TAG_A6: i64 = 0x001E;
const ST_VS1_2_3: i64 = 0x0080;
const ST_VS15: i64 = 0x4000;
const ST_VS16: i64 = 0x8000;

// The bits of the state layout.
const MASK_VS16: i64 = 0x8000;      // the base takes the emoji form
const MASK_VS15: i64 = 0x4000;      // the base takes the text form
const MASK_LIG_KEEP: i64 = 0x2000;  // a set state survives a presentation change
const MASK_TRANSPARENT: i64 = 0x1000; // the state crosses ignorable marks
const MASK_ZWJ: i64 = 0x0400;       // a joiner came after the sequence
const MASK_VS1_2_3: i64 = 0x0080;   // the base takes the narrow form

// The width of one code point in columns: 0, 1, 2 or 3. A control
// character, a surrogate and a value outside U+0000 to U+10FFFF give -1.
fn char_width(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return -1; }
    if cp >= 0xD800 && cp <= 0xDFFF { return -1; }
    if cp < 0x20 || (cp >= 0x7F && cp <= 0x9F) { return -1; }
    let i = last_at_or_below(CW_START[..], cp);
    if i < 0 { return 1; }
    return CW_VAL[i];
}

// True when cp sits in the sorted range table.
fn width_in_table(starts: const i64[:], ends: const i64[:], cp: i64) -> bool {
    return run_at(starts, ends, cp) >= 0;
}

// True when the code point starts an emoji presentation sequence.
fn width_is_emoji_seq(cp: i64) -> bool {
    return width_in_table(CW_EPS_START[..], CW_EPS_END[..], cp);
}

// True when the code point is an emoji modifier base.
fn width_is_modifier_base(cp: i64) -> bool {
    return width_in_table(CW_EMB_START[..], CW_EMB_END[..], cp);
}

// True when the code point never breaks a joiner sequence.
fn width_is_transparent(cp: i64) -> bool {
    return width_in_table(CW_LT_START[..], CW_LT_END[..], cp);
}

// The state that a plain lookup of the code point gives. The Rust crate
// holds script states for the ligature rules; this package does not
// apply them, so their code points take the default state.
fn width_lookup_state(cp: i64) -> i64 {
    if cp == 0x000A { return ST_LINE_FEED; }
    if cp == 0xFE0F { return ST_VS16; }
    if cp == 0xFE0E { return ST_VS15; }
    if cp == 0xFE01 { return ST_VS1_2_3; }
    if cp >= 0x1F1E6 && cp <= 0x1F1FF { return ST_REGIONAL_INDICATOR; }
    if cp >= 0x1F3FB && cp <= 0x1F3FF { return ST_EMOJI_MODIFIER; }
    if width_in_table(CW_EP_START[..], CW_EP_END[..], cp) { return ST_EMOJI_PRESENTATION; }
    return ST_DEFAULT;
}

// The width step of the walk. It reads one code point and the state of
// the code points to its right, and gives the width to add and the
// state to carry left.
fn width_seq(c: i64, st_in: i64) -> i64, i64 {
    var next = st_in;
    // A variation selector to the right holds the form of its base.
    if (next & MASK_VS16) == MASK_VS16 {
        if width_is_emoji_seq(c) {
            if (next & 0xB000) == 0x9000 {
                return 0, ST_EMOJI_PRESENTATION;
            }
            return 2, ST_EMOJI_PRESENTATION;
        }
        if (next & MASK_LIG_KEEP) == MASK_LIG_KEEP {
            next = next ^ MASK_VS16;
        } else {
            next = ST_DEFAULT;
        }
    }
    if c <= 0xA0 {
        if c == 0x000A { return 1, ST_LINE_FEED; }
        if c == 0x000D && next == ST_LINE_FEED { return 0, ST_DEFAULT; }
        return 1, ST_DEFAULT;
    }
    if next != ST_DEFAULT {
        if c == 0xFE0F {
            // The emoji form joins the state, or starts from it alone.
            if (next & MASK_LIG_KEEP) == MASK_LIG_KEEP
                || (next & 0x9000) == 0x1000 {
                return 0, next | MASK_VS16;
            }
            return 0, ST_VS16;
        }
        if c == 0xFE01 {
            if (next & MASK_LIG_KEEP) == MASK_LIG_KEEP {
                return 0, next | MASK_VS1_2_3;
            }
            return 0, ST_VS1_2_3;
        }
        if c == 0xFE0E {
            if (next & MASK_LIG_KEEP) == MASK_LIG_KEEP {
                return 0, next | MASK_VS15;
            }
            return 0, ST_VS15;
        }
        if (next & MASK_VS15) == MASK_VS15 {
            if width_in_table(CW_TPS_START[..], CW_TPS_END[..], c) {
                return 1, ST_DEFAULT;
            }
            next = next ^ MASK_VS15;
        } else if (next & MASK_VS1_2_3) == MASK_VS1_2_3 {
            if c == 0x2018 || c == 0x2019 || c == 0x201C || c == 0x201D {
                return 2, ST_DEFAULT;
            }
            next = next ^ MASK_VS1_2_3;
        }
        if (next & MASK_TRANSPARENT) == MASK_TRANSPARENT {
            if c == 0x200D {
                return 0, next | MASK_ZWJ;
            }
            if width_is_transparent(c) {
                return 0, next;
            }
        }
        // The sequence rules, in the order of the crate.
        if next == ST_EMOJI_MODIFIER && width_is_modifier_base(c) {
            return 0, ST_EMOJI_PRESENTATION;
        }
        if c >= 0x1F1E6 && c <= 0x1F1FF {
            if next == ST_REGIONAL_INDICATOR || next == ST_SEVERAL_RI {
                return 1, ST_SEVERAL_RI;
            }
            if next == ST_ZWJ_EMOJI { return 1, ST_RI_ZWJ; }
            if next == ST_RI_ZWJ || next == ST_ODD_RI_ZWJ { return -1, ST_EVEN_RI_ZWJ; }
            if next == ST_EVEN_RI_ZWJ { return 3, ST_ODD_RI_ZWJ; }
        }
        if c == 0x200D
            && (next == ST_EMOJI_PRESENTATION || next == ST_SEVERAL_RI
                || next == ST_EVEN_RI_ZWJ || next == ST_ODD_RI_ZWJ
                || next == ST_EMOJI_MODIFIER) {
            return 0, ST_ZWJ_EMOJI;
        }
        if next == ST_ZWJ_EMOJI && c == 0x20E3 { return 0, ST_KEYCAP_ZWJ; }
        if next == ST_VS16_ZWJ_EMOJI && width_is_emoji_seq(c) {
            return 0, ST_EMOJI_PRESENTATION;
        }
        if next == ST_VS16_KEYCAP_ZWJ
            && ((c >= 0x30 && c <= 0x39) || c == 0x23 || c == 0x2A) {
            return 0, ST_EMOJI_PRESENTATION;
        }
        if next == ST_ZWJ_EMOJI && c >= 0x1F3FB && c <= 0x1F3FF {
            return 0, ST_EMOJI_MODIFIER;
        }
        if next == ST_ZWJ_EMOJI && c == 0xE007F { return 0, ST_TAG_END_ZWJ; }
        if c >= 0xE0061 && c <= 0xE007A {
            if next == ST_TAG_END_ZWJ { return 0, ST_TAG_A1; }
            if next == ST_TAG_A1 { return 0, ST_TAG_A2; }
            if next == ST_TAG_A2 { return 0, ST_TAG_A3; }
            if next == ST_TAG_A3 { return 0, ST_TAG_A4; }
            if next == ST_TAG_A4 { return 0, ST_TAG_A5; }
            if next == ST_TAG_A5 { return 0, ST_TAG_A6; }
        }
        if c >= 0xE0030 && c <= 0xE0039 {
            if next == ST_TAG_END_ZWJ || next == ST_TAG_A1 || next == ST_TAG_A2
                || next == ST_TAG_A3 || next == ST_TAG_A4 {
                return 0, ST_TAG_D1;
            }
            if next == ST_TAG_D1 { return 0, ST_TAG_D2; }
            if next == ST_TAG_D2 { return 0, ST_TAG_D3; }
        }
        if c == 0x1F3F4
            && (next == ST_TAG_A3 || next == ST_TAG_A4 || next == ST_TAG_A5
                || next == ST_TAG_A6 || next == ST_TAG_D3) {
            return 0, ST_EMOJI_PRESENTATION;
        }
        if next == ST_ZWJ_EMOJI && width_lookup_state(c) == ST_EMOJI_PRESENTATION {
            return 0, ST_EMOJI_PRESENTATION;
        }
    }
    return char_width(c), width_lookup_state(c);
}

// The width of the text in terminal columns. Returns a fault code and
// the width. A control character counts as 1, and CR LF counts as 1. A
// bad byte gives ERR_BAD_UTF8 and no width.
fn string_width(s: const u8[:]) -> i64, i64 {
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var cps: i64[>..] = [];
    var at: i64 = 0;
    while at < s.len {
        let cp, n = decode_at(s, at);
        if cp < 0 { return ERR_BAD_UTF8, 0; }
        cps.push(cp);
        at += n;
    }
    var sum: i64 = 0;
    var next: i64 = ST_DEFAULT;
    var i = cps.len;
    while i > 0 {
        i -= 1;
        let add, st = width_seq(cps[i], next);
        sum += add;
        next = st;
    }
    return OK, sum;
}
