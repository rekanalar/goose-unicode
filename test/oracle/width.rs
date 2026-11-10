// Oracle for the width tables of the package. It reads one text per line,
// as hex code points separated by spaces, and prints one number per line.
//
// Modes:
//   str   print the width of the whole text, in columns (default)
//   cchar, cstr  the same two, in the East Asian context form
//   char  print the width of each code point of the line, in columns,
//         -1 where the library refuses the code point
//
// The answers come from the Rust unicode-width crate 0.2.x.

use std::io::{self, BufRead, Write};
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_default();
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let cps: Vec<u32> = line
            .split_whitespace()
            .map(|h| u32::from_str_radix(h, 16).unwrap())
            .collect();
        if mode == "cchar" {
            let mut parts = Vec::with_capacity(cps.len());
            for cp in &cps {
                let w = match char::from_u32(*cp) {
                    Some(c) => UnicodeWidthChar::width_cjk(c)
                        .map(|w| w as i64)
                        .unwrap_or(-1),
                    None => -1,
                };
                parts.push(w.to_string());
            }
            writeln!(out, "{}", parts.join(" ")).unwrap();
        } else if mode == "cstr" {
            let s: String = cps.iter().filter_map(|c| char::from_u32(*c)).collect();
            writeln!(out, "{}", UnicodeWidthStr::width_cjk(s.as_str())).unwrap();
        } else if mode == "char" {
            let mut parts = Vec::with_capacity(cps.len());
            for cp in &cps {
                let w = match char::from_u32(*cp) {
                    Some(c) => UnicodeWidthChar::width(c)
                        .map(|w| w as i64)
                        .unwrap_or(-1),
                    None => -1,
                };
                parts.push(w.to_string());
            }
            writeln!(out, "{}", parts.join(" ")).unwrap();
        } else {
            // A lone surrogate cannot sit in a Rust text; it never reaches
            // this oracle, so we drop it here.
            let s: String = cps.iter().filter_map(|c| char::from_u32(*c)).collect();
            writeln!(out, "{}", UnicodeWidthStr::width(s.as_str())).unwrap();
        }
    }
}
