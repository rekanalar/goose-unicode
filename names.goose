// The code point of a name, the way back from `name`. The names are the
// names of the Character Database and the formal name aliases. The match
// ignores the case of ASCII letters and nothing else. A search over the
// sorted names takes at most 18 steps, and each step compares at most
// the bytes of the query.
namespace unicode;

import std;

// The longest name in the tables is 88 bytes. A longer query names
// nothing.
const MAX_NAME: i64 = 128;

// Compares the query with a name, folding the ASCII letters of the query
// to upper case. Gives -1, 0 or 1 for a query below, equal to or above
// the name.
fn name_compare(q: const u8[:], name: const u8[:]) -> i64 {
    let n = if q.len < name.len { q.len } else { name.len };
    for k in 0..n {
        var c = q[k] as i64;
        if c >= 97 && c <= 122 { c -= 32; }
        let d = name[k] as i64;
        if c < d { return -1; }
        if c > d { return 1; }
    }
    if q.len < name.len { return -1; }
    if q.len > name.len { return 1; }
    return 0;
}

// The code point whose name or alias is q, or -1 when there is none. A
// name of a code point wins over an alias of the same text. A query above
// MAX_NAME bytes gives -1.
fn lookup(q: const u8[:]) -> i64 {
    if q.len == 0 || q.len > MAX_NAME { return -1; }
    var lo: i64 = 0;
    var hi: i64 = NAME_ORDER.len;
    while lo < hi {
        let mid = (lo + hi) / 2;
        let i = NAME_ORDER[mid];
        let c = name_compare(q, NAME_NAMES[NAME_OFF[i]..NAME_OFF[i + 1]]);
        if c == 0 { return NAME_START[i]; }
        if c < 0 { hi = mid; } else { lo = mid + 1; }
    }
    lo = 0;
    hi = ALIAS_CP.len;
    while lo < hi {
        let mid = (lo + hi) / 2;
        let c = name_compare(q, ALIAS_NAMES[ALIAS_OFF[mid]..ALIAS_OFF[mid + 1]]);
        if c == 0 { return ALIAS_CP[mid]; }
        if c < 0 { hi = mid; } else { lo = mid + 1; }
    }
    return -1;
}

// The same lookup as lookup, with a fault code. A query above MAX_NAME
// bytes gives ERR_TOO_LONG. A query that is not UTF-8 gives ERR_BAD_UTF8.
// A name that no code point holds gives OK and -1.
fn lookup_checked(q: const u8[:]) -> i64, i64 {
    if q.len > MAX_NAME { return ERR_TOO_LONG, -1; }
    if !utf8_valid(q) { return ERR_BAD_UTF8, -1; }
    return OK, lookup(q);
}
