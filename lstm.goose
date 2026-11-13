// The LSTM model engine for the word and the line calls.
//
// The engine follows the model engine of the ICU library, release 79.1.
// It splits a run of Thai or Burmese code points with a small neural
// model. The two default models of ICU hold the data in the file
// lstm_data.goose.
//
// The engine reads each code point of a run a fixed number of times, so
// the time of a call is linear in the run. The model calls refuse a
// text above MAX_MODEL_INPUT bytes, because the model costs about 53
// microseconds for each Thai code point.
//
// All math is single precision, as in ICU. The exponential and the
// hyperbolic tangent of the standard library work in double precision.
// The result is rounded to single precision, so the answer of a call is
// the same on every platform.
namespace unicode;

import std;

// The longest cluster of a run, in UTF-16 units. The vectorizer of ICU
// holds 10 units. A longer cluster makes the run give no break.
const LSTM_MAX_CLUSTER: i64 = 10;

// The shortest run that can hold two words, in code points. The engine of
// ICU needs 5 code points, because it steps 4 code points ahead.
const LSTM_MIN_SPAN: i64 = 5;

// The embedding size, the count of hidden units and the count of strings
// of each model.
var LSTM_EMB: i64[2] = [0, 0];
var LSTM_HUNITS: i64[2] = [0, 0];
var LSTM_COUNT: i64[2] = [0, 0];

// The float values of the two models, one after the other. The values
// of a model sit in the order of ICU: the embedding table, then the
// matrices of the forward pass, then the matrices of the backward pass,
// then the output matrix and the output bias.
var LSTM_VALS: f32[>..] = [];
// The strings of the two models. Each string holds its length first,
// then its UTF-16 units.
var LSTM_STRINGS: i64[>..] = [];
// The first value of each model and the first string of each model.
var LSTM_VSTART: i64[2] = [0, 0];
var LSTM_SSTART: i64[2] = [0, 0];
// The lookup table from a string to its index in the list of its model.
var LSTM_HASH_KEY: i64[>..] = [];
var LSTM_HASH_IDX: i64[>..] = [];
// The place of each string of the list in LSTM_STRINGS.
var LSTM_HASH_OFF: i64[>..] = [];
var LSTM_HASH_MASK: i64 = 0;
var LSTM_READY: bool = false;

// The exponential of x, in double precision. The argument goes into the
// range of the series and the series gives the small part. A power of
// two gives the rest.
//
// The function uses only the operations of IEEE 754, so the answer is
// the same on every platform. The product of a multiply and an add
// sits in a variable of its own, so the compiler cannot fuse the two
// into one rounding.
fn lstm_exp64(x: f64) -> f64 {
    if x > 709.0 { return 1.0e308; }
    if x < -745.0 { return 0.0; }
    // The natural logarithm of two.
    let ln2: f64 = 0.6931471805599453;
    let k = (x / ln2) as i64;
    let r = x - k * ln2;
    // The series of the exponential up to the ninth term, by the Horner
    // form.
    var p: f64 = 0.0001984126984126984;
    p = 0.001388888888888889 + r * p;
    p = 0.008333333333333333 + r * p;
    p = 0.041666666666666664 + r * p;
    p = 0.16666666666666666 + r * p;
    p = 0.5 + r * p;
    p = 1.0 + r * p;
    p = 1.0 + r * p;
    // The scale of the multiple, by a power of two.
    var s: f64 = 1.0;
    var n = k;
    if n > 0 {
        while n > 0 { s = s * 2.0; n -= 1; }
    } else {
        while n < 0 { s = s * 0.5; n += 1; }
    }
    return p * s;
}

