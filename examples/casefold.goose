// The NFKC case fold is the match key for a caseless and
// compatibility-insensitive compare: two texts that differ only in
// case, in compatibility or in invisible characters fold to the same
// bytes.
import std;
import unicode from "..";

fn same(a: const u8[:], b: const u8[:]) -> bool {
    var fa: u8[>..] = [];
    var fb: u8[>..] = [];
    let c1, _ = unicode::nfkc_casefold(fa, a);
    let c2, _ = unicode::nfkc_casefold(fb, b);
    return c1 == unicode::OK && c2 == unicode::OK && fa[..] == fb[..];
}

fn main() {
    var a: u8[>..] = [];
    push_utf8(a, 'S');
    push_utf8(a, 't');
    push_utf8(a, 'r');
    push_utf8(a, 'a');
    push_utf8(a, 0xDF);
    push_utf8(a, 'e');

    // The sharp s and the two letter spelling.
    if same(a[..], "Strasse") {
        print("the sharp s matches Strasse\n");
    } else {
        print("the fold failed\n");
        return 1;
    }

    // The fullwidth spelling folds to the plain one.
    var wide: u8[>..] = [];
    push_utf8(wide, 0xFF53);
    push_utf8(wide, 0xFF54);
    push_utf8(wide, 0xFF52);
    push_utf8(wide, 0xFF41);
    push_utf8(wide, 0xFF53);
    push_utf8(wide, 0xFF53);
    push_utf8(wide, 0xFF45);
    if same(wide[..], "strasse") {
        print("the fullwidth text matches strasse\n");
    } else {
        print("the wide fold failed\n");
        return 1;
    }

    // A soft hyphen in the middle changes nothing.
    var sneaky: u8[>..] = [];
    append(sneaky, "Str");
    push_utf8(sneaky, 0xAD);
    append(sneaky, "asse");
    if same(sneaky[..], "strasse") {
        print("the hidden soft hyphen changes nothing\n");
    } else {
        print("the soft hyphen broke the match\n");
        return 1;
    }
    return 0;
}

fn append(out: u8[>..]&, s: const u8[:]) {
    for i in 0..s.len { out.push(s[i]); }
}
