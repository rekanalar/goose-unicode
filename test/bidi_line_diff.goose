// Prints the paragraphs and the line results of each input line, in the
// format of the oracles icubidi and bidilines.
// Usage: goose run test/bidi_line_diff.goose -- <input file>
// Each input line holds "dir start limit | code points in hex". The
// program must start in the package directory.
import std;
import os;
import unicode from "..";
import bidiutil from "./bidiutil";

fn add_int(buf: u8[>..]&, v: i64) {
    buf.push(32);
    format_int(buf, v, 10, 0, 32);
}

fn add_hex(buf: u8[>..]&, v: i64) {
    buf.push(32);
    format_int(buf, v, 16, 0, 32);
}

fn main() {
    let argv = args();
    if argv.len < 2 {
        print("usage: bidi_line_diff <input file>\n");
        return 1;
    }
    var text: u8[>..] = [];
    if !read_file(argv[1], text) {
        print("FAIL: cannot read the input file\n");
        return 1;
    }
    for line in split(text[..], '\n') {
        if line.len == 0 { continue; }
        var head: u8[>..] = [];
        var body: u8[>..] = [];
        var seen_bar = false;
        for k in 0..line.len {
            if line[k] == 124 { seen_bar = true; continue; }
            if seen_bar { body.push(line[k]); } else { head.push(line[k]); }
        }
        var nums: i64[>..] = [];
        for w in split(head[..], ' ') {
            let q = trim(w);
            if q.len > 0 { nums.push(bidiutil::numval(q)); }
        }
        let dir = nums[0];
        let start = nums[1];
        let limit = nums[2];
        var bytes: u8[>..] = [];
        var count = 0;
        for w in split(body[..], ' ') {
            let q = trim(w);
            if q.len == 0 { continue; }
            unicode::utf8_encode(bytes, bidiutil::hexval(q));
            count += 1;
        }
        var out: u8[>..] = [];
        var pars: i64[>..] = [];
        let pc, _ = unicode::bidi_paragraphs(pars, bytes[..], dir);
        if pc != unicode::OK {
            print("E ", pc, "\n.\n");
            continue;
        }
        out.push(80);
        add_int(out, pars.len / 3);
        for k in 0..pars.len { add_int(out, pars[k]); }
        print(out, "\n");
        if start < 0 || limit > count || start > limit {
            print("E range\n.\n");
            continue;
        }
        var res: i64[>..] = [];
        var offs: i64[>..] = [];
        unicode::bidi_resolve(res, offs, bytes[..], dir);
        var lv: i64[>..] = [];
        let c1 = unicode::bidi_line_levels_from(lv, res[..], start, limit);
        if c1 != unicode::OK {
            print("E ", c1, "\n.\n");
            continue;
        }
        var l: u8[>..] = [];
        l.push(76);
        for k in 0..lv.len { add_int(l, lv[k]); }
        print(l, "\n");
        var ord: i64[>..] = [];
        unicode::bidi_line_order_from(ord, res[..], start, limit);
        var o: u8[>..] = [];
        o.push(79);
        for k in 0..ord.len { add_int(o, ord[k]); }
        print(o, "\n");
        var flags: i64[>..] = [0, 1, 2, 3, 8, 9, 10, 11];
        for fi in 0..flags.len {
            var w: u8[>..] = [];
            let c3 = unicode::bidi_reorder_from(w, bytes[..], res[..], offs[..], start, limit, flags[fi]);
            var o3: u8[>..] = [];
            o3.push(87);
            add_int(o3, flags[fi]);
            if c3 != unicode::OK { o3.push(32); o3.push(69); }
            var at = 0;
            while at < w.len {
                let cp, n = unicode::decode_at(w[..], at);
                add_hex(o3, cp);
                at += n;
            }
            print(o3, "\n");
        }
        print(".\n");
    }
    return 0;
}
