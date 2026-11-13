// Helpers of the test suites.
namespace suite;

import std;

// The next number of a seeded generator. The state wraps on purpose.
fn rnd(st: u64&) -> i64 {
    st = st * 6364136223846793005 + 1442695040888963407;
    return (st >> 33) as i64;
}

// The value at index i of a pool. Each value takes three bytes, low
// byte first.
fn pool_val(pool: const u8[:], i: i64) -> i64 {
    let a = pool[3 * i] as i64;
    let b = pool[3 * i + 1] as i64;
    let c = pool[3 * i + 2] as i64;
    return a | (b << 8) | (c << 16);
}

// Copy the values from index a up to index b of a pool into dst.
fn pool_load(dst: i64[>..]&, pool: const u8[:], a: i64, b: i64) {
    dst.clear();
    for i in a..b { dst.push(pool_val(pool, i)); }
}

// The smaller of two values.
fn min_of(a: i64, b: i64) -> i64 {
    if a < b { return a; }
    return b;
}

// The byte order of two keys: -1, 0 or 1. A shorter key that is a
// prefix of the other orders first.
fn key_sign(a: const i64[:], b: const i64[:]) -> i64 {
    let n = min_of(a.len, b.len);
    for k in 0..n {
        if a[k] != b[k] {
            if a[k] < b[k] { return -1; }
            return 1;
        }
    }
    if a.len < b.len { return -1; }
    if a.len > b.len { return 1; }
    return 0;
}

// The result of a check: 0 when the check holds, else 1. The message
// names the subject and the case.
fn check(subject: const u8[:], name: const u8[:], ok: bool) -> i64 {
    if !ok { print("FAIL: ", subject, " ", name, "\n"); return 1; }
    return 0;
}
