// Helpers of the test suites.
namespace suite;

import std;

// The next number of a seeded generator. The state wraps on purpose.
fn rnd(st: u64&) -> i64 {
    st = st * 6364136223846793005 + 1442695040888963407;
    return (st >> 33) as i64;
}
