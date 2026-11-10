// The group, the emoji and the identifier properties of code points.
import std;
import unicode from "..";

fn main() {
    // A letter, a digit and a mark. The group of each is a constant.
    print(unicode::category_group(0x61), unicode::category_group(0x31), unicode::category_group(0x300), "\n");   // 021
    // The grinning face is an emoji. The zero width joiner is a component
    // of emoji sequences and no emoji.
    print(unicode::is_emoji(0x1F600), unicode::is_emoji(0x200D), unicode::is_emoji_component(0x200D), "\n");   // truefalsetrue
    // An identifier starts with a letter and continues with a digit.
    print(unicode::is_id_start(0x61), unicode::is_id_start(0x31), unicode::is_id_continue(0x31), "\n");   // truefalsetrue
    return 0;
}
