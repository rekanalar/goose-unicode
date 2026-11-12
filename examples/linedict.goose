// The line break opportunities of Thai, Khmer, Lao and Burmese text.
// These scripts write no spaces between the words. The line break call
// puts an opportunity at each word end, with the word lists of the ICU
// library.
import std;
import unicode from "..";

// Prints the pieces of the text between two break opportunities.
fn show(text: const u8[:]) -> i64 {
    var brk: i64[>..] = [];
    let code, off = unicode::line_breaks(brk, text);
    if code != unicode::OK { print("the line break call failed\n"); return 1; }
    print(text, " ->");
    var start: i64 = 0;
    for k in 0..brk.len {
        let at = brk[k] / 2;
        print(" ", text[start..at], "|");
        start = at;
    }
    print("\n");
    return 0;
}

fn main() {
    var bad: i64 = 0;
    bad += show("ภาษาไทย");
    bad += show("ឃាំ");
    bad += show("ລາວດີ");
    bad += show("Hello ภาษาไทย");
    return bad;
}
