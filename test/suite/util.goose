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
