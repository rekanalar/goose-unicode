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
    bad += fl_check(unicode::UNICODE_VERSION == "17.0.0", "tables version");
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
        if unicode::is_emoji(cp) { got |= 1; }
        if unicode::is_emoji_presentation(cp) { got |= 2; }
        if unicode::is_emoji_modifier(cp) { got |= 4; }
        if unicode::is_emoji_modifier_base(cp) { got |= 8; }
        if unicode::is_emoji_component(cp) { got |= 16; }
        if unicode::is_extended_pictographic(cp) { got |= 32; }
        if unicode::is_id_start(cp) { got |= 64; }
        if unicode::is_id_continue(cp) { got |= 128; }
        if unicode::is_xid_start(cp) { got |= 256; }
        if unicode::is_xid_continue(cp) { got |= 512; }
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

fn run_flags() -> i64 {
    var bad = 0;
    bad += flag_samples();
    bad += flag_range();
    bad += flag_sample_points();
    bad += flag_groups();
    return bad;
}
