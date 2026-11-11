// The confusable table of the standard, for the defense against look
// alike identifiers.
//
// The skeleton of a text is its key under the confusable table. The
// text takes the canonical form first, then the code points of
// Default_Ignorable_Code_Point drop out, then every code point maps
// through the table, and the canonical form runs once more over the
// result. The skeleton keeps the case. Two texts with the same
// skeleton read the same to a person, and a caller can use the test to
// refuse an identifier that imitates another.
namespace unicode;

import std;

// The target of one source code point: the index of its row. -1 when
// the code point has no row.
fn conf_row(cp: i64) -> i64 {
    return find_exact(CONF_CP[..], cp);
}

// Writes the skeleton of s into out. A bad byte gives ERR_BAD_UTF8
// and the offset of the first bad byte. A text above MAX_INPUT or a
// result above MAX_OUTPUT gives ERR_TOO_LONG. Either fault leaves out
// empty.
fn skeleton(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var src: i64[>..] = [];
    let code, off = utf8_decode(src, s);
    if code != OK { return code, off; }
    // The canonical form of the text.
    var canon: i64[>..] = [];
    let c = normalize_cps(canon, src[..], FORM_NFD);
    if c != OK { return c, -1; }
    // The map: the default ignorables drop out, the other code points
    // take their target.
    var mapped: i64[>..] = [];
    for k in 0..canon.len {
        if has_property(canon[k], PROP_DEFAULT_IGNORABLE_CODE_POINT) { continue; }
        let row = conf_row(canon[k]);
        if row < 0 {
            mapped.push(canon[k]);
        } else {
            for j in CONF_OFF[row]..CONF_OFF[row + 1] { mapped.push(CONF_POOL[j]); }
        }
        if mapped.len > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG, -1;
        }
    }
    // The canonical form of the result.
    var composed: i64[>..] = [];
    let c2 = normalize_cps(composed, mapped[..], FORM_NFD);
    if c2 != OK { return c2, -1; }
    let c3 = encode_all(out, composed[..]);
    return c3, -1;
}

// True when the two texts have the same skeleton, so a person reads
// them the same. A bad byte in a text gives false. The call has no
// fault code.
fn confusable(a: const u8[:], b: const u8[:]) -> bool {
    var sa: u8[>..] = [];
    var sb: u8[>..] = [];
    let c1, _ = skeleton(sa, a);
    if c1 != OK { return false; }
    let c2, _ = skeleton(sb, b);
    if c2 != OK { return false; }
    return sa[..] == sb[..];
}
