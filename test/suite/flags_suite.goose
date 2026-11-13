// Tests for the group, the emoji and the identifier calls.
namespace suite;

import std;
import unicode from "../..";

fn fl_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: flags ", name, "\n"); return 1; }
    return 0;
}

fn flag_samples() -> i64 {
    var bad = 0;
    bad += fl_check(unicode::is_emoji(0x1F600), "grinning face is emoji");
    bad += fl_check(unicode::is_emoji_presentation(0x1F600), "grinning face presentation");
    bad += fl_check(!unicode::is_emoji(0x61), "a is no emoji");
    bad += fl_check(unicode::is_emoji(0x23) && unicode::is_emoji_component(0x23), "number sign");
    bad += fl_check(!unicode::is_emoji_presentation(0x23), "number sign presentation");
    // The zero width joiner is a component and no emoji.
    bad += fl_check(unicode::is_emoji_component(0x200D) && !unicode::is_emoji(0x200D), "joiner");
    bad += fl_check(unicode::is_emoji_modifier(0x1F3FB), "skin tone modifier");
    bad += fl_check(unicode::is_emoji_modifier_base(0x1F44D), "thumbs up base");
    bad += fl_check(unicode::is_extended_pictographic(0xA9), "copyright sign");
    bad += fl_check(unicode::is_id_start(0x61) && unicode::is_xid_start(0x61), "a starts an identifier");
    bad += fl_check(!unicode::is_id_start(0x31) && unicode::is_id_continue(0x31), "digit continues");
    bad += fl_check(unicode::is_id_continue(0x5F) && !unicode::is_id_start(0x5F), "underscore");
    bad += fl_check(unicode::is_id_continue(0x300), "combining mark continues");
    bad += fl_check(!unicode::is_id_start(0x20) && !unicode::is_id_continue(0x2D), "space and hyphen");
    // The tables come from Unicode 17.0, as the Node and Go oracles hold.
    bad += fl_check(unicode::UNICODE_VERSION == "18.0.0", "tables version");
    bad += fl_check(unicode::is_zwj(0x200D) && !unicode::is_zwj(0x200C), "joiner test");
    bad += fl_check(unicode::is_emoji_presentation_selector(0xFE0F), "selector 16");
    bad += fl_check(unicode::is_text_presentation_selector(0xFE0E), "selector 15");
    bad += fl_check(unicode::is_regional_indicator(0x1F1E6) && unicode::is_regional_indicator(0x1F1FF)
        && !unicode::is_regional_indicator(0x1F1E5) && !unicode::is_regional_indicator(0x1F200), "regional");
    bad += fl_check(unicode::is_tag_character(0xE0020) && unicode::is_tag_character(0xE007F)
        && !unicode::is_tag_character(0xE001F) && !unicode::is_tag_character(0xE0080), "tag");
    bad += fl_check(unicode::is_letter_cased(0x41) && unicode::is_letter_cased(0x61)
        && unicode::is_letter_cased(0x1C5) && !unicode::is_letter_cased(0x1C0)
        && !unicode::is_letter_cased(0x31), "cased letter");
    bad += fl_check(unicode::category_group(0x61) == unicode::GROUP_LETTER, "group letter");
    bad += fl_check(unicode::category_group(0x300) == unicode::GROUP_MARK, "group mark");
    bad += fl_check(unicode::category_group(0x31) == unicode::GROUP_NUMBER, "group number");
    bad += fl_check(unicode::category_group(0x21) == unicode::GROUP_PUNCTUATION, "group punctuation");
    bad += fl_check(unicode::category_group(0x24) == unicode::GROUP_SYMBOL, "group symbol");
    bad += fl_check(unicode::category_group(0x20) == unicode::GROUP_SEPARATOR, "group separator");
    bad += fl_check(unicode::category_group(0x0) == unicode::GROUP_OTHER, "group control");
    return bad;
}

