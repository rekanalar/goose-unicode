// The numeric type, the decomposition, the joining and the bracket properties.
import std;
import unicode from "..";

fn main() {
    // The decimal and digit values: a superscript two is a digit and no decimal.
    print(unicode::decimal_value(0x665), " ", unicode::digit_value(0xB2), " ", unicode::decimal_value(0xB2), "\n");   // 5 2 -1
    print(unicode::numeric_type_name(0xBD), "\n");                  // Numeric

    // The one level mapping of a ligature and its type.
    var m: i64[>..] = [];
    unicode::decomposition(m, 0xFB01);
    print(m, " ", unicode::decomposition_type_name(0xFB01), "\n");  // [102, 105] Compat

    // The joining type and group of an Arabic letter.
    print(unicode::joining_type_name(0x628), " ", unicode::joining_group_name(0x628), "\n");   // Dual_Joining Beh

    // The partner of a bracket.
    print(unicode::bidi_paired_bracket(0x28) == 0x29, "\n");        // true
    return 0;
}
