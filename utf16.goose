// UTF-16 decode and encode.
//
// The rules of UTF-16 are arithmetic, so the package holds no table for
// them. A code point below U+10000 takes one unit. A code point at or
// above U+10000 takes two units: a high surrogate and a low surrogate.
// A high surrogate must be followed by a low surrogate.
//
// The Go library writes U+FFFD for a lone surrogate. The package
// refuses it and names the byte offset of the first bad byte, as the
// UTF-8 decoder of the package does.
namespace unicode;

import std;

// True when the code point is a surrogate, in the range U+D800 to
// U+DFFF.
fn utf16_is_surrogate(cp: i64) -> bool {
    return cp >= 0xD800 && cp <= 0xDFFF;
}

// The number of UTF-16 units of the code point: 1 or 2. A code point
// that no UTF-16 text can hold gives 0. A surrogate gives 0, because no
// UTF-16 text holds a surrogate alone.
fn utf16_rune_len(cp: i64) -> i64 {
    if !scalar_ok(cp) { return 0; }
    if cp < 0x10000 { return 1; }
    return 2;
}

// Reads the unit that starts at byte i. Returns the unit and the number
// of bytes. The caller keeps both bytes of the unit inside s.
fn utf16_unit(s: const u8[:], i: i64, big_endian: bool) -> i64 {
    let lo = s[i] as i64;
    let hi = s[i + 1] as i64;
    if big_endian { return (lo << 8) | hi; }
    return (hi << 8) | lo;
}

// Appends the two bytes of one unit to out.
fn utf16_put(out: u8[>..]&, u: i64, big_endian: bool) {
    if big_endian {
        out.push((u >> 8) as u8);
        out.push(u as u8);
    } else {
        out.push(u as u8);
        out.push((u >> 8) as u8);
    }
}

// Decodes the UTF-16 bytes of s into code points. out is cleared first.
// A lone surrogate and an odd count of bytes give ERR_BAD_UTF16 and the
// byte offset of the first bad byte, and out stays empty. Otherwise the
// call returns OK and -1.
fn utf16_decode(out: i64[>..]&, s: const u8[:], big_endian: bool) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var i: i64 = 0;
    while i < s.len {
        // A tail of one byte cannot hold a unit.
        if i + 2 > s.len { out.clear(); return ERR_BAD_UTF16, i; }
        let u = utf16_unit(s, i, big_endian);
        if u >= 0xD800 && u <= 0xDBFF {
            // A high surrogate must be followed by a low surrogate.
            if i + 4 > s.len { out.clear(); return ERR_BAD_UTF16, i; }
            let v = utf16_unit(s, i + 2, big_endian);
            if v < 0xDC00 || v > 0xDFFF { out.clear(); return ERR_BAD_UTF16, i; }
            out.push(0x10000 + ((u - 0xD800) << 10) + (v - 0xDC00));
            i += 4;
            continue;
        }
        if u >= 0xDC00 && u <= 0xDFFF {
            // A low surrogate alone is a fault.
            out.clear();
            return ERR_BAD_UTF16, i;
        }
        out.push(u);
        i += 2;
    }
    return OK, -1;
}

// Writes the UTF-16 bytes of the code points of cps into out. out is
// cleared first. A surrogate and a value above U+10FFFF give
// ERR_BAD_CODEPOINT and write nothing. The count of the code points
// must stay at or below MAX_INPUT. The loop checks the length of the
// result against MAX_OUTPUT and clears out above it.
fn utf16_encode(out: u8[>..]&, cps: const i64[:], big_endian: bool) -> i64 {
    out.clear();
    if cps.len > MAX_INPUT { return ERR_TOO_LONG; }
    for k in 0..cps.len {
        let cp = cps[k];
        let len = utf16_rune_len(cp);
        if len == 0 {
            out.clear();
            return ERR_BAD_CODEPOINT;
        }
        if out.len + len * 2 > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG;
        }
        if len == 1 {
            utf16_put(out, cp, big_endian);
        } else {
            let v = cp - 0x10000;
            utf16_put(out, 0xD800 + (v >> 10), big_endian);
            utf16_put(out, 0xDC00 + (v & 0x3FF), big_endian);
        }
    }
    return OK;
}

// Decodes the UTF-16 bytes of s and writes U+FFFD for each bad part. A
// lone surrogate and a final odd byte each give one U+FFFD. A high
// surrogate before any other unit gives U+FFFD, and that unit is read
// again. out is cleared first. The call returns OK and the number of
// U+FFFD that it wrote. A text above MAX_INPUT bytes gives ERR_TOO_LONG
// and 0.
fn utf16_decode_lossy(out: i64[>..]&, s: const u8[:], big_endian: bool) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var i: i64 = 0;
    var bad: i64 = 0;
    while i < s.len {
        if i + 2 > s.len { out.push(0xFFFD); bad += 1; break; }
        let u = utf16_unit(s, i, big_endian);
        if u >= 0xD800 && u <= 0xDBFF {
            if i + 4 > s.len { out.push(0xFFFD); bad += 1; break; }
            let v = utf16_unit(s, i + 2, big_endian);
            if v >= 0xDC00 && v <= 0xDFFF {
                out.push(0x10000 + ((u - 0xD800) << 10) + (v - 0xDC00));
                i += 4;
            } else {
                out.push(0xFFFD);
                bad += 1;
                i += 2;
            }
            continue;
        }
        if u >= 0xDC00 && u <= 0xDFFF {
            out.push(0xFFFD);
            bad += 1;
        } else {
            out.push(u);
        }
        i += 2;
    }
    return OK, bad;
}

// Decodes UTF-16 bytes and reads the byte order from a leading mark.
// FE FF means big endian and FF FE means little endian. The mark does not
// reach out. Bytes with no mark use default_big_endian. The fault offset
// counts from the first byte of s, the mark included.
fn utf16_decode_auto(out: i64[>..]&, s: const u8[:], default_big_endian: bool) -> i64, i64 {
    var be = default_big_endian;
    var skip: i64 = 0;
    if s.len >= 2 && s[0] == 0xFE && s[1] == 0xFF {
        be = true;
        skip = 2;
    } else if s.len >= 2 && s[0] == 0xFF && s[1] == 0xFE {
        be = false;
        skip = 2;
    }
    let code, off = utf16_decode(out, s[skip..s.len], be);
    if off >= 0 { return code, off + skip; }
    return code, off;
}
