// The UTF-32 form of a text.
import std;
import unicode from "..";

fn main() {
    // The text "Hi" and a face, which takes four bytes here.
    var text: u8[>..] = [];
    push_utf8(text, 0x48);
    push_utf8(text, 0x69);
    push_utf8(text, 0x1F600);
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, text[..]);
    var le: u8[>..] = [];
    let code = unicode::utf32_encode(le, cps[..], false);
    if code != unicode::OK { print("the encode failed\n"); return 1; }
    print("little endian: ");
    for k in 0..le.len { print(le[k], " "); }
    print("\n");
    var be: u8[>..] = [];
    unicode::utf32_encode(be, cps[..], true);
    print("big endian: ");
    for k in 0..be.len { print(be[k], " "); }
    print("\n");
    var back: i64[>..] = [];
    let code2, off2 = unicode::utf32_decode(back, le[..], false);
    if code2 != unicode::OK { print("the decode failed\n"); return 1; }
    print("code points: ");
    for k in 0..back.len { print(back[k], " "); }
    print("\n");
    // A value above U+10FFFF is a fault.
    var bad: u8[>..] = [];
    bad.push(0x01);
    bad.push(0x00);
    bad.push(0x11);
    bad.push(0x00);
    var none: i64[>..] = [];
    let code3, off3 = unicode::utf32_decode(none, bad[..], false);
    print("fault code: ", code3, " at byte ", off3, "\n");
    return 0;
}
