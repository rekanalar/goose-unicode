// Two spellings of one name must compare equal after the compose.
import std;
import unicode from "..";

fn main() {
    // The name in two spellings: one with a mark, one with a precomposed
    // letter.
    var typed: u8[>..] = [];
    push_utf8(typed, 0x63);
    push_utf8(typed, 0x61);
    push_utf8(typed, 0x66);
    push_utf8(typed, 0x65);
    push_utf8(typed, 0x301);

    var pasted: u8[>..] = [];
    push_utf8(pasted, 0x63);
    push_utf8(pasted, 0x61);
    push_utf8(pasted, 0x66);
    push_utf8(pasted, 0xE9);

    var a: u8[>..] = [];
    var b: u8[>..] = [];
    let code = unicode::normalize(a, unicode::FORM_NFC, typed[..]);
    if code != unicode::OK { print("the first name failed\n"); return 1; }
    let code2 = unicode::normalize(b, unicode::FORM_NFC, pasted[..]);
    if code2 != unicode::OK { print("the second name failed\n"); return 1; }

    print("typed:  ", typed, "\n");
    print("pasted: ", pasted, "\n");
    print("composed: ", a, "\n");
    if a[..] != b[..] {
        print("the two spellings differ\n");
        return 1;
    }
    print("the two spellings are equal\n");
    return 0;
}
