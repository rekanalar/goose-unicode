// The words and the sentences of a text.
import std;
import unicode from "..";

fn main() {
    let text = "Dr. Who said it's 3.14. Then he left.";
    var at: i64 = 0;
    var words: i64 = 0;
    print("words:");
    while at < text.len {
        let code, end = unicode::word_next(text, at);
        if code != unicode::OK { print("the split failed\n"); return 1; }
        if unicode::is_word_like(text, at, end) {
            print(" ", text[at..end]);
            words += 1;
        }
        at = end;
    }
    print("\ncount: ", words, "\n");
    var starts: i64[>..] = [];
    unicode::sentence_offsets(starts, text);
    for k in 0..starts.len {
        var end = text.len;
        if k + 1 < starts.len { end = starts[k + 1]; }
        print("sentence: ", text[starts[k]..end], "\n");
    }
    return 0;
}
