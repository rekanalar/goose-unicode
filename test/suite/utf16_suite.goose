// Tests for the UTF-16 encodings.
namespace suite;

import std;
import unicode from "../..";

// The code points of one case of the test file.
fn u16_case(case: i64) -> i64[>..] {
    let start = U16_OFF[case];
    let n = U16_POOL[start];
    var out: i64[>..] = [];
    for k in 1..n + 1 { out.push(U16_POOL[start + k]); }
    return out;
}

// The bytes of the code points, in the given byte order.
fn u16_bytes(cps: const i64[:], big_endian: bool) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..cps.len {
        let cp = cps[k];
        if cp < 0x10000 {
            if big_endian {
                out.push((cp >> 8) as u8);
                out.push(cp as u8);
            } else {
                out.push(cp as u8);
                out.push((cp >> 8) as u8);
            }
        } else {
            let v = cp - 0x10000;
            let hi = 0xD800 + (v >> 10);
            let lo = 0xDC00 + (v & 0x3FF);
            if big_endian {
                out.push((hi >> 8) as u8);
                out.push(hi as u8);
                out.push((lo >> 8) as u8);
                out.push(lo as u8);
            } else {
                out.push(hi as u8);
                out.push((hi >> 8) as u8);
                out.push(lo as u8);
                out.push((lo >> 8) as u8);
            }
        }
    }
    return out;
}

// Every case of the test file: the encode gives the bytes that the
// decode reads back, in both byte orders.
fn u16_cases() -> i64 {
    var bad = 0;
    for c in 0..U16_OFF.len - 1 {
        let cps = u16_case(c);
        for big in 0..2 {
            let bytes = u16_bytes(cps[..], big == 1);
            // The encode must give the same bytes.
            var made: u8[>..] = [];
            let made_code = unicode::utf16_encode(made, cps[..], big == 1);
            if made_code != unicode::OK || made.len != bytes.len {
                print("FAIL: the case ", c, " encoded to ", made.len, " bytes\n");
                bad += 1;
                break;
            }
            for k in 0..bytes.len {
                if made[k] != bytes[k] {
                    print("FAIL: the case ", c, " encodes a wrong byte at ", k, "\n");
                    bad += 1;
                    break;
                }
            }
            var back: i64[>..] = [];
            let code, off = unicode::utf16_decode(back, bytes[..], big == 1);
            if code != unicode::OK {
                print("FAIL: the case ", c, " gave the code ", code, "\n");
                bad += 1;
                break;
            }
            if back.len != cps.len {
                print("FAIL: the case ", c, " gave ", back.len, " code points and not ", cps.len, "\n");
                bad += 1;
                break;
            }
            for k in 0..cps.len {
                if back[k] != cps[k] {
                    print("FAIL: the case ", c, " differs at the code point ", k, "\n");
                    bad += 1;
                    break;
                }
            }
            if bad > 5 { return bad; }
        }
    }
    return bad;
}

// The lengths and the surrogate test of the Go library.
fn u16_names() -> i64 {
    var bad = 0;
    if unicode::utf16_rune_len(0x41) != 1 { print("FAIL: the length of a letter\n"); bad += 1; }
    if unicode::utf16_rune_len(0xFFFF) != 1 { print("FAIL: the length of the last unit\n"); bad += 1; }
    if unicode::utf16_rune_len(0x10000) != 2 { print("FAIL: the length of a pair\n"); bad += 1; }
    if unicode::utf16_rune_len(0x10FFFF) != 2 { print("FAIL: the length of the last pair\n"); bad += 1; }
    if unicode::utf16_rune_len(0xD800) != 0 { print("FAIL: the length of a surrogate\n"); bad += 1; }
    if unicode::utf16_rune_len(0x110000) != 0 { print("FAIL: the length of a value too large\n"); bad += 1; }
    if unicode::utf16_rune_len(-1) != 0 { print("FAIL: the length of a negative value\n"); bad += 1; }
    if !unicode::utf16_is_surrogate(0xD800) { print("FAIL: the first surrogate\n"); bad += 1; }
    if !unicode::utf16_is_surrogate(0xDFFF) { print("FAIL: the last surrogate\n"); bad += 1; }
    if unicode::utf16_is_surrogate(0xD7FF) { print("FAIL: the code point before the range\n"); bad += 1; }
    if unicode::utf16_is_surrogate(0xE000) { print("FAIL: the code point after the range\n"); bad += 1; }
    if unicode::utf16_is_surrogate(0x41) { print("FAIL: a letter is a surrogate\n"); bad += 1; }
    return bad;
}

