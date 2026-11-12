// Byte order marks. The call names the mark at the start of a text.
namespace unicode;

import std;

// The kind of a byte order mark.
const BOM_NONE: i64 = 0;
const BOM_UTF8: i64 = 1;
const BOM_UTF16LE: i64 = 2;
const BOM_UTF16BE: i64 = 3;
const BOM_UTF32LE: i64 = 4;
const BOM_UTF32BE: i64 = 5;

// The kind of the mark at the start of s and the length of the mark in
// bytes. A text with no mark gives BOM_NONE and 0. The UTF-32 marks come
// first, so FF FE 00 00 is the UTF-32 little endian mark, as in the ICU
// library. WHATWG, Python and Go read those bytes as a UTF-16 mark
// followed by a null. The call reads at most 4 bytes and never faults.
fn bom_detect(s: const u8[:]) -> i64, i64 {
    if s.len >= 4 && s[0] == 0x00 && s[1] == 0x00 && s[2] == 0xFE && s[3] == 0xFF {
        return BOM_UTF32BE, 4;
    }
    if s.len >= 4 && s[0] == 0xFF && s[1] == 0xFE && s[2] == 0x00 && s[3] == 0x00 {
        return BOM_UTF32LE, 4;
    }
    if s.len >= 3 && s[0] == 0xEF && s[1] == 0xBB && s[2] == 0xBF { return BOM_UTF8, 3; }
    if s.len >= 2 && s[0] == 0xFE && s[1] == 0xFF { return BOM_UTF16BE, 2; }
    if s.len >= 2 && s[0] == 0xFF && s[1] == 0xFE { return BOM_UTF16LE, 2; }
    return BOM_NONE, 0;
}