// A value outside U+0000 to U+10FFFF gives false and the other group.
fn flag_range() -> i64 {
    var bad = 0;
    bad += fl_check(!unicode::is_emoji(-1) && !unicode::is_emoji(0x110000), "emoji outside");
    bad += fl_check(!unicode::is_id_start(-1) && !unicode::is_xid_continue(0x110000), "identifier outside");
    bad += fl_check(!unicode::is_letter_cased(-1) && !unicode::is_letter_cased(0x110000), "cased outside");
    bad += fl_check(unicode::category_group(-1) == unicode::GROUP_OTHER
        && unicode::category_group(0x110000) == unicode::GROUP_OTHER, "group outside");
    bad += fl_check(!unicode::is_zwj(-1) && !unicode::is_tag_character(-1), "fixed outside");
    return bad;
}

// The mask of each sample point, from Node, against the ten calls.
fn flag_sample_points() -> i64 {
    var bad = 0;
    for k in 0..FL_CP.len {
        let cp = FL_CP[k];
        let m = FL_MASK[k];
        var got = 0;
        for p in 0..unicode::PROP_COUNT {
            if unicode::has_property(cp, p) { got |= 1 << p; }
        }
        // The ten older calls read the same bits.
        var old = 0;
        if unicode::is_emoji(cp) { old |= 1; }
        if unicode::is_emoji_presentation(cp) { old |= 2; }
        if unicode::is_emoji_modifier(cp) { old |= 4; }
        if unicode::is_emoji_modifier_base(cp) { old |= 8; }
        if unicode::is_emoji_component(cp) { old |= 16; }
        if unicode::is_extended_pictographic(cp) { old |= 32; }
        if unicode::is_id_start(cp) { old |= 64; }
        if unicode::is_id_continue(cp) { old |= 128; }
        if unicode::is_xid_start(cp) { old |= 256; }
        if unicode::is_xid_continue(cp) { old |= 512; }
        if old != (got & 1023) {
            print("FAIL: the old calls differ at U+", cp, "\n");
            bad += 1;
        }
        if got != m {
            print("FAIL: flags of U+", cp, " are ", got, ", want ", m, "\n");
            bad += 1;
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The group of every code point, against the runs of Go.
fn flag_groups() -> i64 {
    var bad = 0;
    var next: i64 = 0;
    for k in 0..GP_START.len {
        if GP_START[k] != next {
            print("FAIL: the group runs leave a gap at ", next, "\n");
            return 1;
        }
        for cp in GP_START[k]..GP_END[k] + 1 {
            if unicode::category_group(cp) != GP_VAL[k] {
                print("FAIL: group of U+", cp, " differs\n");
                bad += 1;
                if bad > 5 { return bad; }
            }
        }
        next = GP_END[k] + 1;
    }
    return bad;
}

// Well known code points for the binary properties.
fn prop_samples() -> i64 {
    var bad = 0;
    bad += fl_check(unicode::has_property(0x20, unicode::PROP_WHITE_SPACE), "space is white space");
    bad += fl_check(unicode::has_property(0xA0, unicode::PROP_WHITE_SPACE), "no break space");
    bad += fl_check(!unicode::has_property(0x200B, unicode::PROP_WHITE_SPACE), "zero width space");
    bad += fl_check(unicode::has_property(0x61, unicode::PROP_ALPHABETIC)
        && unicode::has_property(0x61, unicode::PROP_LOWERCASE)
        && !unicode::has_property(0x61, unicode::PROP_UPPERCASE), "a");
    bad += fl_check(unicode::has_property(0x41, unicode::PROP_UPPERCASE)
        && unicode::has_property(0x41, unicode::PROP_CASED), "A");
    bad += fl_check(unicode::has_property(0x2D, unicode::PROP_DASH)
        && unicode::has_property(0x2014, unicode::PROP_DASH), "dashes");
    bad += fl_check(unicode::has_property(0x66, unicode::PROP_HEX_DIGIT)
        && unicode::has_property(0x66, unicode::PROP_ASCII_HEX_DIGIT)
        && unicode::has_property(0xFF26, unicode::PROP_HEX_DIGIT)
        && !unicode::has_property(0xFF26, unicode::PROP_ASCII_HEX_DIGIT), "hex digits");
    bad += fl_check(unicode::has_property(0xAD, unicode::PROP_DEFAULT_IGNORABLE_CODE_POINT), "soft hyphen");
    bad += fl_check(unicode::has_property(0xFFFF, unicode::PROP_NONCHARACTER_CODE_POINT), "noncharacter");
    bad += fl_check(unicode::has_property(0x4E00, unicode::PROP_IDEOGRAPHIC)
        && unicode::has_property(0x4E00, unicode::PROP_UNIFIED_IDEOGRAPH), "han");
    bad += fl_check(unicode::has_property(0x22, unicode::PROP_QUOTATION_MARK), "quote");
    bad += fl_check(unicode::has_property(0x69, unicode::PROP_SOFT_DOTTED), "i");
    bad += fl_check(unicode::has_property(0x200D, unicode::PROP_JOIN_CONTROL), "joiner");
    bad += fl_check(unicode::has_property(0x300, unicode::PROP_GRAPHEME_EXTEND)
        && !unicode::has_property(0x300, unicode::PROP_GRAPHEME_BASE), "grave accent");
    bad += fl_check(unicode::has_property(0x2B, unicode::PROP_MATH), "plus");
    bad += fl_check(unicode::has_property(0x21, unicode::PROP_TERMINAL_PUNCTUATION)
        && unicode::has_property(0x2E, unicode::PROP_SENTENCE_TERMINAL), "terminators");
    bad += fl_check(unicode::has_property(0x2FFE, unicode::PROP_IDS_UNARY_OPERATOR), "ids unary");
    // The names.
    bad += fl_check(unicode::property_name(unicode::PROP_WHITE_SPACE) == "White_Space", "name");
    bad += fl_check(unicode::property_name(unicode::PROP_EMOJI) == "Emoji", "first name");
    bad += fl_check(unicode::property_name(unicode::PROP_COUNT - 1) == "ID_Compat_Math_Continue", "last name");
    bad += fl_check(unicode::property_name(-1).len == 0 && unicode::property_name(unicode::PROP_COUNT).len == 0, "no name");
    for p in 0..unicode::PROP_COUNT {
        bad += fl_check(unicode::property_by_name(unicode::property_name(p)) == p, "name round trip");
    }
    bad += fl_check(unicode::property_by_name("white_space") == unicode::PROP_WHITE_SPACE, "name case");
    bad += fl_check(unicode::property_by_name("Whitespace") == -1 && unicode::property_by_name("") == -1, "bad name");
    bad += fl_check(unicode::property_by_name("White_Space_Extra_Extra_Extra_Extra") == -1, "long name");
    // A value outside the range and a value that is no property give false.
    bad += fl_check(!unicode::has_property(-1, unicode::PROP_ALPHABETIC)
        && !unicode::has_property(0x110000, unicode::PROP_ALPHABETIC), "outside");
    bad += fl_check(!unicode::has_property(0x61, -1) && !unicode::has_property(0x61, unicode::PROP_COUNT)
        && !unicode::has_property(0x61, 63) && !unicode::has_property(0x61, 100), "no property");
    // A lone surrogate holds no property.
    var any = false;
    for p in 0..unicode::PROP_COUNT {
        if unicode::has_property(0xD800, p) { any = true; }
    }
    bad += fl_check(!any, "surrogate");
    return bad;
}

fn run_flags() -> i64 {
    var bad = 0;
    if want("flags", "prop_samples") { bad += prop_samples(); }
    if want("flags", "flag_samples") { bad += flag_samples(); }
    if want("flags", "flag_range") { bad += flag_range(); }
    if want("flags", "flag_sample_points") { bad += flag_sample_points(); }
    if want("flags", "flag_groups") { bad += flag_groups(); }
    return bad;
}
