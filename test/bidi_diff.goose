// Prints the levels and the visual order of each line of the input.
// Usage: goose run test/bidi_diff.goose -- <input file>
// The input holds one text per line, as hex code points separated by
// spaces. The program must start in the package directory.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn hexval(s: const u8[:]) -> i64 { return bidiutil::hexval(s); }

fn main() {
    let argv = args();
    if argv.len < 2 {
        print("usage: bidi_diff <input file>\n");
        return 1;
    }
    var text: u8[>..] = [];
    if !read_file(argv[1], text) {
        print("FAIL: cannot read the input file\n");
        return 1;
    }
    for line in split(text[..], '\n') {
        if line.len == 0 { continue; }
        var bytes: u8[>..] = [];
        for w in split(line, ' ') {
            let q = trim(w);
            if q.len == 0 { continue; }
            unicode::utf8_encode(bytes, hexval(q));
        }
        var lv: i64[>..] = [];
        let code, pl = unicode::bidi_levels(lv, bytes[..], unicode::BIDI_DIR_AUTO);
        if code != unicode::OK { print("fault"); continue; }
        var line: u8[>..] = [];
        for k in 0..lv.len {
            if k > 0 { line.push(32); }
            format_int(line, lv[k], 10, 0, 32);
        }
        print(line);
        var ord: i64[>..] = [];
        let c2 = unicode::bidi_order(ord, lv[..]);
        if c2 != unicode::OK { print("fault"); continue; }
        var line2: u8[>..] = [];
        for k in 0..ord.len {
            if k > 0 { line2.push(32); }
            format_int(line2, ord[k], 10, 0, 32);
        }
        print(line2);
    }
    return 0;
}
