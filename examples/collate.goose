// The root collation orders names the way a reader expects: accents
// hold the base letter, lower case comes before upper case, and the
// signs of the alphabet sit between the letters.
import std;
import unicode from "..";

fn sign(out: i64[>..]&, a: const u8[:], b: const u8[:]) {
    let code, _ = unicode::compare(out, a, b);
    if code != unicode::OK {
        print("the compare failed\n");
        return;
    }
    if out[0] < 0 {
        print(a, " sorts before ", b, "\n");
    } else if out[0] > 0 {
        print(a, " sorts after ", b, "\n");
    } else {
        print(a, " and ", b, " sort equal\n");
    }
}

fn main() {
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    var out: i64[>..] = [];

    append(a, "amber");
    append(b, "Apple");
    sign(out, a[..], b[..]);

    a.clear();
    push_utf8(a, 'S');
    push_utf8(a, 't');
    push_utf8(a, 'r');
    push_utf8(a, 'a');
    push_utf8(a, 0xDF);
    push_utf8(a, 'e');
    b.clear();
    append(b, "Strasse");
    sign(out, a[..], b[..]);

    a.clear();
    append(a, "cafe");
    push_utf8(a, 0xE9);
    b.clear();
    append(b, "cafe");
    sign(out, a[..], b[..]);

    // The sort key orders the same way as the compare, so a caller can
    // sort a table once and search it many times.
    var k1: i64[>..] = [];
    var k2: i64[>..] = [];
    let c1, _ = unicode::sort_key(k1, a[..]);
    let c2, _ = unicode::sort_key(k2, b[..]);
    if c1 != unicode::OK || c2 != unicode::OK {
        print("the keys failed\n");
        return 1;
    }
    var first: bool = false;
    if k1.len < k2.len { first = true; }
    for i in 0..k1.len {
        if i >= k2.len { break; }
        if k1[i] < k2[i] { first = true; break; }
        if k1[i] > k2[i] { break; }
    }
    if first {
        print("the key of ", a, " orders before the key of ", b, "\n");
    } else {
        print("the key of ", a, " orders after the key of ", b, "\n");
    }
    return 0;
}

// Appends the bytes of one text.
fn append(out: u8[>..]&, s: const u8[:]) {
    for i in 0..s.len { out.push(s[i]); }
}
