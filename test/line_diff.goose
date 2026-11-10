// Prints the line break offsets of each line of the input, counted in code
// points, each followed by m for a mandatory break. The last entry has no
// mark. Usage: goose run test/line_diff.goose -- <input file>
// The input holds one text per line, as hex code points separated by
// spaces. The program must start in the package directory.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn main() {
    let argv = args();
    if argv.len < 2 {
        print("usage: line_diff <input file>\n");
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
        var brk: i64[>..] = [];
        let code, off = unicode::line_breaks(brk, bytes[..]);
        if code != unicode::OK { print("fault"); continue; }
        // The code point index of each byte offset.
        var row: u8[>..] = [];
        var cp: i64 = 0;
        var at: i64 = 0;
        for k in 0..brk.len {
            let b = brk[k] / 2;
            while at < b {
                let c, n = unicode::decode_at(bytes[..], at);
                at += n;
                cp += 1;
            }
            if k > 0 { row.push(32); }
            format_int(row, cp, 10, 1, 48);
            if k + 1 < brk.len && (brk[k] % 2) == 1 { row.push(109); }
        }
        print(row);
    }
    return 0;
}
