// The trie walk of the dictionary word segmentation. A trie holds the word
// list of one script. The walk reads the code points of one run and finds
// every word that starts at one index. The candidate lengths come in
// increasing order, as in the dictionary matcher of the ICU library.
namespace unicode;

import std;

// The tries, one for each word list.
const DICT_THAI: i64 = 0;
const DICT_LAO: i64 = 1;
const DICT_BURMESE: i64 = 2;
const DICT_KHMER: i64 = 3;
const DICT_CJ: i64 = 4;

// The most candidate words that one position keeps. The last slot of the
// struct stays free for the single code point fallback of the CJ walk.
const DICT_MAX_CAND: i64 = 20;

// The words that start at one index of a run.
struct DictMatch {
    count: i64,       // the number of words found
    prefix: i64,      // the code points read, the one that failed included
    len: i64[21],     // the length of each word in code points
    cost: i64[21],    // the cost of each word, for the list that has costs
}

// The nodes of the tries, decoded from the byte strings of the data
// files at the first use. The compiler reads a string of bytes far
// faster than it reads a list of numbers, so the data files hold bytes.
var DICT_THAI_DATA: i64[>..] = [];
var DICT_LAO_DATA: i64[>..] = [];
var DICT_BURMESE_DATA: i64[>..] = [];
var DICT_KHMER_DATA: i64[>..] = [];
var DICT_CJ_DATA: i64[>..] = [];
var DICT_COST_DATA: i64[>..] = [];
var DICT_READY: bool = false;

// Reads the bytes of the data files into the arrays of the nodes. The
// call reads each byte once and takes the time of the size of the data.
fn dict_load() {
    if DICT_READY { return; }
    DICT_READY = true;
    dict_decode(DICT_THAIDICT_NODE, DICT_THAI_DATA);
    dict_decode(DICT_LAODICT_NODE, DICT_LAO_DATA);
    dict_decode(DICT_BURMESEDICT_NODE, DICT_BURMESE_DATA);
    dict_decode(DICT_KHMERDICT_NODE, DICT_KHMER_DATA);
    dict_decode(DICT_CJDICT_NODE, DICT_CJ_DATA);
    for k in 0..DICT_CJ_COST.len {
        DICT_COST_DATA.push(DICT_CJ_COST[k]);
    }
}

// Reads the bytes into the numbers of the nodes. Eight bytes make one
// node, low byte first.
fn dict_decode(data: const u8[:], out: i64[>..]&) {
    var i: i64 = 0;
    while i + 8 <= data.len {
        var v: i64 = 0;
        var k: i64 = 0;
        while k < 8 {
            v |= (data[i + k] as i64) << (k * 8);
            k += 1;
        }
        out.push(v);
        i += 8;
    }
}

fn dict_node(t: i64, i: i64) -> i64 {
    dict_load();
    if t == DICT_THAI { return DICT_THAI_DATA[i]; }
    if t == DICT_LAO { return DICT_LAO_DATA[i]; }
    if t == DICT_BURMESE { return DICT_BURMESE_DATA[i]; }
    if t == DICT_KHMER { return DICT_KHMER_DATA[i]; }
    return DICT_CJ_DATA[i];
}

// The table of the nodes of one word list.
fn dict_table(t: i64) -> const i64[:] {
    dict_load();
    if t == DICT_THAI { return DICT_THAI_DATA[..]; }
    if t == DICT_LAO { return DICT_LAO_DATA[..]; }
    if t == DICT_BURMESE { return DICT_BURMESE_DATA[..]; }
    if t == DICT_KHMER { return DICT_KHMER_DATA[..]; }
    return DICT_CJ_DATA[..];
}

// The child of a node for one code point, in a table of nodes. -1 when
// the node has none. The layout of a node is the layout of every trie
// of the package.
fn trie_child(data: const i64[:], node: i64, cp: i64) -> i64 {
    let v = data[node];
    var lo = (v >> 15) & 0x1FFFFF;
    var hi = lo + ((v >> 1) & 0x3FFF);
    while lo < hi {
        let mid = (lo + hi) / 2;
        let c = (data[mid] >> 36) & 0x1FFFFF;
        if c == cp { return mid; }
        if c < cp { lo = mid + 1; } else { hi = mid; }
    }
    return -1;
}

// The child of a node for one code point. -1 when the node has none.
fn dict_child(t: i64, node: i64, cp: i64) -> i64 {
    return trie_child(dict_table(t), node, cp);
}

// Finds the words of trie t that start at index at of the code points c.
// The walk stops before index limit, and after max_units UTF-16 units when
// max_units is above zero. The result holds at most DICT_MAX_CAND words.
fn dict_matches(t: i64, c: const i64[:], at: i64, limit: i64, max_units: i64, m: DictMatch&) {
    m.count = 0;
    var node: i64 = 0;
    var i = at;
    var units: i64 = 0;
    while i < limit {
        let cp = c[i];
        i += 1;
        if cp >= 0x10000 { units += 2; } else { units += 1; }
        let next = dict_child(t, node, cp);
        if next < 0 { break; }
        node = next;
        let v = dict_node(t, node);
        if (v & 1) == 1 && m.count < DICT_MAX_CAND {
            m.len[m.count] = i - at;
            if t == DICT_CJ { m.cost[m.count] = DICT_COST_DATA[node]; }
            m.count += 1;
        }
        if ((v >> 1) & 0x3FFF) == 0 { break; }
        if max_units > 0 && units >= max_units { break; }
    }
    m.prefix = i - at;
}
