// UTF-32 decode and encode.
//
// The rules of UTF-32 are arithmetic, so the package holds no table for
// them. Every code point takes one unit of four bytes. A unit must hold
// a scalar value: a surrogate and a value above U+10FFFF are faults.
//
// The strict codecs of Python refuse a surrogate too. The loose forms,
// such as a plain slice of `u32` in Rust, hold no rule at all. The
// package refuses and names the byte offset of the first bad byte, as
// the UTF-8 and UTF-16 decoders of the package do.
namespace unicode;

import std;

// The number of UTF-32 units of the code point: 1, or 0 when no UTF-32
// text can hold it.
fn utf32_rune_len(cp: i64) -> i64 {
    if scalar_ok(cp) { return 1; }
    return 0;
}

// Reads the unit that starts at byte i. The caller keeps all four bytes
// of the unit inside s.
fn utf32_unit(s: const u8[:], i: i64, big_endian: bool) -> i64 {
    if big_endian {
        return (s[i] as i64) << 24 | (s[i + 1] as i64) << 16
            | (s[i + 2] as i64) << 8 | (s[i + 3] as i64);
    }
    return (s[i + 3] as i64) << 24 | (s[i + 2] as i64) << 16
        | (s[i + 1] as i64) << 8 | (s[i] as i64);
}

// Appends the four bytes of one unit to out.
fn utf32_put(out: u8[>..]&, u: i64, big_endian: bool) {
    if big_endian {
        out.push((u >> 24) as u8);
        out.push((u >> 16) as u8);
        out.push((u >> 8) as u8);
        out.push(u as u8);
    } else {
        out.push(u as u8);
        out.push((u >> 8) as u8);
        out.push((u >> 16) as u8);
        out.push((u >> 24) as u8);
    }
}

// Decodes the UTF-32 bytes of s into code points. out is cleared first.
// A surrogate, a value above U+10FFFF and a length that no count of
// units gives give ERR_BAD_UTF32 and the byte offset of the first bad
// byte, and out stays empty. Otherwise the call returns OK and -1.
fn utf32_decode(out: i64[>..]&, s: const u8[:], big_endian: bool) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var i: i64 = 0;
    while i < s.len {
        // The tail cannot hold a whole unit.
        if i + 4 > s.len { out.clear(); return ERR_BAD_UTF32, i; }
        let u = utf32_unit(s, i, big_endian);
        if !scalar_ok(u) { out.clear(); return ERR_BAD_UTF32, i; }
        out.push(u);
        i += 4;
    }
    return OK, -1;
}

// Writes the UTF-32 bytes of the code points of cps into out. out is
// cleared first. A surrogate and a value above U+10FFFF give
// ERR_BAD_CODEPOINT and write nothing. The count of the code points
// must stay at or below MAX_INPUT. The loop checks the length of the
// result against MAX_OUTPUT and clears out above it.
fn utf32_encode(out: u8[>..]&, cps: const i64[:], big_endian: bool) -> i64 {
    out.clear();
    if cps.len > MAX_INPUT { return ERR_TOO_LONG; }
    for k in 0..cps.len {
        let cp = cps[k];
        if !scalar_ok(cp) {
            out.clear();
            return ERR_BAD_CODEPOINT;
        }
        if out.len + 4 > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG;
        }
        utf32_put(out, cp, big_endian);
    }
    return OK;
}