// The hyperbolic tangent of x, in single precision. The series of the
// tangent serves the small values, where the ratio of two exponentials
// loses its digits. The ratio serves the other values.
fn lstm_tanh(x: f32) -> f32 {
    if x > 20.0 { return 1.0; }
    if x < -20.0 { return -1.0; }
    let a = (x as f64);
    if a > -0.5 && a < 0.5 {
        let a2 = a * a;
        let p: f64 = a * (1.0 + a2 * (-1.0 / 3.0 + a2 * (2.0 / 15.0
            + a2 * (-17.0 / 315.0 + a2 * (62.0 / 2835.0)))));
        return (p as f32);
    }
    let e = lstm_exp64(2.0 * a);
    return (((e - 1.0) / (e + 1.0)) as f32);
}

// The sigmoid of x, in single precision.
fn lstm_sigmoid(x: f32) -> f32 {
    if x >= 0.0 {
        let e = lstm_exp64(-(x as f64));
        return ((1.0 / (1.0 + e)) as f32);
    }
    let e = lstm_exp64(x);
    return ((e / (1.0 + e)) as f32);
}

// The hash of a string of the list. The value is the mix of the units.
fn lstm_hash(units: const i64[:]) -> i64 {
    var h: u64 = 14695981039346656037;
    for k in 0..units.len {
        h = (h ^ (units[k] as u64)) * 1099511628211;
    }
    return (h as i64) & 0x7FFFFFFF;
}

// The fault of an engine and a text length. The call gives OK when the
// engine is known and the text is short enough. The engine is checked
// first.
fn engine_fault(engine: i64, n: i64) -> i64 {
    if engine != SEG_DICTIONARY && engine != SEG_MODEL { return ERR_BAD_ARG; }
    if engine == SEG_MODEL && n > MAX_MODEL_INPUT { return ERR_TOO_LONG; }
    return OK;
}

// The model of a trie. The value is the index of the model. The value -1
// means that the trie has no model.
fn lstm_model_of(trie: i64) -> i64 {
    if trie == DICT_THAI { return 0; }
    if trie == DICT_BURMESE { return 1; }
    return -1;
}

// The single precision value of a 32-bit pattern. The standard library of
// the older Goose release has no such call, so the value comes from the
// parts of the pattern: the sign, the exponent and the mantissa. The
// result is exact, because a double holds every single precision value.
fn lstm_f32(bits: i64) -> f32 {
    let e = (bits >> 23) & 255;
    let m = bits & 0x7FFFFF;
    var v: f64 = 0.0;
    var k: i64 = 0;
    if e == 0 {
        v = m;
        k = -149;
    } else {
        v = m + 0x800000;
        k = e - 150;
    }
    while k > 0 { v = v * 2.0; k -= 1; }
    while k < 0 { v = v * 0.5; k += 1; }
    if (bits >> 31) != 0 { v = -v; }
    return (v as f32);
}

// The 32-bit value at the place at of the bytes. The bytes are in the
// little-endian order.
fn lstm_le32(data: const u8[:], at: i64) -> i64 {
    var v: i64 = 0;
    for j in 0..4 { v |= (data[at + j] as i64) << (j * 8); }
    return v;
}

// Reads the bytes of one model into the arrays of the package. The call
// checks the header of the model against the length of the bytes. It
// gives false when the bytes hold no model.
fn lstm_decode(data: const u8[:], m: i64) -> bool {
    if data.len < 12 { return false; }
    var at: i64 = 0;
    var head: i64[3] = [0, 0, 0];
    for k in 0..3 {
        head[k] = lstm_le32(data, at);
        at += 4;
    }
    let emb = head[0];
    let hunits = head[1];
    let count = head[2];
    if emb <= 0 || hunits <= 0 || count <= 0 { return false; }
    if emb > 1024 || hunits > 1024 || count > 65536 { return false; }
    let sstart = LSTM_STRINGS.len;
    for k in 0..count {
        if at + 4 > data.len { return false; }
        let len = lstm_le32(data, at);
        at += 4;
        if len < 0 || len > 64 { return false; }
        if at + len * 2 > data.len { return false; }
        LSTM_STRINGS.push(len);
        for j in 0..len {
            var unit: i64 = 0;
            unit |= data[at];
            unit |= (data[at + 1] as i64) << 8;
            LSTM_STRINGS.push(unit);
            at += 2;
        }
    }
    let vstart = LSTM_VALS.len;
    let want = ((count + 1) * emb + 2 * (emb * 4 * hunits + hunits * 4 * hunits
        + 4 * hunits) + 2 * hunits * 4 + 4);
    if data.len - at != want * 4 { return false; }
    while at < data.len {
        LSTM_VALS.push(lstm_f32(lstm_le32(data, at)));
        at += 4;
    }
    LSTM_EMB[m] = emb;
    LSTM_HUNITS[m] = hunits;
    LSTM_COUNT[m] = count;
    LSTM_VSTART[m] = vstart;
    LSTM_SSTART[m] = sstart;
    return true;
}

