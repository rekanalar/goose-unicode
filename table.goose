// Lookups in the sorted tables of the package.
namespace unicode;

import std;

// The index of the last entry that is at or below v. -1 when every
// entry is above v. The array must be sorted.
fn last_at_or_below(a: const i64[:], v: i64) -> i64 {
    var lo: i64 = 0;
    var hi: i64 = a.len;
    while lo < hi {
        let mid = (lo + hi) / 2;
        if a[mid] <= v { lo = mid + 1; } else { hi = mid; }
    }
    return lo - 1;
}

// The index of v in a sorted array. -1 when v is not there.
fn find_exact(a: const i64[:], v: i64) -> i64 {
    let i = last_at_or_below(a, v);
    if i >= 0 && a[i] == v { return i; }
    return -1;
}
