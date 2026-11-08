// The general category and the canonical combining class.
namespace unicode;

import std;

// The category names, two letters each, in the order of the CAT_ constants.
const CAT_NAMES: u8[] = "CnLuLlLtLmLoMnMcMeNdNlNoPcPdPsPePiPfPoSmScSkSoZsZlZpCcCfCsCo";

// The general category of a code point, as a CAT_ constant. A value
// outside U+0000 to U+10FFFF gives CAT_CN.
fn category(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return CAT_CN; }
    return CAT_VAL[last_at_or_below(CAT_START[..], cp)];
}

// The two letter name of the category of a code point, such as "Lu".
fn category_name(cp: i64) -> const u8[:] {
    let c = category(cp);
    return CAT_NAMES[2 * c..2 * c + 2];
}

// The canonical combining class of a code point, from 0 to 240. A value
// outside U+0000 to U+10FFFF gives 0.
fn combining_class(cp: i64) -> i64 {
    if cp < 0 || cp > 0x10FFFF { return 0; }
    let i = last_at_or_below(CCC_START[..], cp);
    if i >= 0 && cp <= CCC_END[i] { return CCC_VAL[i]; }
    return 0;
}