// Reads the two models at the first use. The call reads each byte once.
fn lstm_load() {
    if LSTM_READY { return; }
    LSTM_READY = true;
    if !lstm_decode(LSTM_THAI, 0) { return; }
    if !lstm_decode(LSTM_BURMESE, 1) { return; }
    lstm_hash_build();
}

// The lookup table from a string to its index. The table holds the hash
// value of a string and the index of that string. The index holds the
// model in the high bits and the place in the list in the low bits. The
// size of the table is a power of two.
fn lstm_hash_build() {
    let n = LSTM_COUNT[0] + LSTM_COUNT[1];
    var size: i64 = 16;
    while size < n * 4 { size *= 2; }
    LSTM_HASH_MASK = size - 1;
    LSTM_HASH_KEY.clear();
    LSTM_HASH_IDX.clear();
    LSTM_HASH_OFF.clear();
    for k in 0..size {
        LSTM_HASH_KEY.push(-1);
        LSTM_HASH_IDX.push(-1);
        LSTM_HASH_OFF.push(-1);
    }
    for m in 0..2 {
        let start = LSTM_SSTART[m];
        var at = start;
        for k in 0..LSTM_COUNT[m] {
            let len = LSTM_STRINGS[at];
            var units: i64[>..] = [];
            for j in 0..len { units.push(LSTM_STRINGS[at + 1 + j]); }
            let h = lstm_hash(units[..]);
            var slot = h & LSTM_HASH_MASK;
            while LSTM_HASH_KEY[slot] >= 0 {
                slot = (slot + 1) & LSTM_HASH_MASK;
            }
            LSTM_HASH_KEY[slot] = h;
            LSTM_HASH_IDX[slot] = m * 65536 + k;
            LSTM_HASH_OFF[slot] = at;
            at += 1 + len;
        }
    }
}

// The index of a string in the list of the model m. The index is the
// count of the strings when the list holds no such string. That index
// is the last row of the embedding table.
fn lstm_string_index(m: i64, units: const i64[:]) -> i64 {
    if LSTM_HASH_MASK == 0 { return LSTM_COUNT[m]; }
    let h = lstm_hash(units);
    var slot = h & LSTM_HASH_MASK;
    while LSTM_HASH_KEY[slot] >= 0 {
        if LSTM_HASH_KEY[slot] == h {
            let idx = LSTM_HASH_IDX[slot];
            let model = idx / 65536;
            let k = idx % 65536;
            if model != m {
                slot = (slot + 1) & LSTM_HASH_MASK;
                continue;
            }
            let p = LSTM_HASH_OFF[slot];
            let len = LSTM_STRINGS[p];
            if len != units.len { return LSTM_COUNT[m]; }
            for j in 0..len {
                if LSTM_STRINGS[p + 1 + j] != units[j] { return LSTM_COUNT[m]; }
            }
            return k;
        }
        slot = (slot + 1) & LSTM_HASH_MASK;
    }
    return LSTM_COUNT[m];
}

