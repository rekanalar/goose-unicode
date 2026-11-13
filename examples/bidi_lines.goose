// A text renderer cuts a text into paragraphs, cuts each paragraph into
// lines and writes each line in the order that a reader sees it.
// The resolution runs once for the whole text. Each line then costs
// its own length.
import std;
import unicode from "..";

fn main() {
    // Two paragraphs: a Latin one with a Hebrew word, then an Arabic one.
    // The text ends with white space before the line break.
    var text: u8[>..] = [];
    let cps = [0x61, 0x20, 0x5D0, 0x5D1, 0x5D2, 0x20, 0x28, 0x62, 0x29, 0x0A,
               0x627, 0x644, 0x20, 0x31, 0x32, 0x20];
    for k in 0..cps.len { push_utf8(text, cps[k]); }

    // The paragraphs: the start, the limit and the level of each one.
    var pars: i64[>..] = [];
    let code, _ = unicode::bidi_paragraphs(pars, text[..], unicode::BIDI_DIR_AUTO);
    if code != unicode::OK { print("fault ", code, "\n"); return 1; }
    for p in 0..pars.len / 3 {
        print("paragraph ", p, ": ", pars[p * 3], " to ", pars[p * 3 + 1],
              ", level ", pars[p * 3 + 2], "\n");
    }

    // Resolve once, then cut lines.
    var res: i64[>..] = [];
    var offs: i64[>..] = [];
    unicode::bidi_resolve(res, offs, text[..], unicode::BIDI_DIR_AUTO);
    for p in 0..pars.len / 3 {
        let start = pars[p * 3];
        let limit = pars[p * 3 + 1];

        // Rule L1: the levels of the line.
        var levels: i64[>..] = [];
        unicode::bidi_line_levels_from(levels, res[..], start, limit);
        print("levels:");
        for k in 0..levels.len { print(" ", levels[k]); }
        print("\n");

        // Rule L2: the visual order. The indexes count from the text.
        var order: i64[>..] = [];
        unicode::bidi_line_order_from(order, res[..], start, limit);
        print("order:");
        for k in 0..order.len { print(" ", order[k]); }
        print("\n");

        // Rules L3 and L4 with the write call. The options mirror the
        // brackets of a right to left run, keep the marks after their
        // base and drop the bidi controls.
        var visual: u8[>..] = [];
        let flags = unicode::BIDI_DO_MIRRORING | unicode::BIDI_KEEP_BASE_COMBINING
            | unicode::BIDI_REMOVE_CONTROLS;
        unicode::bidi_reorder_from(visual, text[..], res[..], offs[..], start, limit, flags);
        print("visual: ", visual[..], "\n");
    }

    // A line that crosses a paragraph is a fault.
    var bad: i64[>..] = [];
    let c = unicode::bidi_line_levels_from(bad, res[..], 5, 12);
    print("a line across two paragraphs gives the fault ", c, "\n");
    return 0;
}
