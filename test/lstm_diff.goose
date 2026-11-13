// The word breaks of the package for a file of texts, in the format of
// the oracles. Usage: goose run test/lstm_diff.goose -- <input file>
// <engine> <mode>
// Each input line holds the code points of one text in hex. The program
// must start in the package directory. The output holds the byte offset
// of each break, one line per text.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn main() {
    let argv = args();
    if argv.len < 4 {
        print("usage: lstm_diff <input file> <engine> <mode>\n");
        return 1;
    }
    let engine = if argv[2] == "model" { unicode::SEG_MODEL } else { unicode::SEG_DICTIONARY };
    let mode = argv[3];
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
        var br: i64[>..] = [];
        var code: i64 = 0;
        if mode == "line" {
            code = unicode::line_breaks_with(br, bytes[..], unicode::LINE_STYLE_NORMAL, engine);
        } else {
            code = unicode::word_offsets_with(br, bytes[..], engine);
        }
        var out: u8[>..] = [];
        for k in 0..br.len {
            if k > 0 { out.push(32); }
            format_int(out, br[k], 10, 0, 32);
        }
        if code != 0 { print("E", code); continue; }
        print(str(out));
    }
    return 0;
}
