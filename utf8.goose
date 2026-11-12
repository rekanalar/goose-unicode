// UTF-8 decode, encode and validation.
//
// The standard library walk gives U+FFFD for a bad byte, so it cannot
// report a fault. The package reads the bytes itself and applies the
// byte ranges of the Unicode standard. It rejects overlong forms,
// surrogates, truncated sequences and values above U+10FFFF.
namespace unicode;

import std;

// Reads the sequence that starts at byte i. Returns the code point and
// the number of bytes. A bad byte gives -1 and 1, so each bad byte is a
// unit of its own. The caller keeps i below the length of s.
fn decode_at(s: const u8[:], i: i64) -> i64, i64 {
    let b0 = s[i] as i64;
    if b0 < 0x80 { return b0, 1; }
    if b0 < 0xC2 || b0 > 0xF4 { return -1, 1; }
    var need: i64 = 1;
    var lo: i64 = 0x80;
    var hi: i64 = 0xBF;
    var cp: i64 = b0 & 0x1F;
    if b0 >= 0xF0 {
        need = 3;
        cp = b0 & 0x07;
        if b0 == 0xF0 { lo = 0x90; }
        if b0 == 0xF4 { hi = 0x8F; }
    } else if b0 >= 0xE0 {
        need = 2;
        cp = b0 & 0x0F;
        if b0 == 0xE0 { lo = 0xA0; }
        if b0 == 0xED { hi = 0x9F; }
    }
    if i + need >= s.len { return -1, 1; }
    let b1 = s[i + 1] as i64;
    if b1 < lo || b1 > hi { return -1, 1; }
    cp = (cp << 6) | (b1 & 0x3F);
    for k in 2..need + 1 {
        let b = s[i + k] as i64;
        if b < 0x80 || b > 0xBF { return -1, 1; }
        cp = (cp << 6) | (b & 0x3F);
    }
    return cp, need + 1;
}

// Reads the sequence that starts at byte i for the lossy decode. Returns
// the code point and the number of bytes. A bad part gives -1 and its
// length: the lead byte and each byte after it that the standard
// accepts. The next call starts at the first byte that broke the form.
// The caller keeps i below the length of s.
fn decode_lossy_at(s: const u8[:], i: i64) -> i64, i64 {
    let b0 = s[i] as i64;
    if b0 < 0x80 { return b0, 1; }
    if b0 < 0xC2 || b0 > 0xF4 { return -1, 1; }
    var need: i64 = 1;
    var lo: i64 = 0x80;
    var hi: i64 = 0xBF;
    var cp: i64 = b0 & 0x1F;
    if b0 >= 0xF0 {
        need = 3;
        cp = b0 & 0x07;
        if b0 == 0xF0 { lo = 0x90; }
        if b0 == 0xF4 { hi = 0x8F; }
    } else if b0 >= 0xE0 {
        need = 2;
        cp = b0 & 0x0F;
        if b0 == 0xE0 { lo = 0xA0; }
        if b0 == 0xED { hi = 0x9F; }
    }
    var k: i64 = 1;
    while k <= need {
        if i + k >= s.len { return -1, k; }
        let b = s[i + k] as i64;
        if k == 1 {
            if b < lo || b > hi { return -1, k; }
        } else if b < 0x80 || b > 0xBF {
            return -1, k;
        }
        cp = (cp << 6) | (b & 0x3F);
        k += 1;
    }
    return cp, need + 1;
}

// Decodes s into code points and writes U+FFFD for each maximal bad part,
// as the decoder of the WHATWG standard does. out is cleared first. The
// call returns OK and the number of U+FFFD that it wrote. A text above
// MAX_INPUT bytes gives ERR_TOO_LONG and 0, and out stays empty.
fn utf8_decode_lossy(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, 0; }
    var i: i64 = 0;
    var bad: i64 = 0;
    while i < s.len {
        let cp, n = decode_lossy_at(s, i);
        if cp < 0 {
            out.push(0xFFFD);
            bad += 1;
        } else {
            out.push(cp);
        }
        i += n;
    }
    return OK, bad;
}

// Copies s to out without a leading UTF-8 byte order mark. out is cleared
// first. A text above MAX_INPUT bytes gives ERR_TOO_LONG and out stays
// empty. The call does not check that the text is UTF-8.
fn utf8_strip_bom(out: u8[>..]&, s: const u8[:]) -> i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG; }
    var from: i64 = 0;
    if s.len >= 3 && s[0] == 0xEF && s[1] == 0xBB && s[2] == 0xBF { from = 3; }
    for k in from..s.len { out.push(s[k]); }
    return OK;
}

// True when the code point is a Unicode scalar value.
fn scalar_ok(cp: i64) -> bool {
    return cp >= 0 && cp <= 0x10FFFF && !utf16_is_surrogate(cp);
}

// Reads the sequence that ends at byte j. Returns the code point and
// the number of bytes. A bad form gives -1 and 1.
fn decode_back(s: const u8[:], j: i64) -> i64, i64 {
    if j <= 0 { return -1, 1; }
    var start: i64 = j - 1;
    var back: i64 = 0;
    while start > 0 && s[start] >= 0x80 && s[start] < 0xC0 && back < 3 {
        start -= 1;
        back += 1;
    }
    let cp, len = decode_at(s, start);
    if cp < 0 || start + len != j { return -1, 1; }
    return cp, len;
}

// True when every byte of s belongs to a well formed sequence.
fn utf8_valid(s: const u8[:]) -> bool {
    if s.len > MAX_INPUT { return false; }
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 { return false; }
        i += n;
    }
    return true;
}

// Decodes s into code points. out is cleared first. On a bad byte the
// call returns ERR_BAD_UTF8 and the offset of the first bad byte, and out
// stays empty. Otherwise it returns OK and -1.
fn utf8_decode(out: i64[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 {
            out.clear();
            return ERR_BAD_UTF8, i;
        }
        out.push(cp);
        i += n;
    }
    return OK, -1;
}

// Appends the UTF-8 form of one code point to out. A surrogate, a
// negative value or a value above U+10FFFF gives ERR_BAD_CODEPOINT and
// writes nothing.
fn utf8_encode(out: u8[>..]&, cp: i64) -> i64 {
    if !scalar_ok(cp) { return ERR_BAD_CODEPOINT; }
    push_utf8(out, cp);
    return OK;
}

// Appends the code points of cps to out. The result is at most MAX_OUTPUT
// bytes. A longer result gives ERR_TOO_LONG and clears out.
fn encode_all(out: u8[>..]&, cps: const i64[:]) -> i64 {
    out.clear();
    for k in 0..cps.len {
        push_utf8(out, cps[k]);
        if out.len > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG;
        }
    }
    return OK;
}
