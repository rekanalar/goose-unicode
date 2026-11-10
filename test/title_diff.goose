// Prints the title case of each line of the input, as hex code points.
// Usage: goose run test/title_diff.goose -- <input file>
// The input holds one text per line, as hex code points separated by
// spaces. The program must start in the package directory.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn main() {
    let argv = args();
    if argv.len < 2 {
        print("usage: title_diff <input file>\n");
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
            unicode::utf8_encode(bytes, bidiutil::hexval(q));
        }
        var out: u8[>..] = [];
        let code, off = unicode::to_title(out, bytes[..]);
        if code != unicode::OK { print("fault"); continue; }
        var cps: i64[>..] = [];
        unicode::utf8_decode(cps, out[..]);
        var row: u8[>..] = [];
        for k in 0..cps.len {
            if k > 0 { row.push(32); }
            var hex: u8[>..] = [];
            format_int(hex, cps[k], 16, 4, 48);
            row.append(hex[..]);
        }
        print(row);
    }
    return 0;
}
