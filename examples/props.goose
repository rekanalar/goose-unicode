// The property calls of the unicode package. Run with:
// goose run examples/props.goose

import std;
import unicode from "..";

fn main() {
    // The script and the width of a code point.
    print("script of A: ", unicode::script_name('A'), "\n");
    print("script of a han letter: ", unicode::script_name(0x6F22), "\n");
    print("width of a han letter: ", unicode::width_name(0x6F22), "\n");

    // The bidirectional class and the mirror partner.
    print("class of a hebrew letter: ", unicode::bidi_class_name(0x05D0), "\n");
    print("partner of the left bracket: ", unicode::mirror_of('('), "\n");
    print("is the left bracket mirrored: ", unicode::mirrored('('), "\n");

    // The numeric value of a code point.
    let num, den = unicode::numeric_value(0xBD);
    print("value of one half: ", num, "/", den, "\n");

    // The name of a code point.
    print("name of A: ", unicode::name('A'), "\n");
    print("name of a hangul syllable: ", unicode::name(0xAC00), "\n");

    // The full case mappings.
    var out: u8[>..] = [];
    let code, offset = unicode::to_upper_full(out, "Straße");
    if code == unicode::OK {
        print("upper of the sharp s: ", out, "\n");
    }
    let code2, offset2 = unicode::to_lower_full(out, "ΟΟΣ");
    if code2 == unicode::OK {
        print("lower of a greek word: ", out, "\n");
    }
    return 0;
}
