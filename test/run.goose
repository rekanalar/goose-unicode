// Tests for the unicode package. Run with: goose run test/run.goose
// The program must start in the package directory.

import std;
import os;
import unicode from "..";
import suite from "./suite";

// Every .goose file in the package directory declares the namespace of
// the package.
fn check_namespaces() -> i64 {
    var bad = 0;
    var names: u8[>..] = [];
    if !list_dir(".", names) {
        print("FAIL: cannot list the package directory\n");
        return 1;
    }
    var seen = 0;
    for name in split(names[..], '\n') {
        if name.len < 7 || name[name.len - 6..name.len] != ".goose" { continue; }
        var text: u8[>..] = [];
        if !read_file(name, text) {
            print("FAIL: cannot read ", name, "\n");
            bad += 1;
            continue;
        }
        seen += 1;
        var found = false;
        for line in split(text[..], '\n') {
            if line.len >= 10 && line[0..10] == "namespace " {
                found = true;
                if trim(line[10..line.len]) != "unicode;" {
                    print("FAIL: ", name, " declares: ", line, "\n");
                    bad += 1;
                }
                break;
            }
        }
        if !found {
            print("FAIL: ", name, " declares no namespace\n");
            bad += 1;
        }
    }
    if seen == 0 {
        print("FAIL: no .goose file found; start the tests in the package directory\n");
        bad += 1;
    }
    return bad;
}

fn main() {
    var bad = 0;
    bad += check_namespaces();
    bad += suite::run_utf8();
    bad += suite::run_normalize();
    bad += suite::run_case();
    bad += suite::run_confusable();
    bad += suite::run_property();
    bad += suite::run_grapheme();
    bad += suite::run_segment();
    bad += suite::run_utf16();
    bad += suite::run_utf32();
    bad += suite::run_props();
    bad += suite::run_case_full();
    bad += suite::run_hostile();
    bad += suite::run_width();
    bad += suite::run_bidi();
    bad += suite::run_title();
    bad += suite::run_flags();
    bad += suite::run_line();
    bad += suite::run_enum();
    bad += suite::run_name();
    bad += suite::run_char();
    bad += suite::run_script();
    bad += suite::run_coll();
    bad += suite::run_locale();
    bad += suite::run_greek();
    bad += suite::run_dict();
    bad += suite::run_line_dict();
    bad += suite::run_sent_abbr();
    bad += suite::run_lossy();
    bad += suite::run_emoji_seq();
    if bad > 0 {
        print(bad, " checks failed\n");
        assert(false);
    }
    print("ok\n");
    return 0;
}
