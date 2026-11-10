// The script extensions, the block and the age of a code point.
import std;
import unicode from "..";

fn main() {
    // The prolonged sound mark belongs to two scripts.
    var out: i64[>..] = [];
    unicode::script_extensions(out, 0x30FC);
    for k in 0..out.len { print(unicode::script_value_name(out[k]), "\n"); }   // Hiragana, then Katakana

    print(unicode::block_name(0xAC00), "\n");   // Hangul Syllables
    let major, minor = unicode::age(0x1F600);
    print(major, ".", minor, "\n");             // 6.1
    return 0;
}