// The row of the embedding table of the model m for the index of a
// cluster. The row holds emb values.
fn lstm_embedding(m: i64, index: i64, out: f32[>..]&) {
    let emb = LSTM_EMB[m];
    let at = LSTM_VSTART[m] + index * emb;
    for k in 0..emb { out.push(LSTM_VALS[at + k]); }
}


// One step of the LSTM. The matrices W and U and the bias b are the
// places of the model m. The row x is the embedding of the cluster. The
// row h is the hidden row before the step. The row c is the cell state
// before the step. The row ifco holds 4 * hunits values.
//
// The order of the operations follows ICU: the bias comes first, then
// the product with the embedding, then the product with the hidden row.
fn lstm_cell(m: i64, w: i64, u: i64, b: i64, x: const f32[:], h: f32[>..]&,
             c: f32[>..]&, ifco: f32[>..]&) {
    let hunits = LSTM_HUNITS[m];
    let four = 4 * hunits;
    // The place of the model in the array of the values. The index of
    // every value of the model is this place plus its own index.
    let base = LSTM_VSTART[m];
    for i in 0..four { ifco[i] = LSTM_VALS[base + b + i]; }
    for i in 0..four {
        var sum = ifco[i];
        for j in 0..x.len {
            sum = sum + x[j] * LSTM_VALS[base + w + j * four + i];
        }
        ifco[i] = sum;
    }
    for i in 0..four {
        var sum = ifco[i];
        for j in 0..hunits {
            sum = sum + h[j] * LSTM_VALS[base + u + j * four + i];
        }
        ifco[i] = sum;
    }
    for i in 0..hunits {
        ifco[i] = lstm_sigmoid(ifco[i]);
        ifco[hunits + i] = lstm_sigmoid(ifco[hunits + i]);
        ifco[2 * hunits + i] = lstm_tanh(ifco[2 * hunits + i]);
        ifco[3 * hunits + i] = lstm_sigmoid(ifco[3 * hunits + i]);
    }
    for i in 0..hunits {
        let nc = c[i] * ifco[hunits + i] + ifco[i] * ifco[2 * hunits + i];
        c[i] = nc;
    }
    for i in 0..hunits {
        let t = lstm_tanh(c[i]);
        h[i] = t * ifco[3 * hunits + i];
    }
}

