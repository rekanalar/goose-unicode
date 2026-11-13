// Tests for the full case mappings.
namespace suite;

import std;
import unicode from "../..";

// The sharp s, the final sigma and the ligatures.
fn full_samples() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    let code, off = unicode::to_upper_full(out, "Straße");
    if code != unicode::OK || off != -1 || out != "STRASSE" {
        print("FAIL: the sharp s does not upper case to SS\n");
        bad += 1;
    }
    let c2, o2 = unicode::to_lower_full(out, "ΟΟΣ ΟΣ");
    if c2 != unicode::OK || o2 != -1 || out != "οος ος" {
        print("FAIL: the final sigma of the first text differs: ", out, "\n");
        bad += 1;
    }
    let c3, o3 = unicode::to_lower_full(out, "Σ ΣΣ ΟΣ");
    if c3 != unicode::OK || o3 != -1 || out != "σ σς ος" {
        print("FAIL: the final sigma of the second text differs: ", out, "\n");
        bad += 1;
    }
    let c4, o4 = unicode::to_upper_full(out, "ﬁx");
    if c4 != unicode::OK || o4 != -1 || out != "FIX" {
        print("FAIL: the ligature does not upper case: ", out, "\n");
        bad += 1;
    }
    let c5, o5 = unicode::to_upper_full(out, "؜ﬅ");
    if c5 != unicode::OK || out != "؜ST" {
        print("FAIL: the long s ligature does not upper case: ", out, "\n");
        bad += 1;
    }
    // A sigma with no cased letter around it keeps the sigma.
    let c6, o6 = unicode::to_lower_full(out, "Σ");
    if c6 != unicode::OK || out != "σ" {
        print("FAIL: the lone sigma differs: ", out, "\n");
        bad += 1;
    }
    // The simple mappings keep their behavior.
    let c7, o7 = unicode::to_upper(out, "Straße");
    if c7 != unicode::OK || out != "STRAßE" {
        print("FAIL: the simple upper of the sharp s differs\n");
        bad += 1;
    }
    let c8, o8 = unicode::to_lower(out, "Σ");
    if c8 != unicode::OK || out != "σ" {
        print("FAIL: the simple lower of the sigma differs\n");
        bad += 1;
    }
    return bad;
}

// Every text of the generated set, against Python, Node and Go.
fn full_texts() -> i64 {
    var bad = 0;
    var inb: u8[>..] = [];
    var wantb: u8[>..] = [];
    for k in 0..FC_IN_OFF.len {
        inb.clear();
        wantb.clear();
        var a: i64 = 0;
        if k > 0 { a = FC_IN_OFF[k - 1]; }
        for j in a..FC_IN_OFF[k] { unicode::utf8_encode(inb, FC_IN_POOL[j]); }
        var ua: i64 = 0;
        if k > 0 { ua = FC_UP_OFF[k - 1]; }
        for j in ua..FC_UP_OFF[k] { unicode::utf8_encode(wantb, FC_UP_POOL[j]); }
        var out: u8[>..] = [];
        let code, off = unicode::to_upper_full(out, inb[..]);
        if code != unicode::OK || off != -1 || out != wantb[..] {
            print("FAIL: the upper of text ", k, " differs: ", out, "\n");
            bad += 1;
        }
        wantb.clear();
        var la: i64 = 0;
        if k > 0 { la = FC_LO_OFF[k - 1]; }
        for j in la..FC_LO_OFF[k] { unicode::utf8_encode(wantb, FC_LO_POOL[j]); }
        let c2, o2 = unicode::to_lower_full(out, inb[..]);
        if c2 != unicode::OK || o2 != -1 || out != wantb[..] {
            print("FAIL: the lower of text ", k, " differs: ", out, "\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// A bad byte faults with the offset and leaves the buffer empty.
fn full_faults() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    out.push(0x41);
    let code, off = unicode::to_upper_full(out, "abc\xffdef");
    if code != unicode::ERR_BAD_UTF8 || off != 3 {
        print("FAIL: the fault of the bad byte differs: ", code, " ", off, "\n");
        bad += 1;
    }
    if out.len != 0 {
        print("FAIL: a fault leaves bytes in the buffer\n");
        bad += 1;
    }
    let c2, o2 = unicode::to_lower_full(out, "ab\xE0\x80");
    if c2 != unicode::ERR_BAD_UTF8 || o2 != 2 {
        print("FAIL: the fault of the cut sequence differs\n");
        bad += 1;
    }
    if out.len != 0 {
        print("FAIL: the cut fault leaves bytes in the buffer\n");
        bad += 1;
    }
    return bad;
}

// The bounds of the input and of the output.
fn full_bounds() -> i64 {
    var bad = 0;
    var out: u8[>..] = [];
    var long: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT + 1 { long.push(0x41); }
    let code, off = unicode::to_upper_full(out, long[..]);
    if code != unicode::ERR_TOO_LONG || off != -1 {
        print("FAIL: the input bound does not fault\n");
        bad += 1;
    }
    if out.len != 0 {
        print("FAIL: the input bound leaves bytes in the buffer\n");
        bad += 1;
    }
    // The sharp s grows two to one, so half of the input bound is a
    // result above the output bound.
    var grow: u8[>..] = [];
    for i in 0..unicode::MAX_OUTPUT / 2 + 1 { grow.push(0xDF); }
    let c2, o2 = unicode::to_upper_full(out, grow[..]);
    if c2 != unicode::ERR_TOO_LONG || o2 != -1 {
        print("FAIL: the output bound does not fault\n");
        bad += 1;
    }
    if out.len != 0 {
        print("FAIL: the output bound leaves bytes in the buffer\n");
        bad += 1;
    }
    return bad;
}

fn run_case_full() -> i64 {
    var bad = 0;
    if want("case_full", "full_samples") { bad += full_samples(); }
    if want("case_full", "full_texts") { bad += full_texts(); }
    if want("case_full", "full_faults") { bad += full_faults(); }
    if want("case_full", "full_bounds") { bad += full_bounds(); }
    return bad;
}
