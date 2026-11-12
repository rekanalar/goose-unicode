// The restriction levels grade a text by the scripts that it holds.
// The level tells a caller how far a name may drift from one script
// before a reader may mistake it for another.
import std;
import unicode from "..";

// The level of a text under the profile of the standard.
fn show(name: const u8[:], s: const u8[:]) {
    let level = unicode::restriction_level(s, unicode::PROFILE_ANY);
    print(name, ": ", unicode::restriction_level_name(level), "\n");
}

fn main() {
    // The Latin letters only.
    show("the Latin text", "paypal");

    // The Latin letters and the Cyrillic a.
    var cyrillic: u8[>..] = [];
    push_utf8(cyrillic, 0x61);
    push_utf8(cyrillic, 0x430);
    push_utf8(cyrillic, 0x79);
    push_utf8(cyrillic, 0x70);
    push_utf8(cyrillic, 0x61);
    push_utf8(cyrillic, 0x6C);
    show("the mixed word", cyrillic[..]);

    // The Latin a and the Han ideograph.
    var han: u8[>..] = [];
    push_utf8(han, 0x61);
    push_utf8(han, 0x4E00);
    show("the Latin and the Han", han[..]);

    // The Latin a and the Hiragana letter.
    var hiragana: u8[>..] = [];
    push_utf8(hiragana, 0x61);
    push_utf8(hiragana, 0x3042);
    show("the Latin and the Hiragana", hiragana[..]);

    // The Latin a and the Devanagari letter.
    var devanagari: u8[>..] = [];
    push_utf8(devanagari, 0x61);
    push_utf8(devanagari, 0x915);
    show("the Latin and the Devanagari", devanagari[..]);

    // The mixed script test tells the texts of two scripts apart.
    if unicode::is_mixed_script(cyrillic[..]) {
        print("the mixed word mixes scripts\n");
    }
    if !unicode::is_mixed_script("paypal") {
        print("the Latin text mixes no script\n");
    }

    // The whole script test finds the scripts that hold a twin of the
    // whole text.
    var twins: i64[>..] = [];
    let code, offset = unicode::whole_script_twins(twins, "scope");
    if code == unicode::OK {
        print("the twins of the word scope: ");
        for k in 0..twins.len { print(unicode::script_value_name(twins[k]), " "); }
        print("\n");
    }
    return 0;
}
