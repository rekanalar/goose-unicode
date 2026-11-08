// Two file names that differ in case must compare equal after the fold.
import std;
import unicode from "..";

fn main() {
    var first: u8[>..] = [];
    for k in 0.."Bericht.txt".len { first.push("Bericht.txt"[k]); }
    var second: u8[>..] = [];
    for k in 0.."bericht.txt".len { second.push("bericht.txt"[k]); }

    var a: u8[>..] = [];
    var b: u8[>..] = [];
    let code = unicode::fold_case(a, first[..]);
    if code != unicode::OK { print("the first name failed\n"); return 1; }
    let code2 = unicode::fold_case(b, second[..]);
    if code2 != unicode::OK { print("the second name failed\n"); return 1; }

    print("first:  ", first, "\n");
    print("second: ", second, "\n");
    print("folded: ", a, "\n");
    if a[..] != b[..] {
        print("the two names differ\n");
        return 1;
    }
    print("the two names are equal\n");
    return 0;
}
