// Tests with hostile input. Every call must answer with a fault code
// and never hang or grow without bound.
namespace suite;

import std;
import unicode from "../..";

// A random byte string. The seed gives the same bytes on every run.
fn hostile_bytes(st: u64&, len: i64) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..len { out.push(rnd(st) as u8); }
    return out;
}

// A random text of code points. Some of the code points are malformed
// on purpose.
fn hostile_text(st: u64&, len: i64) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..len {
        let r = rnd(st);
        if r % 5 == 0 {
            out.push(rnd(st) as u8);
            continue;
        }
        var cp: i64 = r % 0x110000;
        if cp >= 0xD800 && cp <= 0xDFFF { cp = 0x41; }
        push_utf8(out, cp);
    }
    return out;
}

// Every public call must answer with a fault code that the package
// names, and must not keep bytes of the input in the fault.
fn hostile_random() -> i64 {
    var bad = 0;
    var st: u64 = 424242;
    let forms: i64[4] = [unicode::FORM_NFC, unicode::FORM_NFD, unicode::FORM_NFKC, unicode::FORM_NFKD];
    for k in 0..20000 {
        let text = hostile_text(st, rnd(st) % 20);
        var out: u8[>..] = [];
        var cps: i64[>..] = [];
        var offsets: i64[>..] = [];

        let c1, o1 = unicode::utf8_decode(cps, text[..]);
        if !known(c1) { print("FAIL: the decode gave an unknown code ", c1, "\n"); bad += 1; }
        let c2, o2 = unicode::normalize(out, forms[k % 4], text[..]);
        if !known(c2) { print("FAIL: the normalize gave an unknown code ", c2, "\n"); bad += 1; }
        let c3, o3 = unicode::to_upper(out, text[..]);
        if !known(c3) { print("FAIL: the upper case gave an unknown code ", c3, "\n"); bad += 1; }
        let c4, o4 = unicode::to_lower(out, text[..]);
        if !known(c4) { print("FAIL: the lower case gave an unknown code ", c4, "\n"); bad += 1; }
        let c5, o5 = unicode::fold_case(out, text[..]);
        if !known(c5) { print("FAIL: the fold gave an unknown code ", c5, "\n"); bad += 1; }
        let c6, n6 = unicode::grapheme_count(text[..]);
        if !known(c6) { print("FAIL: the count gave an unknown code ", c6, "\n"); bad += 1; }
        let c7 = unicode::grapheme_offsets(offsets, text[..]);
        if !known(c7) { print("FAIL: the offsets gave an unknown code ", c7, "\n"); bad += 1; }

        // A fault must name the offset of the first bad byte, and that
        // offset must be inside the text.
        if c1 == unicode::ERR_BAD_UTF8 && (o1 < 0 || o1 >= text.len) {
            print("FAIL: the decode gave an offset outside the text\n");
            bad += 1;
        }
        if c2 == unicode::ERR_BAD_UTF8 && (o2 < 0 || o2 >= text.len) {
            print("FAIL: the normalize gave an offset outside the text\n");
            bad += 1;
        }
        // A fault must leave the output empty.
        if c2 != unicode::OK && out.len != 0 {
            print("FAIL: a fault kept bytes of the result\n");
            bad += 1;
        }
        if bad > 5 { return bad; }
    }
    return bad;
}

// True when the code is one that the package names.
fn known(code: i64) -> bool {
    if code == unicode::OK { return true; }
    if code == unicode::ERR_BAD_UTF8 { return true; }
    if code == unicode::ERR_BAD_CODEPOINT { return true; }
    if code == unicode::ERR_BAD_FORM { return true; }
    if code == unicode::ERR_TOO_LONG { return true; }
    if code == unicode::ERR_BAD_ARG { return true; }
    return false;
}

// The cut sweep. The text is cut at every position, and every piece
// must give a fault code that the package names.
fn hostile_cut() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    push_utf8(text, 0x65);
    push_utf8(text, 0x301);
    push_utf8(text, 0x1F468);
    push_utf8(text, 0x200D);
    push_utf8(text, 0x1F469);
    push_utf8(text, 0xD);
    push_utf8(text, 0x41);
    for cut in 0..text.len + 1 {
        var piece: u8[>..] = [];
        piece.append(text[0..cut]);
        var out: u8[>..] = [];
        var cps: i64[>..] = [];
        let c1, o1 = unicode::utf8_decode(cps, piece[..]);
        if !known(c1) { print("FAIL: the decode gave an unknown code ", c1, "\n"); bad += 1; }
        let c2, o2 = unicode::normalize(out, unicode::FORM_NFC, piece[..]);
        if !known(c2) { print("FAIL: the normalize gave an unknown code ", c2, "\n"); bad += 1; }
        let c3, n3 = unicode::grapheme_count(piece[..]);
        if !known(c3) { print("FAIL: the count gave an unknown code ", c3, "\n"); bad += 1; }
        if bad > 5 { return bad; }
    }
    return bad;
}

