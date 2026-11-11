// Prints the case mapping of each line of the input, as hex code points.
// Usage: goose run test/locale_diff.goose -- <locale> <upper|lower|title> <input file>
// The locale is the number of a LOCALE_ constant. The input holds one text
// per line, as hex code points separated by spaces. The program must start
// in the package directory.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn main() {
    let argv = args();
    if argv.len < 4 {
        print("usage: locale_diff <locale> <upper|lower|title> <input file>\n");
        return 1;
    }
    let locale = bidiutil::hexval(argv[1]);
    let kind = argv[2];
    var text: u8[>..] = [];
    if !read_file(argv[3], text) {
        print("FAIL: cannot read the input file\n");
        return 1;
    }
    var out: u8[>..] = [];
    var cps: i64[>..] = [];
    var bytes: u8[>..] = [];
    var row: u8[>..] = [];
    var hex: u8[>..] = [];
    var all: u8[>..] = [];
    for line in split(text[..], '\n') {
        if line.len == 0 { continue; }
        bytes.clear();
        for w in split(line, ' ') {
            let q = trim(w);
            if q.len == 0 { continue; }
            unicode::utf8_encode(bytes, bidiutil::hexval(q));
        }
        var code: i64 = 0;
        var off: i64 = 0;
        if kind == "upper" {
            code, off = unicode::to_upper_locale(out, bytes[..], locale);
        } else if kind == "lower" {
            code, off = unicode::to_lower_locale(out, bytes[..], locale);
        } else {
            code, off = unicode::to_title_locale(out, bytes[..], locale);
        }
        row.clear();
        if code != unicode::OK {
            row.append("fault");
        } else {
            cps.clear();
            unicode::utf8_decode(cps, out[..]);
            for k in 0..cps.len {
                if k > 0 { row.push(32); }
                hex.clear();
                format_int(hex, cps[k], 16, 4, 48);
                row.append(hex[..]);
            }
        }
        row.push(10);
        all.append(row[..]);
    }
    print(all);
    return 0;
}
