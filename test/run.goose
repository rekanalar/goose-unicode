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
    // The variable UNICODE_SUITES holds the name of a group of suites.
    // The empty name runs every group. The mutation probes use a group,
    // so a probe costs only the suites that cover the rule it changes.
    var which: u8[>..] = [];
    let has = env("UNICODE_SUITES", which);
    if !has { which.clear(); }
    bad += run_group(which[..]);
    if bad > 0 {
        print(bad, " checks failed\n");
        assert(false);
    }
    print("ok\n");
    return 0;
}

// The suites of one group. A group holds the suites that cover the
// calls of one file, so a probe of that file runs only this group. The
// empty name runs every group, in this order.
fn run_group(name: const u8[:]) -> i64 {
    var bad = 0;
    let every = name.len == 0;
    var ran = 0;
    if every || name == "utf8" { bad += suite::run_utf8(); ran += 1; }
    if every || name == "norm" { bad += suite::run_normalize(); ran += 1; }
    if every || name == "case" { bad += suite::run_case(); ran += 1; }
    if every || name == "confusable" { bad += suite::run_confusable(); ran += 1; }
    if every || name == "property" { bad += suite::run_property(); ran += 1; }
    if every || name == "grapheme" { bad += suite::run_grapheme(); ran += 1; }
    if every || name == "segment" { bad += suite::run_segment(); ran += 1; }
    if every || name == "utf16" { bad += suite::run_utf16(); ran += 1; }
    if every || name == "utf32" { bad += suite::run_utf32(); ran += 1; }
    if every || name == "props" { bad += suite::run_props(); ran += 1; }
    if every || name == "case_full" { bad += suite::run_case_full(); ran += 1; }
    if every || name == "hostile" { bad += suite::run_hostile(); ran += 1; }
    if every || name == "width" { bad += suite::run_width(); ran += 1; }
    if every || name == "bidi" { bad += suite::run_bidi(); ran += 1; }
    if every || name == "title" { bad += suite::run_title(); ran += 1; }
    if every || name == "flags" { bad += suite::run_flags(); ran += 1; }
    if every || name == "line" { bad += suite::run_line(); ran += 1; }
    if every || name == "enum" { bad += suite::run_enum(); ran += 1; }
    if every || name == "name" { bad += suite::run_name(); ran += 1; }
    if every || name == "char" { bad += suite::run_char(); ran += 1; }
    if every || name == "script" { bad += suite::run_script(); ran += 1; }
    if every || name == "coll" { bad += suite::run_coll(); ran += 1; }
    if every || name == "locale" { bad += suite::run_locale(); ran += 1; }
    if every || name == "greek" { bad += suite::run_greek(); ran += 1; }
    if every || name == "dict" { bad += suite::run_dict(); ran += 1; }
    if every || name == "line_dict" { bad += suite::run_line_dict(); ran += 1; }
    if every || name == "sent_abbr" { bad += suite::run_sent_abbr(); ran += 1; }
    if every || name == "lossy" { bad += suite::run_lossy(); ran += 1; }
    if every || name == "emoji_seq" { bad += suite::run_emoji_seq(); ran += 1; }
    if every || name == "restrict" { bad += suite::run_restrict(); ran += 1; }
    if every || name == "lstm" { bad += suite::run_lstm(); ran += 1; }
    if every || name == "bidi_line" { bad += suite::run_bidi_line(); ran += 1; }
    // An unknown name runs no group. The test program must not pass then.
    if !every && ran == 0 {
        print("FAIL: no suite group named ", name, "\n");
        bad += 1;
    }
    return bad;
}
