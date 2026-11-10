// Runs the UCD bidi test files against bidi_levels and bidi_order.
// Usage: goose run test/bidi_conformance.goose <dir of the UCD files>
// The program must start in the package directory. The directory holds
// BidiCharacterTest.txt and BidiTest.txt of the Unicode Character
// Database. The files are not part of this package, because they hold
// many megabytes. The test script test/make_bidi_data.py writes the
// tables of the package from the same source.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn hexval(s: const u8[:]) -> i64 { return bidiutil::hexval(s); }

fn num(s: const u8[:]) -> i64 { return bidiutil::numval(s); }

// A code point of each class, in the order of the BIDI constants.
fn class_cp(name: const u8[:]) -> i64 {
    if name == "L" { return 0x61; }
    if name == "R" { return 0x5D0; }
    if name == "AL" { return 0x627; }
    if name == "EN" { return 0x31; }
    if name == "ES" { return 0x2B; }
    if name == "ET" { return 0x24; }
    if name == "AN" { return 0x661; }
    if name == "CS" { return 0x2C; }
    if name == "NSM" { return 0x300; }
    if name == "BN" { return 0xAD; }
    if name == "B" { return 0x2029; }
    if name == "S" { return 0x09; }
    if name == "WS" { return 0x20; }
    if name == "ON" { return 0x21; }
    if name == "LRE" { return 0x202A; }
    if name == "LRO" { return 0x202D; }
    if name == "RLE" { return 0x202B; }
    if name == "RLO" { return 0x202E; }
    if name == "PDF" { return 0x202C; }
    if name == "LRI" { return 0x2066; }
    if name == "RLI" { return 0x2067; }
    if name == "FSI" { return 0x2068; }
    if name == "PDI" { return 0x2069; }
    return -1;
}

fn nums(s: const u8[:], hex: bool) -> i64[>..] {
    var out: i64[>..] = [];
    for p in split(s, ' ') {
        let q = trim(p);
        if q.len == 0 { continue; }
        if q == "x" { out.push(-1); }
        else if hex { out.push(hexval(q)); }
        else { out.push(num(q)); }
    }
    return out;
}

// Runs one case and returns 1 on a mismatch.
fn check(cps: const i64[:], dir: i64, want_lv: const i64[:], want_ord: const i64[:],
         tag: const u8[:], line: i64) -> i64 {
    return check_para(cps, dir, want_lv, want_ord, tag, line, -1);
}

fn check_para(cps: const i64[:], dir: i64, want_lv: const i64[:],
              want_ord: const i64[:], tag: const u8[:], line: i64,
              want_para: i64) -> i64 {
    var text: u8[>..] = [];
    for k in 0..cps.len { unicode::utf8_encode(text, cps[k]); }
    var lv: i64[>..] = [];
    let code, pl = unicode::bidi_levels(lv, text[..], dir);
    var ok = code == unicode::OK && lv.len == want_lv.len;
    if ok && want_para >= 0 && pl != want_para {
        print("FAIL: ", tag, " line ", line, " paragraph level ", pl, ", want ", want_para, "\n");
        return 1;
    }
    if ok {
        for k in 0..lv.len { if lv[k] != want_lv[k] { ok = false; } }
    }
    if ok {
        var ord: i64[>..] = [];
        let c2 = unicode::bidi_order(ord, lv[..]);
        ok = c2 == unicode::OK && ord.len == want_ord.len;
        if ok {
            for k in 0..ord.len { if ord[k] != want_ord[k] { ok = false; } }
        }
    }
    if !ok {
        print("FAIL: ", tag, " line ", line, " dir ", dir, " code ", code, "\n  got");
        for k in 0..lv.len { print(" ", lv[k]); }
        print("\n  want");
        for k in 0..want_lv.len { print(" ", want_lv[k]); }
        print("\n");
        return 1;
    }
    return 0;
}

fn run_char_test(dir: const u8[:]) -> i64 {
    var text: u8[>..] = [];
    if !read_file(bidiutil::path_of(dir, "BidiCharacterTest.txt"), text) {
        print("FAIL: cannot read BidiCharacterTest.txt\n");
        return 1;
    }
    var bad = 0;
    var n = 0;
    var ln = 0;
    for line in split(text[..], '\n') {
        ln += 1;
        if line.len == 0 || line[0] == '#' { continue; }
        var fields = 0;
        var cps: i64[>..] = [];
        var dir = 0;
        var para = 0;
        var lv: i64[>..] = [];
        var ord: i64[>..] = [];
        for part in split(line, ';') {
            if fields == 0 { cps = nums(part, true); }
            else if fields == 1 { dir = num(trim(part)); }
            else if fields == 2 { para = num(trim(part)); }
            else if fields == 3 { lv = nums(part, false); }
            else if fields == 4 { ord = nums(part, false); }
            fields += 1;
        }
        if fields < 5 { continue; }
        n += 1;
        bad += check_para(cps[..], dir, lv[..], ord[..], "char", ln, para);
        if bad > 10 { return bad; }
    }
    print("BidiCharacterTest: ", n, " cases, ", bad, " failures\n");
    return bad;
}

fn run_class_test(dir: const u8[:]) -> i64 {
    var text: u8[>..] = [];
    if !read_file(bidiutil::path_of(dir, "BidiTest.txt"), text) {
        print("FAIL: cannot read BidiTest.txt\n");
        return 1;
    }
    var bad = 0;
    var n = 0;
    var ln = 0;
    var lv: i64[>..] = [];
    var ord: i64[>..] = [];
    for line in split(text[..], '\n') {
        ln += 1;
        if line.len == 0 || line[0] == '#' { continue; }
        if line[0] == '@' {
            if line.len > 8 && line[0..8] == "@Levels:" {
                lv = nums(line[8..line.len], false);
            } else if line.len >= 9 && line[0..9] == "@Reorder:" {
                ord = nums(line[9..line.len], false);
            }
            continue;
        }
        var cps: i64[>..] = [];
        var bits = 0;
        var fields = 0;
        for part in split(line, ';') {
            if fields == 0 {
                for w in split(part, ' ') {
                    let q = trim(w);
                    if q.len > 0 { cps.push(class_cp(q)); }
                }
            } else {
                bits = num(trim(part));
            }
            fields += 1;
        }
        // bit 1 is auto, bit 2 is left to right, bit 4 is right to left
        if (bits & 1) != 0 { n += 1; bad += check(cps[..], 2, lv[..], ord[..], "class", ln); }
        if (bits & 2) != 0 { n += 1; bad += check(cps[..], 0, lv[..], ord[..], "class", ln); }
        if (bits & 4) != 0 { n += 1; bad += check(cps[..], 1, lv[..], ord[..], "class", ln); }
        if bad > 10 { return bad; }
    }
    print("BidiTest: ", n, " cases, ", bad, " failures\n");
    return bad;
}

fn main() {
    let argv = args();
    if argv.len < 2 {
        print("usage: conformance <dir of the UCD files>\n");
        return 1;
    }
    let dir = argv[1];
    var bad = run_char_test(dir);
    bad += run_class_test(dir);
    if bad > 0 { print("FAIL\n"); return 1; }
    print("ok\n");
    return 0;
}
