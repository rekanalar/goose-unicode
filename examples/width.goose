// The width of a text in terminal columns.
import std;
import unicode from "..";

fn main() {
    // A plain text, an ideograph and a flag.
    let code, w = unicode::string_width("café");
    print("café: ", code, ", ", w, "\n");
    let code2, w2 = unicode::string_width("中文");
    print("中文: ", code2, ", ", w2, "\n");
    // A flag counts as 2. A family of three joined by zero width joiners
    // counts as 2. The keycap of 1 counts as 2.
    let code3, w3 = unicode::string_width("🇩🇪");
    print("flag: ", code3, ", ", w3, "\n");
    var text: u8[>..] = [];
    push_utf8(text, 0x1F468);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F469);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F466);
    let code4, w4 = unicode::string_width(text[..]);
    print("family: ", code4, ", ", w4, "\n");
    var key: u8[>..] = [];
    push_utf8(key, 0x31);
    push_utf8(key, 0xFE0F);
    push_utf8(key, 0x20E3);
    let code5, w5 = unicode::string_width(key[..]);
    print("keycap: ", code5, ", ", w5, "\n");
    // One code point: the heart alone is 1, with the emoji form 2.
    print("heart alone: ", unicode::char_width(0x2764), "\n");
    print("heart emoji: ", unicode::char_width(0x1F497), "\n");
    // A control character is refused alone and counts 1 in a text.
    print("control alone: ", unicode::char_width(0x09), "\n");
    let code6, w6 = unicode::string_width("a\tb");
    print("a tab in a text: ", code6, ", ", w6, "\n");
    return 0;
}
