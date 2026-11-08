// The number of characters that a user sees in a text.
import std;
import unicode from "..";

fn main() {
    // A text with a flag, an accented letter, a family and plain text.
    var text: u8[>..] = [];
    push_utf8(text, 0x48);
    push_utf8(text, 0x69);
    text.push(0x20);
    // The flag of two regional indicators.
    push_utf8(text, 0x1F1E6);
    push_utf8(text, 0x1F1E7);
    text.push(0x20);
    // A letter and a mark.
    push_utf8(text, 0x65);
    push_utf8(text, 0x301);
    text.push(0x20);
    // A family of four people.
    push_utf8(text, 0x1F468);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F469);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F466);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F467);

    let code, count = unicode::grapheme_count(text[..]);
    if code != unicode::OK { print("the count failed\n"); return 1; }
    print("bytes: ", text.len, "\n");
    print("clusters: ", count, "\n");

    var offsets: i64[>..] = [];
    unicode::grapheme_offsets(offsets, text[..]);
    for k in 0..offsets.len {
        print("cluster ", k, " at byte ", offsets[k], "\n");
    }
    return 0;
}
