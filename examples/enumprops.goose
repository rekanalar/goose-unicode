// The enumerated properties of a code point: the position of the value in
// the alias file of the standard, and the short name of the value.
import std;
import unicode from "..";

fn show(cp: i64) {
    print("code point ", cp, "\n");
    print("  grapheme break      ", unicode::grapheme_break_name(cp), "\n");
    print("  word break          ", unicode::word_break_name(cp), "\n");
    print("  sentence break      ", unicode::sentence_break_name(cp), "\n");
    print("  hangul syllable     ", unicode::hangul_syllable_type_name(cp), "\n");
    print("  indic syllabic      ", unicode::indic_syllabic_category_name(cp), "\n");
    print("  indic positional    ", unicode::indic_positional_category_name(cp), "\n");
    print("  vertical            ", unicode::vertical_orientation_name(cp), "\n");
}

fn main() {
    show(0x41);      // a Latin capital letter
    show(0x94D);     // the Devanagari virama
    show(0xAC00);    // a Hangul syllable
    show(0x4E00);    // a Han ideograph
}
