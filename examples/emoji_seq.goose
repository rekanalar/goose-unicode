// The emoji sequences: the kind of a whole text and the scan of a text.
import std;
import unicode from "..";

fn main() {
    // The flag of Japan is one flag sequence. The mask is the flag bit, 8.
    print(unicode::emoji_sequence_kinds("🇯🇵"), "\n");   // 8
    // A keycap needs the selector U+FE0F. Without it the text is no keycap.
    print(unicode::is_emoji_sequence("1️⃣", unicode::EMOJI_SEQ_KEYCAP), unicode::is_emoji_sequence("1⃣", unicode::EMOJI_SEQ_KEYCAP), "\n");   // truefalse
    // Two flags in a row are not one sequence.
    print(unicode::is_rgi_emoji("🇯🇵🇺🇸"), "\n");   // false
    // The scan gives the start and the end of each sequence, in bytes.
    var out: i64[>..] = [];
    let code, _ = unicode::emoji_sequences(out, "a🇯🇵🇺🇸b😀x©️");
    print(code, " ", out.len / 2, " pairs\n");   // 0 4 pairs
    for k in 0..out.len / 2 {
        print(out[2 * k], " ", out[2 * k + 1], "\n");   // 1 9, 9 17, 18 22, 23 28
    }
    return 0;
}
