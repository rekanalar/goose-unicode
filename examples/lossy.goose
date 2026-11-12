// Decodes bytes with bad parts, reads a byte order mark and walks a text
// one word segment at a time.
import std;
import unicode from "..";

fn show(label: const u8[:], cps: const i64[:]) {
    print(label, " holds ", cps.len, " code points");
    for k in 0..cps.len { print("  ", cps[k]); }
}

fn main() {
    var out: i64[>..] = [];
    // The byte 0x80 is no start of a sequence, so it becomes U+FFFD.
    let a: u8[3] = [0x41, 0x80, 0x42];
    let code, bad = unicode::utf8_decode_lossy(out, a[..]);
    show("41 80 42:", out[..]);
    print("replacements: ", bad);

    // A UTF-16 text with a mark: the call reads the byte order from it.
    let b: u8[6] = [0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69];
    let kind, len = unicode::bom_detect(b[..]);
    print("mark kind ", kind, " length ", len);
    let code2, off2 = unicode::utf16_decode_auto(out, b[..], false);
    show("auto:", out[..]);

    // A walk over words with the cached call.
    let text = "one two three";
    var cache: i64[>..] = [];
    var at: i64 = 0;
    while at < text.len {
        let code3, end = unicode::word_next_cached(cache, text, at);
        print("segment [", at, ",", end, ")");
        at = end;
    }
}
