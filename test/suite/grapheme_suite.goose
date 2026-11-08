// Tests for the grapheme clusters.
namespace suite;

import std;
import unicode from "../..";

// The bytes of one code point.
fn gb_one(cp: i64) -> u8[>..] {
    var out: u8[>..] = [];
    push_utf8(out, cp);
    return out;
}

// The expected split of one case of the test file. The case holds the
// code points, then the size of each cluster in code points.
fn gb_case(case: i64) -> u8[>..] {
    let start = GB_OFF[case];
    let n = GB_POOL[start];
    var out: u8[>..] = [];
    for k in 1..n + 1 { out.append(gb_one(GB_POOL[start + k])[..]); }
    return out;
}

// The expected sizes of the clusters of one case.
fn gb_sizes(case: i64) -> i64[>..] {
    let start = GB_OFF[case];
    let n = GB_POOL[start];
    let at = start + n + 1;
    let m = GB_POOL[at];
    var out: i64[>..] = [];
    for k in 0..m { out.push(GB_POOL[at + 1 + k]); }
    return out;
}

// The split of every case of the test file of the standard.
fn gb_cases() -> i64 {
    var bad = 0;
    let cases = GB_OFF.len - 1;
    for c in 0..cases {
        let text = gb_case(c);
        let want = gb_sizes(c);
        var offsets: i64[>..] = [];
        let code = unicode::grapheme_offsets(offsets, text[..]);
        if code != unicode::OK { print("FAIL: the offsets gave the code ", code, "\n"); bad += 1; continue; }
        if offsets.len != want.len {
            print("FAIL: the case ", c, " gave ", offsets.len, " clusters and not ", want.len, "\n");
            bad += 1;
            if bad > 5 { return bad; }
            continue;
        }
        // The walk over the clusters must give the same offsets.
        var at: i64 = 0;
        for k in 0..want.len {
            let c2, end = unicode::grapheme_next(text[..], at);
            if c2 != unicode::OK {
                print("FAIL: the walk gave the code ", c2, "\n");
                bad += 1;
                break;
            }
            if at != offsets[k] {
                print("FAIL: the case ", c, " gave a different offset\n");
                bad += 1;
                break;
            }
            // The size of the cluster in code points must match.
            var cps: i64[>..] = [];
            unicode::utf8_decode(cps, text[at..end]);
            if cps.len != want[k] {
                print("FAIL: the case ", c, " gave a cluster of ", cps.len, " code points\n");
                bad += 1;
                break;
            }
            at = end;
        }
        if at != text.len {
            print("FAIL: the case ", c, " did not reach the end\n");
            bad += 1;
        }
        let c3, count = unicode::grapheme_count(text[..]);
        if c3 != unicode::OK || count != want.len {
            print("FAIL: the count of the case ", c, " differs\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The clusters that a user sees.
fn gb_named() -> i64 {
    var bad = 0;
    // The flag of two regional indicators is one cluster.
    var flag: u8[>..] = [];
    push_utf8(flag, 0x1F1E6);
    push_utf8(flag, 0x1F1E7);
    let code, count = unicode::grapheme_count(flag[..]);
    if code != unicode::OK || count != 1 {
        print("FAIL: the flag is not one cluster\n");
        bad += 1;
    }
    // A family of four people is one cluster.
    var family: u8[>..] = [];
    push_utf8(family, 0x1F468);
    push_utf8(family, 0x200D);
    push_utf8(family, 0x1F469);
    push_utf8(family, 0x200D);
    push_utf8(family, 0x1F466);
    let code2, count2 = unicode::grapheme_count(family[..]);
    if code2 != unicode::OK || count2 != 1 {
        print("FAIL: the family is not one cluster\n");
        bad += 1;
    }
    // A letter and a mark is one cluster.
    var accented: u8[>..] = [];
    push_utf8(accented, 0x65);
    push_utf8(accented, 0x301);
    let code3, count3 = unicode::grapheme_count(accented[..]);
    if code3 != unicode::OK || count3 != 1 {
        print("FAIL: the accented letter is not one cluster\n");
        bad += 1;
    }
    // The letter and the line break of two bytes are two clusters.
    let code4, count4 = unicode::grapheme_count("a\r\n");
    if code4 != unicode::OK || count4 != 2 {
        print("FAIL: the line break gave ", count4, " clusters\n");
        bad += 1;
    }
    // An empty text has no clusters.
    let code5, count5 = unicode::grapheme_count("");
    if code5 != unicode::OK || count5 != 0 {
        print("FAIL: the empty text gave ", count5, " clusters\n");
        bad += 1;
    }
    return bad;
}

// A malformed byte forms a cluster of its own.
fn gb_malformed() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    text.push(0x61);
    text.push(0x80);
    text.push(0x62);
    let code, count = unicode::grapheme_count(text[..]);
    if code != unicode::OK || count != 3 {
        print("FAIL: the malformed byte gave ", count, " clusters\n");
        bad += 1;
    }
    // The offsets must not join the malformed byte with a neighbour.
    var offsets: i64[>..] = [];
    unicode::grapheme_offsets(offsets, text[..]);
    if offsets.len != 3 || offsets[0] != 0 || offsets[1] != 1 || offsets[2] != 2 {
        print("FAIL: the offsets of the malformed byte differ\n");
        bad += 1;
    }
    // A malformed byte between two letters must break the cluster.
    var two: u8[>..] = [];
    push_utf8(two, 0x65);
    push_utf8(two, 0x301);
    two.push(0x80);
    let code2, count2 = unicode::grapheme_count(two[..]);
    if code2 != unicode::OK || count2 != 2 {
        print("FAIL: the malformed byte joined a cluster\n");
        bad += 1;
    }
    return bad;
}

// The faults of the cluster calls.
fn gb_faults() -> i64 {
    var bad = 0;
    let code, end = unicode::grapheme_next("abc", -1);
    if code != unicode::ERR_BAD_ARG { print("FAIL: the offset was not checked\n"); bad += 1; }
    let code2, end2 = unicode::grapheme_next("abc", 3);
    if code2 != unicode::ERR_BAD_ARG { print("FAIL: the offset was not checked\n"); bad += 1; }
    let code3, end3 = unicode::grapheme_next("", 0);
    if code3 != unicode::ERR_BAD_ARG { print("FAIL: the offset was not checked\n"); bad += 1; }
    var offsets: i64[>..] = [];
    let code4 = unicode::grapheme_offsets(offsets, "abc");
    if code4 != unicode::OK { print("FAIL: the offsets gave the code ", code4, "\n"); bad += 1; }
    return bad;
}

// The count must equal the number of the offsets.
fn gb_count_equals_offsets() -> i64 {
    var bad = 0;
    var st: u64 = 555;
    for k in 0..20000 {
        var text: u8[>..] = [];
        let n = rnd(st) % 8;
        for j in 0..n {
            let r = rnd(st);
            if r % 4 == 0 {
                // A malformed byte.
                text.push(0x80 + (r % 0x40) as u8);
            } else {
                var cp: i64 = r % 0x110000;
                if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
                push_utf8(text, cp);
            }
        }
        let code, count = unicode::grapheme_count(text[..]);
        if code != unicode::OK { print("FAIL: the count gave the code ", code, "\n"); bad += 1; continue; }
        var offsets: i64[>..] = [];
        unicode::grapheme_offsets(offsets, text[..]);
        if offsets.len != count {
            print("FAIL: the count and the offsets differ at ", k, "\n");
            bad += 1;
        }
        // The walk must give the same number of clusters.
        var at: i64 = 0;
        var walked: i64 = 0;
        while at < text.len {
            let c2, end = unicode::grapheme_next(text[..], at);
            if c2 != unicode::OK { print("FAIL: the walk gave the code ", c2, "\n"); bad += 1; break; }
            if end <= at { print("FAIL: the walk did not move at ", k, "\n"); bad += 1; break; }
            at = end;
            walked += 1;
        }
        if walked != count {
            print("FAIL: the walk and the count differ at ", k, "\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

fn run_grapheme() -> i64 {
    var bad = 0;
    bad += gb_cases();
    bad += gb_named();
    bad += gb_malformed();
    bad += gb_faults();
    bad += gb_count_equals_offsets();
    return bad;
}
