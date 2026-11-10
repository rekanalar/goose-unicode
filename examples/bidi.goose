// The embedding levels and the visual order of a mixed text.
import std;
import unicode from "..";

fn main() {
    // Latin text with a Hebrew word in the middle.
    let text = "ab אב cd";
    var levels: i64[>..] = [];
    let code, para = unicode::bidi_levels(levels, text, unicode::BIDI_DIR_AUTO);
    print("fault: ", code, ", paragraph level: ", para, "\n");
    print("levels:");
    for k in 0..levels.len { print(" ", levels[k]); }
    print("\n");
    // The order in which a reader sees the code points, left to right.
    var order: i64[>..] = [];
    let c2 = unicode::bidi_order(order, levels[..]);
    print("fault: ", c2, "\norder:");
    for k in 0..order.len { print(" ", order[k]); }
    print("\n");
    return 0;
}
