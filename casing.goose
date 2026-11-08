// Case conversion and case folding.
//
// Upper and lower case use the simple one to one mappings, so the result
// has one code point for each code point of the input. The final sigma
// and other rules that depend on the text around a letter are not built
// in. Folding uses the full case folding table, where one code point can
// give up to three.
namespace unicode;

import std;

// The simple upper case code point. The code point itself when none maps.
fn upper_cp(cp: i64) -> i64 {
    let i = find_exact(UP_CP[..], cp);
    if i < 0 { return cp; }
    return UP_TO[i];
}

// The simple lower case code point. The code point itself when none maps.
fn lower_cp(cp: i64) -> i64 {
    let i = find_exact(LO_CP[..], cp);
    if i < 0 { return cp; }
    return LO_TO[i];
}

// kind: 0 upper, 1 lower, 2 fold. Writes the converted text of s to out.
fn convert_case(out: u8[>..]&, s: const u8[:], kind: i64) -> i64, i64 {
    out.clear();
    if s.len > MAX_INPUT { return ERR_TOO_LONG, -1; }
    var i: i64 = 0;
    while i < s.len {
        let cp, n = decode_at(s, i);
        if cp < 0 {
            out.clear();
            return ERR_BAD_UTF8, i;
        }
        if kind == 0 {
            push_utf8(out, upper_cp(cp));
        } else if kind == 1 {
            push_utf8(out, lower_cp(cp));
        } else {
            let k = find_exact(FOLD_CP[..], cp);
            if k < 0 {
                push_utf8(out, cp);
            } else {
                for j in FOLD_OFF[k]..FOLD_OFF[k + 1] { push_utf8(out, FOLD_POOL[j]); }
            }
        }
        if out.len > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG, -1;
        }
        i += n;
    }
    return OK, -1;
}

// Converts s to upper case. Returns a fault code and the offset of the
// first bad byte, or OK and -1.
fn to_upper(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return convert_case(out, s, 0);
}

// Converts s to lower case.
fn to_lower(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return convert_case(out, s, 1);
}

// Folds s for caseless compare: two texts that differ in case only give
// the same bytes.
fn fold_case(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return convert_case(out, s, 2);
}
