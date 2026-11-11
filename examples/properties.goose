// The binary properties answer questions that the general category
// cannot: is a code point white space, a dash or a hex digit?
import std;
import unicode from "..";

// Prints one code point in decimal and the answer for one property.
fn show(cp: i64, prop: i64) {
    var answer = "no";
    if unicode::has_property(cp, prop) { answer = "yes"; }
    print("code point ", cp, " ", unicode::property_name(prop), ": ", answer);
}

fn main() {
    show(0xA0, unicode::PROP_WHITE_SPACE);
    show(0x200B, unicode::PROP_WHITE_SPACE);
    show(0x2014, unicode::PROP_DASH);
    show(0xFF26, unicode::PROP_HEX_DIGIT);
    show(0xAD, unicode::PROP_DEFAULT_IGNORABLE_CODE_POINT);

    // A property can come from its name.
    let p = unicode::property_by_name("alphabetic");
    if p != unicode::PROP_ALPHABETIC {
        print("the name lookup failed\n");
        return 1;
    }
    show(0x4E2D, p);
    return 0;
}