// The bytes of a text that a user knows.
fn u16_known() -> i64 {
    var bad = 0;
    let cps: i64[>..] = [0x41, 0x1F600];
    let le = u16_bytes(cps[..], false);
    if le.len != 6 || le[0] != 0x41 || le[1] != 0x00 || le[2] != 0x3D || le[3] != 0xD8 {
        print("FAIL: the little endian bytes differ\n");
        bad += 1;
    }
    let be = u16_bytes(cps[..], true);
    if be.len != 6 || be[0] != 0x00 || be[1] != 0x41 || be[2] != 0xD8 || be[3] != 0x3D {
        print("FAIL: the big endian bytes differ\n");
        bad += 1;
    }
    // The encode must give the same bytes.
    var out: u8[>..] = [];
    let code = unicode::utf16_encode(out, cps[..], false);
    if code != unicode::OK || out.len != le.len {
        print("FAIL: the encode gave the code ", code, "\n");
        bad += 1;
    } else {
        for k in 0..le.len {
            if out[k] != le[k] { print("FAIL: the encoded bytes differ at ", k, "\n"); bad += 1; break; }
        }
    }
    // The encode clears the buffer of the caller first.
    out.push(0x7A);
    let code2 = unicode::utf16_encode(out, cps[..], true);
    if code2 != unicode::OK || out.len != be.len { print("FAIL: the encode did not clear the buffer\n"); bad += 1; }
    return bad;
}

