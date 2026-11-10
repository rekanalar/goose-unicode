// The helpers of the bidi tools under test/.
namespace bidiutil;

import std;

// The value of a hexadecimal number.
fn hexval(s: const u8[:]) -> i64 {
    var v = 0;
    for k in 0..s.len {
        let c = s[k];
        var d = 0;
        if c >= 48 && c <= 57 { d = c - 48; }
        else if c >= 65 && c <= 70 { d = c - 55; }
        else if c >= 97 && c <= 102 { d = c - 87; }
        v = v * 16 + d;
    }
    return v;
}

// The value of a decimal number.
fn numval(s: const u8[:]) -> i64 {
    var v = 0;
    for k in 0..s.len { v = v * 10 + (s[k] - 48); }
    return v;
}

// The path of a file in a directory. The separator is a solidus.
fn path_of(dir: const u8[:], name: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for k in 0..dir.len { out.push(dir[k]); }
    if out.len > 0 && out[out.len - 1] != 47 { out.push(47); }
    for k in 0..name.len { out.push(name[k]); }
    return out;
}