// The break offsets of a run of Thai or Burmese code points. The run
// holds the code points c, their byte offsets off and the offset of the
// end of the run. The call pushes the byte offset of each break.
//
// The call follows the model engine of ICU. It cuts the run into
// grapheme clusters, looks each cluster up in the string list of the
// model, runs the backward pass and then the forward pass with the
// output layer, and takes the class of each cluster from the first
// largest of four values. A break goes before a cluster of the class
// BEGIN or SINGLE, except the first cluster.
//
// The call adds no break when the run holds fewer than 4 code points,
// or when a cluster holds more than 10 UTF-16 units.
fn lstm_breaks(t: i64, c: const i64[:], off: const i64[:], breaks: i64[>..]&) {
    let m = lstm_model_of(t);
    if m < 0 { return; }
    let n = c.len;
    if n < LSTM_MIN_SPAN { return; }
    lstm_load();
    if LSTM_EMB[m] == 0 { return; }
    let hunits = LSTM_HUNITS[m];
    // The clusters of the run. Each cluster holds the index of its first
    // code point, its count of code points and its index in the list.
    var starts: i64[>..] = [];
    var indexs: i64[>..] = [];
    var at: i64 = 0;
    while at < n {
        let end = lstm_cluster_end(c, at);
        var units: i64[>..] = [];
        for k in at..end {
            let cp = c[k];
            if cp > 0xFFFF {
                units.push(0xD800 + ((cp - 0x10000) >> 10));
                units.push(0xDC00 + ((cp - 0x10000) & 0x3FF));
            } else {
                units.push(cp);
            }
        }
        if units.len > LSTM_MAX_CLUSTER { return; }
        starts.push(at);
        indexs.push(lstm_string_index(m, units[..]));
        at = end;
    }
    let nc = starts.len;
    // The rows of the hidden state of the backward pass.
    var hback: f32[>..] = [];
    for k in 0..nc * hunits { hback.push(0.0); }
    // The places of the matrices of the model. The embedding table comes
    // first. Then the forward pass. Then the backward pass. Then the
    // output layer.
    let emb = LSTM_EMB[m];
    let base = LSTM_VSTART[m];
    let emb_rows = LSTM_COUNT[m] + 1;
    let fw = emb_rows * emb;
    let fu = fw + emb * 4 * hunits;
    let fb = fu + hunits * 4 * hunits;
    let bw = fb + 4 * hunits;
    let bu = bw + emb * 4 * hunits;
    let bb = bu + hunits * 4 * hunits;
    let ow = bb + 4 * hunits;
    let ob = ow + 2 * hunits * 4;
    // The backward pass.
    var cstate: f32[>..] = [];
    var hrow: f32[>..] = [];
    var ifco: f32[>..] = [];
    var x: f32[>..] = [];
    for k in 0..hunits { cstate.push(0.0); }
    for k in 0..hunits { hrow.push(0.0); }
    for k in 0..4 * hunits { ifco.push(0.0); }
    var i: i64 = nc - 1;
    while i >= 0 {
        if i != nc - 1 {
            for k in 0..hunits { hrow[k] = hback[(i + 1) * hunits + k]; }
        }
        x.clear();
        lstm_embedding(m, indexs[i], x);
        lstm_cell(m, bw, bu, bb, x[..], hrow, cstate, ifco);
        for k in 0..hunits { hback[i * hunits + k] = hrow[k]; }
        i -= 1;
    }
    // The forward pass with the output layer.
    for k in 0..hunits { cstate[k] = 0.0; }
    var fwd: f32[>..] = [];
    for k in 0..hunits { fwd.push(0.0); }
    var logp: f32[>..] = [];
    for k in 0..4 { logp.push(0.0); }
    for i in 0..nc {
        x.clear();
        lstm_embedding(m, indexs[i], x);
        lstm_cell(m, fw, fu, fb, x[..], fwd, cstate, ifco);
        for k in 0..4 { logp[k] = LSTM_VALS[base + ob + k]; }
        for i2 in 0..4 {
            var sum = logp[i2];
            for j in 0..hunits {
                sum = sum + fwd[j] * LSTM_VALS[base + ow + j * 4 + i2];
            }
            for j in 0..hunits {
                sum = sum + hback[i * hunits + j] * LSTM_VALS[base + ow + (hunits + j) * 4 + i2];
            }
            logp[i2] = sum;
        }
        // The class of the cluster: the first largest of the four values.
        let best = lstm_class(logp[..]);
        if (best == 0 || best == 3) && i != 0 {
            breaks.push(off[starts[i]]);
        }
    }
}

// The class of a cluster: the index of the first largest of the four
// values. The classes are BEGIN 0, INSIDE 1, END 2 and SINGLE 3.
fn lstm_class(v: const f32[:]) -> i64 {
    var best: i64 = 0;
    for k in 1..4 { if v[k] > v[best] { best = k; } }
    return best;
}

// The end of the grapheme cluster that starts at the code point at of
// the run c. The run holds no code point above the BMP, so a cluster
// holds at most one unit for each code point.
fn lstm_cluster_end(c: const i64[:], at: i64) -> i64 {
    var st = Cluster { prev: 0, ri: 0, ep: 0, incb: 0 };
    let p0 = grapheme_props(c[at]);
    cluster_take(st, p0);
    var i = at + 1;
    while i < c.len {
        let p = grapheme_props(c[i]);
        if !cluster_joins(st, p) { break; }
        cluster_take(st, p);
        i += 1;
    }
    return i;
}

