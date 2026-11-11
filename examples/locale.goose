// The locale aware case mapping: the Turkish and Lithuanian rules.
import std;
import unicode from "..";

fn main() {
    var out: u8[>..] = [];

    // Turkish: the dotless i is a letter of its own.
    unicode::to_upper_locale(out, "iı istanbul", unicode::LOCALE_TR);
    print(out[..], "\n");
    unicode::to_lower_locale(out, "ISPARTA İZMİR", unicode::LOCALE_TR);
    print(out[..], "\n");
    unicode::to_title_locale(out, "istanbul ığdır", unicode::LOCALE_TR);
    print(out[..], "\n");

    // Azerbaijani holds the same rules.
    unicode::to_upper_locale(out, "iı", unicode::LOCALE_AZ);
    print(out[..], "\n");

    // Lithuanian: the small i and j keep their dot under an accent, and
    // the upper case drops the dot.
    var text: u8[>..] = [];
    for cp in [0x49, 0x300] { unicode::utf8_encode(text, cp); }        // Ì
    unicode::to_lower_locale(out, text[..], unicode::LOCALE_LT);
    print(out[..], "\n");
    text.clear();
    for cp in [0x69, 0x307, 0x300] { unicode::utf8_encode(text, cp); }
    unicode::to_upper_locale(out, text[..], unicode::LOCALE_LT);
    print(out[..], "\n");

    // A language tag names the locale. An unknown tag gives the root.
    print("locale_of(\"tr-TR\") = ", unicode::locale_of("tr-TR"), "\n");
    print("locale_of(\"en\") = ", unicode::locale_of("en"), "\n");
}
