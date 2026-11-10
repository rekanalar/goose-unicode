// The title case of a text, and of one code point.
import std;
import unicode from "..";

fn main() {
    var out: u8[>..] = [];
    let code, off = unicode::to_title(out, "the QUICK brown fox, don't stop");
    print(out, "\n");   // The Quick Brown Fox, Don't Stop

    // The first letter of a word takes the title case mapping.
    // A digraph has a form of its own, and the sharp s gives two letters.
    unicode::to_title(out, "ǆ straße");
    print(out, "\n");   // ǅ Straße

    // One code point gives its title case mapping.
    unicode::titlecase_cp(out, 0xDF);
    print(out, "\n");   // Ss
    return 0;
}
