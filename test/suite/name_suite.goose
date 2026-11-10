// Tests for the name lookup.
namespace suite;

import std;
import unicode from "../..";

fn nm_check(ok: bool, name: const u8[:]) -> i64 {
    if !ok { print("FAIL: name ", name, "\n"); return 1; }
    return 0;
}

// Every named code point resolves from its own name, in upper and lower case.
fn lookup_round_trip() -> i64 {
    var bad = 0;
    var low: u8[>..] = [];
    for cp in 0..0x110000 {
        let n = unicode::name(cp);
        if n.len == 0 { continue; }
        if unicode::lookup(n) != cp {
            bad += 1;
            if bad <= 5 { print("FAIL: lookup of ", n, "\n"); }
            continue;
        }
        if (cp % 61) == 0 {
            low.clear();
            for k in 0..n.len {
                let c = n[k] as i64;
                low.push(if c >= 65 && c <= 90 { (c + 32) as u8 } else { n[k] });
            }
            if unicode::lookup(low[..]) != cp { bad += 1; print("FAIL: lower case lookup of ", n, "\n"); }
        }
    }
    return bad;
}

// Every alias of the file resolves to its code point.
fn lookup_aliases() -> i64 {
    var bad = 0;
    for k in 0..NAL_CP.len {
        let a = NAL_NAMES[NAL_OFF[k]..NAL_OFF[k + 1]];
        if unicode::lookup(a) != NAL_CP[k] {
            bad += 1;
            print("FAIL: alias ", a, "\n");
        }
    }
    return bad;
}

// The queries of the oracle: names, near misses and their answers.
fn lookup_queries() -> i64 {
    var bad = 0;
    for q in 0..NQ_OFF.len - 1 {
        var text: u8[>..] = [];
        for j in NQ_OFF[q]..NQ_OFF[q + 1] { unicode::utf8_encode(text, NQ_POOL[j]); }
        if unicode::lookup(text[..]) != NQ_WANT[q] {
            bad += 1;
            if bad <= 5 { print("FAIL: query ", text, "\n"); }
        }
    }
    return bad;
}

fn lookup_samples() -> i64 {
    var bad = 0;
    bad += nm_check(unicode::lookup("LATIN SMALL LETTER A") == 0x61, "letter");
    bad += nm_check(unicode::lookup("latin small letter a") == 0x61, "lower case");
    bad += nm_check(unicode::lookup("HANGUL SYLLABLE GA") == 0xAC00, "syllable");
    bad += nm_check(unicode::lookup("CJK UNIFIED IDEOGRAPH-4E00") == 0x4E00, "ideograph");
    bad += nm_check(unicode::lookup("LF") == 0xA, "alias abbreviation");
    bad += nm_check(unicode::lookup("LINE FEED") == 0xA, "alias control");
    bad += nm_check(unicode::lookup("BYTE ORDER MARK") == 0xFEFF, "alias alternate");
    bad += nm_check(unicode::lookup("BELL") == 0x1F514, "name wins");
    bad += nm_check(unicode::lookup("") == -1, "empty");
    bad += nm_check(unicode::lookup("LATIN SMALL LETTER") == -1, "prefix");
    bad += nm_check(unicode::lookup(" LATIN SMALL LETTER A") == -1, "leading space");
    bad += nm_check(unicode::lookup("LATIN SMALL LETTER A ") == -1, "trailing space");
    bad += nm_check(unicode::lookup("LATIN-SMALL-LETTER-A") == -1, "hyphens");
    bad += nm_check(unicode::lookup("CJK UNIFIED IDEOGRAPH-4E0") == -1, "short digits");
    bad += nm_check(unicode::lookup("HANGUL SYLLABLE GAX") == -1, "bad syllable");
    return bad;
}

fn lookup_hostile() -> i64 {
    var bad = 0;
    var long: u8[>..] = [];
    for i in 0..unicode::MAX_INPUT { long.push(0x41); }
    bad += nm_check(unicode::lookup(long[..]) == -1, "long text");
    // The longest name with one byte more, and 129 bytes of one letter.
    var near: u8[>..] = [];
    near.append("ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA INITIAL FORMX");
    bad += nm_check(unicode::lookup(near[..]) == -1, "longest name and one more byte");
    near.clear();
    for i in 0..129 { near.push(0x41); }
    bad += nm_check(unicode::lookup(near[..]) == -1, "129 bytes");
    // Many queries with a long shared prefix take bounded time each.
    var q: u8[>..] = [];
    q.append("ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA INITIAL FORM");
    var hits: i64 = 0;
    for i in 0..20000 { if unicode::lookup(q[..]) >= 0 { hits += 1; } }
    bad += nm_check(hits == 20000, "repeated queries");
    return bad;
}

fn run_name() -> i64 {
    var bad = 0;
    bad += lookup_samples();
    bad += lookup_aliases();
    bad += lookup_queries();
    bad += lookup_hostile();
    bad += lookup_round_trip();
    return bad;
}
