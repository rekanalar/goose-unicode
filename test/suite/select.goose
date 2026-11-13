// The choice of single tests. Each run_ function of a suite asks want
// before it calls a test function. With no variable set, want says yes
// to every test.
//
// UNICODE_LIST holds any text: want prints the name of each test as
// group.test and runs none. UNICODE_ONLY holds a list of names, split
// by commas. A name is a test (restrict_levels), a group.test pair
// (restrict.rl_levels) or a group (restrict). want prints "run
// group.test" for each test that it lets run, so a name that matches
// no test is easy to see.
namespace suite;

import std;
import os;

fn want(group: const u8[:], name: const u8[:]) -> bool {
    var list: u8[>..] = [];
    if env("UNICODE_LIST", list) && list.len > 0 {
        print("test ", group, ".", name, "\n");
        return false;
    }
    list.clear();
    if !env("UNICODE_ONLY", list) || list.len == 0 { return true; }
    for item in split(list[..], ',') {
        let w = trim(item);
        if w.len == 0 { continue; }
        var hit = false;
        if w == name || w == group { hit = true; }
        let n = group.len + 1 + name.len;
        if w.len == n && w[0..group.len] == group && w[group.len] == 46
            && w[group.len + 1..w.len] == name {
            hit = true;
        }
        if hit {
            print("run ", group, ".", name, "\n");
            return true;
        }
    }
    return false;
}
