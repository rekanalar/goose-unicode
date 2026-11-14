// The options of the collation change the order of the texts: the
// numeric order puts the number 9 before the number 10, the upper case
// first puts "A" before "a", and the shifted handling moves the
// punctuation behind the letters.
import std;
import unicode from "..";

fn sign(out: i64[>..]&, a: const u8[:], b: const u8[:], o: unicode::CollOptions, name: const u8[:]) {
    let code, _ = unicode::compare_with(out, a[..], b[..], o);
    if code != unicode::OK {
        print("the compare failed\n");
        return;
    }
    print(name, ": ");
    if out[0] < 0 {
        print(a, " sorts before ", b, "\n");
    } else if out[0] > 0 {
        print(a, " sorts after ", b, "\n");
    } else {
        print(a, " and ", b, " sort equal\n");
    }
}

fn main() {
    var out: i64[>..] = [];
    var o = unicode::coll_options();

    // The numeric order: the number 9 sorts before the number 10.
    o.numeric = 1;
    sign(out, "file9", "file10", o, "numeric");

    // The upper case first: the upper case letter sorts first.
    o = unicode::coll_options();
    o.case_first = unicode::CASE_UPPER_FIRST;
    sign(out, "apple", "Banana", o, "upper case first");

    // The shifted handling: the punctuation sorts after the letters.
    o = unicode::coll_options();
    o.alternate = unicode::ALT_SHIFTED;
    sign(out, "a-b", "ab", o, "shifted");

    // The primary strength: the case and the accent no longer decide.
    o = unicode::coll_options();
    o.strength = unicode::STRENGTH_PRIMARY;
    sign(out, "resume", "résumé", o, "primary strength");

    // The case level: "a" sorts before "A" even at the primary strength.
    o = unicode::coll_options();
    o.strength = unicode::STRENGTH_PRIMARY;
    o.case_level = unicode::CASE_LEVEL_ON;
    sign(out, "a", "A", o, "case level");

    // The quaternary strength: the dropped hyphen decides the order.
    o = unicode::coll_options();
    o.alternate = unicode::ALT_SHIFTED;
    o.strength = unicode::STRENGTH_QUATERNARY;
    sign(out, "a b", "a-b", o, "quaternary");

    // The default options give the order of the root collation.
    o = unicode::coll_options();
    sign(out, "resume", "résumé", o, "default");
    return 0;
}
