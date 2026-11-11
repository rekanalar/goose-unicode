// The confusable test tells two identifiers apart when they read the
// same: a Cyrillic letter next to a Latin one, or an m that reads
// like rn.
import std;
import unicode from "..";

fn show(name: const u8[:], a: const u8[:], b: const u8[:]) {
    print(name, ": ");
    if unicode::confusable(a, b) {
        print("the two read the same\n");
    } else {
        print("the two differ\n");
    }
}

fn main() {
    // The Latin abc and the Cyrillic a with a Latin bc.
    var latin: u8[>..] = [];
    push_utf8(latin, 0x61);
    push_utf8(latin, 0x62);
    push_utf8(latin, 0x63);

    var cyrillic: u8[>..] = [];
    push_utf8(cyrillic, 0x430);
    push_utf8(cyrillic, 0x62);
    push_utf8(cyrillic, 0x63);

    show("the cyrillic a", cyrillic[..], latin[..]);

    // The m and the rn.
    var m: u8[>..] = [];
    push_utf8(m, 0x6D);
    show("the m", m[..], "rn");

    // The skeleton of a text is the key of the compare.
    var out: u8[>..] = [];
    let code, offset = unicode::skeleton(out, cyrillic[..]);
    if code == unicode::OK {
        print("the skeleton of the cyrillic text: ");
        for k in 0..out.len { print(out[k]); }
        print("\n");
    }
    return 0;
}