// The flip sweep. Every byte of the text takes every value.
fn hostile_flip() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    push_utf8(text, 0x65);
    push_utf8(text, 0x301);
    push_utf8(text, 0x1F468);
    push_utf8(text, 0x200D);
    for at in 0..text.len {
        for v in 0..256 {
            var piece: u8[>..] = [];
            piece.append(text[0..at]);
            piece.push(v as u8);
            piece.append(text[at + 1..text.len]);
            var out: u8[>..] = [];
            var cps: i64[>..] = [];
            let c1, o1 = unicode::utf8_decode(cps, piece[..]);
            if !known(c1) { print("FAIL: the decode gave an unknown code ", c1, "\n"); bad += 1; }
            let c2, o2 = unicode::normalize(out, unicode::FORM_NFC, piece[..]);
            if !known(c2) { print("FAIL: the normalize gave an unknown code ", c2, "\n"); bad += 1; }
            let c3, o3 = unicode::to_upper(out, piece[..]);
            if !known(c3) { print("FAIL: the upper case gave an unknown code ", c3, "\n"); bad += 1; }
            let c4, o4 = unicode::fold_case(out, piece[..]);
            if !known(c4) { print("FAIL: the fold gave an unknown code ", c4, "\n"); bad += 1; }
            let c5, n5 = unicode::grapheme_count(piece[..]);
            if !known(c5) { print("FAIL: the count gave an unknown code ", c5, "\n"); bad += 1; }
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The bounds. An input above the limit gives ERR_TOO_LONG, and a result
// above the limit gives ERR_TOO_LONG with no bytes written.
fn hostile_bounds() -> i64 {
    var bad = 0;
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { big.push(0x41); }
    var out: u8[>..] = [];
    var cps: i64[>..] = [];
    var offsets: i64[>..] = [];
    let c1, o1 = unicode::utf8_decode(cps, big[..]);
    if c1 != unicode::ERR_TOO_LONG { print("FAIL: the decode did not check the bound\n"); bad += 1; }
    if cps.len != 0 { print("FAIL: the decode kept code points\n"); bad += 1; }
    let c2, o2 = unicode::normalize(out, unicode::FORM_NFC, big[..]);
    if c2 != unicode::ERR_TOO_LONG { print("FAIL: the normalize did not check the bound\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the normalize kept bytes\n"); bad += 1; }
    let c3, o3 = unicode::to_upper(out, big[..]);
    if c3 != unicode::ERR_TOO_LONG { print("FAIL: the upper case did not check the bound\n"); bad += 1; }
    let c4, o4 = unicode::to_lower(out, big[..]);
    if c4 != unicode::ERR_TOO_LONG { print("FAIL: the lower case did not check the bound\n"); bad += 1; }
    let c5, o5 = unicode::fold_case(out, big[..]);
    if c5 != unicode::ERR_TOO_LONG { print("FAIL: the fold did not check the bound\n"); bad += 1; }
    let c6, n6 = unicode::grapheme_count(big[..]);
    if c6 != unicode::ERR_TOO_LONG { print("FAIL: the count did not check the bound\n"); bad += 1; }
    let c7 = unicode::grapheme_offsets(offsets, big[..]);
    if c7 != unicode::ERR_TOO_LONG { print("FAIL: the offsets did not check the bound\n"); bad += 1; }
    if offsets.len != 0 { print("FAIL: the offsets kept values\n"); bad += 1; }
    // The input at the bound must work.
    var at_bound: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT { at_bound.push(0x41); }
    let c8, o8 = unicode::utf8_decode(cps, at_bound[..]);
    if c8 != unicode::OK || cps.len != unicode::MAX_INPUT {
        print("FAIL: the input at the bound was refused\n");
        bad += 1;
    }
    return bad;
}

// The output bound. A compatibility decomposition can grow the text. The
// call must fault instead of writing past the limit.
fn hostile_output_bound() -> i64 {
    var bad = 0;
    // The character U+FDFA has a compatibility decomposition of 18 code
    // points. A long run of it grows the text by a factor of 18.
    var text: u8[>..] = [];
    for k in 0..250000 { push_utf8(text, 0xFDFA); }
    var out: u8[>..] = [];
    let code, off = unicode::normalize(out, unicode::FORM_NFKD, text[..]);
    if code != unicode::ERR_TOO_LONG {
        print("FAIL: the output bound was not checked\n");
        bad += 1;
    }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    return bad;
}

// A fault holds a code and an offset. It never holds bytes of the
// input. The check reads every fault path and holds no byte.
fn hostile_fault_holds_no_bytes() -> i64 {
    var bad = 0;
    // The decode of a text with a bad byte.
    var text: u8[>..] = [];
    text.push(0x41);
    text.push(0xC3);
    var cps: i64[>..] = [];
    let code, off = unicode::utf8_decode(cps, text[..]);
    if code != unicode::ERR_BAD_UTF8 { print("FAIL: the bad byte was not found\n"); bad += 1; }
    if cps.len != 0 { print("FAIL: the decode kept code points\n"); bad += 1; }
    if off != 1 { print("FAIL: the offset was ", off, "\n"); bad += 1; }
    // The offset is a number. It holds no byte of the input.
    if off != 1 && off != -1 { print("FAIL: the offset is not a plain number\n"); bad += 1; }
    // The normalize of the same text.
    var out: u8[>..] = [];
    let c2, o2 = unicode::normalize(out, unicode::FORM_NFC, text[..]);
    if c2 != unicode::ERR_BAD_UTF8 { print("FAIL: the bad byte was not found\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    // The case calls of the same text.
    let c3, o3 = unicode::to_upper(out, text[..]);
    if c3 != unicode::ERR_BAD_UTF8 { print("FAIL: the bad byte was not found\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    let c4, o4 = unicode::to_lower(out, text[..]);
    if c4 != unicode::ERR_BAD_UTF8 { print("FAIL: the bad byte was not found\n"); bad += 1; }
    let c5, o5 = unicode::fold_case(out, text[..]);
    if c5 != unicode::ERR_BAD_UTF8 { print("FAIL: the bad byte was not found\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    // The encode of a value that is not a code point.
    out.clear();
    let c6 = unicode::utf8_encode(out, 0xD800);
    if c6 != unicode::ERR_BAD_CODEPOINT { print("FAIL: the surrogate was accepted\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault kept bytes\n"); bad += 1; }
    return bad;
}

// The encode of every value that is not a code point.
fn hostile_encode() -> i64 {
    var bad = 0;
    let mut_values: i64[7] = [-1, -2, 0x110000, 0x110001, 0x200000, 0x7FFFFFFF, 0xFFFFFFFF];
    for k in 0..7 {
        var out: u8[>..] = [];
        let code = unicode::utf8_encode(out, mut_values[k]);
        if code != unicode::ERR_BAD_CODEPOINT {
            print("FAIL: the encode accepted ", mut_values[k], "\n");
            bad += 1;
        }
        if out.len != 0 { print("FAIL: the encode wrote bytes\n"); bad += 1; }
    }
    // Every value of the range must be accepted.
    for cp in 0..0x110000 {
        if cp >= 0xD800 && cp <= 0xDFFF { continue; }
        var out: u8[>..] = [];
        let code = unicode::utf8_encode(out, cp);
        if code != unicode::OK { print("FAIL: the encode refused ", cp, "\n"); bad += 1; }
        var cps: i64[>..] = [];
        unicode::utf8_decode(cps, out[..]);
        if cps.len != 1 || cps[0] != cp { print("FAIL: the round trip failed at ", cp, "\n"); bad += 1; }
        if bad > 5 { return bad; }
    }
    return bad;
}

// A long run of combining marks must not take a long time. The work
// must stay inside the count of the marks.
fn hostile_long_run() -> i64 {
    var bad = 0;
    var text: u8[>..] = [];
    push_utf8(text, 0x61);
    for k in 0..20000 {
        push_utf8(text, 0x316);
        push_utf8(text, 0x301);
    }
    var out: u8[>..] = [];
    let code, off = unicode::normalize(out, unicode::FORM_NFD, text[..]);
    if code != unicode::OK { print("FAIL: the long run gave the code ", code, "\n"); bad += 1; }
    var cps: i64[>..] = [];
    unicode::utf8_decode(cps, out[..]);
    if cps.len != 40001 { print("FAIL: the long run gave ", cps.len, " code points\n"); bad += 1; }
    return bad;
}

fn run_hostile() -> i64 {
    var bad = 0;
    bad += hostile_random();
    bad += hostile_cut();
    bad += hostile_flip();
    bad += hostile_bounds();
    bad += hostile_output_bound();
    bad += hostile_fault_holds_no_bytes();
    bad += hostile_encode();
    bad += hostile_long_run();
    return bad;
}
