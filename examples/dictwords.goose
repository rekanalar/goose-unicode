// The words of Thai, Lao, Khmer, Burmese, Chinese and Japanese text. These
// scripts write no spaces between the words. The split uses the word lists
// of the ICU library.
import std;
import unicode from "..";

fn show(text: const u8[:]) -> i64 {
    var starts: i64[>..] = [];
    let code = unicode::word_offsets(starts, text);
    if code != unicode::OK { print("the split failed\n"); return 1; }
    print(text, " ->");
    for k in 0..starts.len {
        var end = text.len;
        if k + 1 < starts.len { end = starts[k + 1]; }
        if unicode::is_word_like(text, starts[k], end) { print(" ", text[starts[k]..end]); }
    }
    print("\n");
    return 0;
}

fn main() {
    var bad: i64 = 0;
    bad += show("ภาษาไทย");
    bad += show("中文测试");
    bad += show("今日は晴れ");
    bad += show("コンニチハ");
    bad += show("中文。中文");
    if bad != 0 { print("an example split failed\n"); }
}
