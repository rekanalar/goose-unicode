// The code point of a name, and the name of a code point.
import std;
import unicode from "..";

fn main() {
    print(unicode::lookup("LATIN SMALL LETTER A"), "\n");       // 97
    print(unicode::lookup("latin small letter a"), "\n");       // 97, the case of ASCII letters does not count
    print(unicode::lookup("CJK UNIFIED IDEOGRAPH-4E00"), "\n"); // 19968
    print(unicode::lookup("LF"), "\n");                         // 10, a formal alias
    print(unicode::lookup("NO SUCH NAME"), "\n");               // -1

    // A name makes the round trip.
    print(unicode::lookup(unicode::name(0x1F600)), "\n");       // 128512
    return 0;
}
