// The sentences of a locale and the breaks of the three line styles.
// The sentence call holds the break after an abbreviation, so "Mr. Smith"
// stays one sentence. The line styles are the strict, the normal and the
// loose style of the ICU library.
import std;
import unicode from "..";

// Prints the start of every sentence of the text.
fn sentences(text: const u8[:], locale: i64) -> i64 {
    var out: i64[>..] = [];
    let code = unicode::sentence_offsets_locale(out, text, locale);
    if code != unicode::OK { print("the sentence call failed\n"); return 1; }
    print("the starts:");
    for k in 0..out.len { print(" ", out[k]); }
    print("\n");
    return 0;
}

// Prints the breaks of the text for the three styles.
fn styles(text: const u8[:]) -> i64 {
    var brk: i64[>..] = [];
    for style in 0..3 {
        brk.clear();
        let code, off = unicode::line_breaks_style(brk, text, style);
        if code != unicode::OK { print("the line break call failed\n"); return 1; }
        print("the breaks:");
        for k in 0..brk.len { print(" ", brk[k] >> 1); }
        print("\n");
    }
    return 0;
}

fn main() {
    var bad: i64 = 0;
    let text = "Mr. Smith went home. Dr. Jones stayed.";
    print("the locale of a tag: ", unicode::sentence_locale_of("en"), "\n");
    bad += sentences(text, unicode::SENT_LOCALE_ROOT);
    bad += sentences(text, unicode::SENT_LOCALE_EN);
    bad += styles("ヽヾー々〻");
    return bad;
}
