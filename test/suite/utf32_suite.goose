// Tests for the UTF-32 encodings.
namespace suite;

import std;
import unicode from "../..";

// The code points of one case of the test file.
fn u32_case(case: i64) -> i64[>..] {
    let start = U32_OFF[case];
    let n = U32_POOL[start];
    var out: i64[>..] = [];
    for k in 1..n + 1 { out.push(U32_POOL[start + k]); }
    return out;
}

// The bytes of the code points, in the given byte order. The builder
// stands apart from the package, so a shared mistake cannot cancel out.
fn u32_bytes(cps: const i64[:], big_endian: bool) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..cps.len {
        let cp = cps[k];
        if big_endian {
            out.push((cp >> 24) as u8);
            out.push((cp >> 16) as u8);
            out.push((cp >> 8) as u8);
            out.push(cp as u8);
        } else {
            out.push(cp as u8);
            out.push((cp >> 8) as u8);
            out.push((cp >> 16) as u8);
            out.push((cp >> 24) as u8);
        }
    }
    return out;
}

// Every case of the test file: the encode gives the bytes that the
// decode reads back, in both byte orders.
fn u32_cases() -> i64 {
    var bad = 0;
    for c in 0..U32_OFF.len - 1 {
        let cps = u32_case(c);
        for big in 0..2 {
            let bytes = u32_bytes(cps[..], big == 1);
            var made: u8[>..] = [];
            let made_code = unicode::utf32_encode(made, cps[..], big == 1);
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
            let code, off = unicode::utf32_decode(back, bytes[..], big == 1);
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

// The lengths of the code points.
fn u32_names() -> i64 {
    var bad = 0;
    if unicode::utf32_rune_len(0x41) != 1 { print("FAIL: the length of a letter\n"); bad += 1; }
    if unicode::utf32_rune_len(0x10FFFF) != 1 { print("FAIL: the length of the last scalar\n"); bad += 1; }
    if unicode::utf32_rune_len(0xD800) != 0 { print("FAIL: the length of a surrogate\n"); bad += 1; }
    if unicode::utf32_rune_len(0x110000) != 0 { print("FAIL: the length of a value too large\n"); bad += 1; }
    if unicode::utf32_rune_len(-1) != 0 { print("FAIL: the length of a negative value\n"); bad += 1; }
    return bad;
}

// A surrogate, a value above U+10FFFF and a length that no count of
// units gives are faults.
fn u32_bad() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    // A surrogate.
    let lone: u8[>..] = [0x00, 0xD8, 0x00, 0x00];
    let code, off = unicode::utf32_decode(out, lone[..], false);
    if code != unicode::ERR_BAD_UTF32 || off != 0 { print("FAIL: the surrogate gave ", code, " at ", off, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the fault left code points\n"); bad += 1; }
    // A value above U+10FFFF.
    let big: u8[>..] = [0x01, 0x00, 0x11, 0x00];
    let code2, off2 = unicode::utf32_decode(out, big[..], false);
    if code2 != unicode::ERR_BAD_UTF32 || off2 != 0 { print("FAIL: the big unit gave ", code2, " at ", off2, "\n"); bad += 1; }
    // A good unit and a fault after it. The buffer stays empty.
    let mixed: u8[>..] = [0x41, 0x00, 0x00, 0x00, 0x00, 0xD8, 0x00, 0x00];
    let code3, off3 = unicode::utf32_decode(out, mixed[..], false);
    if code3 != unicode::ERR_BAD_UTF32 || off3 != 4 { print("FAIL: the late fault gave ", code3, " at ", off3, "\n"); bad += 1; }
    if out.len != 0 { print("FAIL: the late fault left code points\n"); bad += 1; }
    // Three bytes: no count of units.
    let tail: u8[>..] = [0x41, 0x00, 0x00];
    let code4, off4 = unicode::utf32_decode(out, tail[..], false);
    if code4 != unicode::ERR_BAD_UTF32 || off4 != 0 { print("FAIL: the short tail gave ", code4, " at ", off4, "\n"); bad += 1; }
    // Five bytes: the fault names the start of the short unit.
    let five: u8[>..] = [0x41, 0x00, 0x00, 0x00, 0x42];
    let code5, off5 = unicode::utf32_decode(out, five[..], false);
    if code5 != unicode::ERR_BAD_UTF32 || off5 != 4 { print("FAIL: the five bytes gave ", code5, " at ", off5, "\n"); bad += 1; }
    // The big endian order reads the same text.
    let be: u8[>..] = [0x00, 0x00, 0xD8, 0x00];
    let code6, off6 = unicode::utf32_decode(out, be[..], true);
    if code6 != unicode::ERR_BAD_UTF32 || off6 != 0 { print("FAIL: the big endian surrogate gave ", code6, " at ", off6, "\n"); bad += 1; }
    // The encode refuses a surrogate and a value too large.
    let cps1: i64[>..] = [0xD800];
    var bytes: u8[>..] = [];
    let code7 = unicode::utf32_encode(bytes, cps1[..], false);
    if code7 != unicode::ERR_BAD_CODEPOINT || bytes.len != 0 { print("FAIL: the encode took a surrogate\n"); bad += 1; }
    let cps2: i64[>..] = [0x110000];
    let code8 = unicode::utf32_encode(bytes, cps2[..], false);
    if code8 != unicode::ERR_BAD_CODEPOINT { print("FAIL: the encode took a value too large\n"); bad += 1; }
    // The encode clears the buffer of the caller first.
    let cps3: i64[>..] = [0x41, 0x1F600];
    var twice: u8[>..] = [];
    unicode::utf32_encode(twice, cps3[..], false);
    twice.push(0x7A);
    let code9 = unicode::utf32_encode(twice, cps3[..], true);
    let want = u32_bytes(cps3[..], true);
    if code9 != unicode::OK || twice.len != want.len { print("FAIL: the encode did not clear the buffer\n"); bad += 1; }
    return bad;
}

// The faults of the calls.
fn u32_faults() -> i64 {
    var bad = 0;
    var out: i64[>..] = [];
    var big: u8[>..] = [];
    for k in 0..unicode::MAX_INPUT + 2 { big.push(0x41); }
    let code, off = unicode::utf32_decode(out, big[..], false);
    if code != unicode::ERR_TOO_LONG { print("FAIL: a long text was accepted\n"); bad += 1; }
    var many: i64[>..] = [];
    for k in 0..unicode::MAX_INPUT + 1 { many.push(0x41); }
    var bytes: u8[>..] = [];
    let code2 = unicode::utf32_encode(bytes, many[..], false);
    if code2 != unicode::ERR_TOO_LONG { print("FAIL: many code points were accepted\n"); bad += 1; }
    if bytes.len != 0 { print("FAIL: the fault left bytes\n"); bad += 1; }
    return bad;
}

// A long text must not take a long time. The work stays inside the
// count of the code points.
fn u32_hostile() -> i64 {
    var bad = 0;
    let n = 200000;
    var cps: i64[>..] = [];
    for k in 0..n { cps.push(0x1F600); }
    var bytes: u8[>..] = [];
    let code = unicode::utf32_encode(bytes, cps[..], false);
    if code != unicode::OK || bytes.len != n * 4 { print("FAIL: the long text gave ", bytes.len, " bytes\n"); bad += 1; }
    var back: i64[>..] = [];
    let code2, off = unicode::utf32_decode(back, bytes[..], false);
    if code2 != unicode::OK || back.len != n { print("FAIL: the long text gave ", back.len, " code points\n"); bad += 1; }
    return bad;
}

fn run_utf32() -> i64 {
    var bad = 0;
    bad += u32_cases();
    bad += u32_names();
    bad += u32_bad();
    bad += u32_faults();
    bad += u32_hostile();
    return bad;
}
