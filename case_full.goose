// The full case mappings.
//
// The full mappings give more than one code point for one code point of
// the input, so the German sharp s gives SS and the ligatures split. The
// lower case follows the rule of the final sigma: a sigma at the end of
// a word gives the final sigma. The simple mappings of the casing module
// keep their behavior.
//
// The rule of the final sigma: the sigma is final when a cased letter
// holds before it, with only case ignorable characters between, and no
// cased letter holds after it, with only case ignorable characters
// between.
namespace unicode;

import std;

// True when the code point is a letter with case.
fn is_cased(cp: i64) -> bool {
    return run_at(CASED_START[..], CASED_END[..], cp) >= 0;
}

// True when the case of the code point changes no letter.
fn is_ignorable(cp: i64) -> bool {
    return run_at(IGNORABLE_START[..], IGNORABLE_END[..], cp) >= 0;
}

// The full upper case of the text. Returns a fault code and the offset
// of the first bad byte, or OK and -1.
fn to_upper_full(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return convert_full(out, s, 0);
}

// The full lower case of the text. A sigma at the end of a word gives
// the final sigma.
fn to_lower_full(out: u8[>..]&, s: const u8[:]) -> i64, i64 {
    return convert_full(out, s, 1);
}

// kind: 0 upper, 1 lower. Walks the text once and writes the result.
fn convert_full(out: u8[>..]&, s: const u8[:], kind: i64) -> i64, i64 {
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
            if !push_full(out, UFULL_CP[..], UFULL_OFF[..], UFULL_POOL[..], cp) {
                push_utf8(out, upper_cp(cp));
            }
        } else {
            push_lower_full(out, s, i, n, cp);
        }
        if out.len > MAX_OUTPUT {
            out.clear();
            return ERR_TOO_LONG, -1;
        }
        i += n;
    }
    return OK, -1;
}

// Writes the full lower case of the code point at the byte offset i of
// the text. The capital sigma gives the final sigma at the end of a word.
fn push_lower_full(out: u8[>..]&, s: const u8[:], i: i64, n: i64, cp: i64) {
    if cp == SIGMA_CP[0] {
        if sigma_is_final(s, i, n) {
            push_utf8(out, SIGMA_FINAL[0]);
        } else {
            push_utf8(out, 0x3C3);
        }
    } else if !push_full(out, LFULL_CP[..], LFULL_OFF[..], LFULL_POOL[..], cp) {
        push_utf8(out, lower_cp(cp));
    }
}

// Writes the full mapping of the code point when the table holds one.
fn push_full(out: u8[>..]&, cps: const i64[:], offs: const i64[:], pool: const i64[:], cp: i64) -> bool {
    let k = find_exact(cps, cp);
    if k < 0 { return false; }
    for j in offs[k]..offs[k + 1] { push_utf8(out, pool[j]); }
    return true;
}

// The rule of the final sigma at the byte offset i of the text. The
// sigma is final when a cased letter holds before it and no cased
// letter holds after it, with case ignorable characters between.
fn sigma_is_final(s: const u8[:], i: i64, n: i64) -> bool {
    var cased_before = false;
    var j: i64 = i;
    while j > 0 {
        let cp, len = decode_back(s, j);
        if cp < 0 { break; }
        j -= len;
        if is_ignorable(cp) { continue; }
        cased_before = is_cased(cp);
        break;
    }
    if !cased_before { return false; }
    var cased_after = false;
    j = i + n;
    while j < s.len {
        let cp, len = decode_at(s, j);
        if cp < 0 { break; }
        j += len;
        if is_ignorable(cp) { continue; }
        cased_after = is_cased(cp);
        break;
    }
    return !cased_after;
}