// A lone surrogate and an odd count of bytes are faults. The Go library
// writes U+FFFD for them.
fn u16_bad() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    // A high surrogate alone.
    let lone: u8[>..] = [0x00, 0xD8];
    let code, off = unicode::utf16_decode(out, lone[..], false);
    if code != unicode::ERR_BAD_UTF16 || off != 0 { print("FAIL: the lone surrogate gave ", code, " at ", off, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault left code points\n"); bad += 1; }
    // A low surrogate alone.
    let low: u8[>..] = [0x00, 0xDC];
    let code2, off2 = unicode::utf16_decode(out, low[..], false);
    if code2 != unicode::ERR_BAD_UTF16 || off2 != 0 { print("FAIL: the low surrogate gave ", code2, "\n"); bad += 1; }
    // A high surrogate with a letter after it.
    let pair: u8[>..] = [0x00, 0xD8, 0x41, 0x00];
    let code3, off3 = unicode::utf16_decode(out, pair[..], false);
    if code3 != unicode::ERR_BAD_UTF16 || off3 != 0 { print("FAIL: the broken pair gave ", code3, " at ", off3, "\n"); bad += 1; }
    // An odd count of bytes.
    let odd: u8[>..] = [0x41];
    let code4, off4 = unicode::utf16_decode(out, odd[..], false);
    if code4 != unicode::ERR_BAD_UTF16 || off4 != 0 { print("FAIL: the odd count gave ", code4, " at ", off4, "\n"); bad += 1; }
    // An odd count of bytes with a lone surrogate before the tail. The
    // offset names the surrogate, the first bad byte.
    let oddLone: u8[>..] = [0x00, 0xD8, 0x41];
    let codeOdd, offOdd = unicode::utf16_decode(out, oddLone[..], false);
    if codeOdd != unicode::ERR_BAD_UTF16 || offOdd != 0 { print("FAIL: the odd lone gave ", codeOdd, " at ", offOdd, "\n"); bad += 1; }
    // An odd count of bytes after a good unit. The offset names the tail
    // and the buffer stays empty.
    let oddTail: u8[>..] = [0x41, 0x00, 0x42];
    let codeTail, offTail = unicode::utf16_decode(out, oddTail[..], false);
    if codeTail != unicode::ERR_BAD_UTF16 || offTail != 2 { print("FAIL: the odd tail gave ", codeTail, " at ", offTail, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the odd tail left code points\n"); bad += 1; }
    // A fault after two good code points leaves the buffer empty.
    let mixed: u8[>..] = [0x41, 0x00, 0x42, 0x00, 0x00, 0xD8];
    let codeMid, offMid = unicode::utf16_decode(out, mixed[..], false);
    if codeMid != unicode::ERR_BAD_UTF16 || offMid != 4 { print("FAIL: the late fault gave ", codeMid, " at ", offMid, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the late fault left code points\n"); bad += 1; }
    // A high surrogate at the end of the text.
    let end: u8[>..] = [0x41, 0x00, 0x00, 0xD8];
    let code5, off5 = unicode::utf16_decode(out, end[..], false);
    if code5 != unicode::ERR_BAD_UTF16 || off5 != 2 { print("FAIL: the surrogate at the end gave ", code5, " at ", off5, "\n"); bad += 1; }
    // A pair of two high surrogates.
    let two: u8[>..] = [0x00, 0xD8, 0x00, 0xD8];
    let code6, off6 = unicode::utf16_decode(out, two[..], false);
    if code6 != unicode::ERR_BAD_UTF16 || off6 != 0 { print("FAIL: the two surrogates gave ", code6, "\n"); bad += 1; }
    // A valid pair must not be a fault.
    let good: u8[>..] = [0x3D, 0xD8, 0x00, 0xDE];
    let code7, off7 = unicode::utf16_decode(out, good[..], false);
    if code7 != unicode::OK || out.len != 1 || out[0] != 0x1F600 { print("FAIL: the valid pair gave ", code7, "\n"); bad += 1; }
    // The encode refuses a surrogate and a value too large.
    let cps1: i64[>..] = [0xD800];
    var bytes: u8[>..] = [];
    let code8 = unicode::utf16_encode(bytes, cps1[..], false);
    if code8 != unicode::ERR_BAD_CODEPOINT || bytes.len != 0 { print("FAIL: the encode took a surrogate\n"); bad += 1; }
    let cps2: i64[>..] = [0x110000];
    let code9 = unicode::utf16_encode(bytes, cps2[..], false);
    if code9 != unicode::ERR_BAD_CODEPOINT { print("FAIL: the encode took a value too large\n"); bad += 1; }
    return bad;
}

// The faults of the calls.
fn u16_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 2 { big.push(0x41); }
    let code, off = unicode::utf16_decode(out, big[..], false);
    if code != unicode::ERR_TOO_LONG { print("FAIL: a long text was accepted\n"); bad += 1; }
    // The encode takes at most MAX_INPUT code points. The bound of the
    // result follows from it, because a code point takes at most four
    // bytes.
    var many: i64[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { many.push(0x41); }
    var bytes: u8[>..] = [];
    let code2 = unicode::utf16_encode(bytes, many[..], false);
    if code2 != unicode::ERR_TOO_LONG { print("FAIL: many code points were accepted\n"); bad += 1; }
    if bytes.len != 0 { print("FAIL: the fault left bytes\n"); bad += 1; }
    var cps: i64[>..] = [0x41];
    let code3 = unicode::utf16_encode(bytes, cps[..], false);
    if code3 != unicode::OK { print("FAIL: the encode gave the code ", code3, "\n"); bad += 1; }
    return bad;
}

// A long text must not take a long time. The work stays inside the
// count of the code points.
fn u16_hostile() -> i64 {
    var bad = 0;
    let n = 200000;
    var cps: i64[>..] = [];
    for k in 0..n { cps.push(0x1F600); }
    var bytes: u8[>..] = [];
    let code = unicode::utf16_encode(bytes, cps[..], false);
    if code != unicode::OK || bytes.len != n * 4 { print("FAIL: the long text gave ", bytes.len, " bytes\n"); bad += 1; }
    var back: i64[>..] = [];
    let code2, off = unicode::utf16_decode(back, bytes[..], false);
    if code2 != unicode::OK || back.len != n { print("FAIL: the long text gave ", back.len, " code points\n"); bad += 1; }
    // A text of surrogates alone must fail at the first one.
    var bad2: i64[>..] = [];
    for k in 0..n { bad2.push(0xD800); }
    var bytes2: u8[>..] = [];
    let code3 = unicode::utf16_encode(bytes2, bad2[..], false);
    if code3 != unicode::ERR_BAD_CODEPOINT { print("FAIL: the surrogates were accepted\n"); bad += 1; }
    return bad;
}

fn run_utf16() -> i64 {
    var bad = 0;
    if want("utf16", "u16_cases") { bad += u16_cases(); }
    if want("utf16", "u16_names") { bad += u16_names(); }
    if want("utf16", "u16_known") { bad += u16_known(); }
    if want("utf16", "u16_bad") { bad += u16_bad(); }
    if want("utf16", "u16_faults") { bad += u16_faults(); }
    if want("utf16", "u16_hostile") { bad += u16_hostile(); }
    return bad;
}
