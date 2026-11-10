// The line break opportunities of a text, and a greedy wrap.
import std;
import unicode from "..";

fn main() {
    let text = "The quick brown fox, jumps over the lazy-dog.\nEnd";
    var brk: i64[>..] = [];
    let code, off = unicode::line_breaks(brk, text);
    // Each entry holds the byte offset times two, plus one for a mandatory break.
    for k in 0..brk.len {
        print(brk[k] / 2, " ", brk[k] % 2, "\n");
    }

    // A greedy wrap at 16 bytes: break at the last opportunity that fits.
    var start: i64 = 0;
    var last: i64 = 0;
    for k in 0..brk.len {
        let at = brk[k] / 2;
        if at - start > 16 && last > start {
            print(text[start..last], "|\n");
            start = last;
        }
        last = at;
        if brk[k] % 2 == 1 {
            print(text[start..at], "|\n");
            start = at;
        }
    }

    // The class of one code point.
    print(unicode::line_break_class(0x20) == unicode::LB_SP, "\n");   // true
    return 0;
}
