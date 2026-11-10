// The oracle for the UTF-16 tables. It reads one line per case from the
// input. A line holds the code points of the text in hex, separated by
// spaces, then a bar, then the byte order: "le" or "be". The output
// holds the UTF-16 bytes of the text in hex, one pair per line, and a
// bar with the fault of the Go library. The Go library writes U+FFFD for
// a lone surrogate; the Rust library refuses it. The output holds the
// code point of the Rust library, or the word "bad".
//
// The second mode reads UTF-16 bytes and gives the code points of the
// Rust library. A line holds the bytes in hex, then a bar, then the
// byte order. The output holds the code points in hex, or the word
// "bad" when the Rust library refuses the bytes.
use std::io::{self, Read};

fn units_of(cps: &[u32]) -> Vec<u16> {
    // A code point that no char holds is a surrogate. The text holds a
    // surrogate pair as two units, so the units are built here.
    let mut units = Vec::new();
    for &c in cps {
        if (0xD800..=0xDFFF).contains(&c) {
            units.push(c as u16);
        } else if c > 0xFFFF {
            let v = c - 0x10000;
            units.push((0xD800 + (v >> 10)) as u16);
            units.push((0xDC00 + (v & 0x3FF)) as u16);
        } else {
            units.push(c as u16);
        }
    }
    units
}

fn bytes_of(units: &[u16], big: bool) -> Vec<u8> {
    let mut out = Vec::new();
    for u in units {
        if big {
            out.push((u >> 8) as u8);
            out.push((u & 0xFF) as u8);
        } else {
            out.push((u & 0xFF) as u8);
            out.push((u >> 8) as u8);
        }
    }
    out
}

fn hexlist(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02X}", b)).collect::<Vec<_>>().join(" ")
}

fn main() {
    let mode = std::env::args().nth(1).unwrap_or_default();
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    for line in input.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let (body, order) = match line.rsplit_once('|') {
            Some((b, o)) => (b.trim(), o.trim()),
            None => (line, "le"),
        };
        let big = order == "be";
        if mode == "decode" {
            let bytes: Vec<u8> = body
                .split_whitespace()
                .map(|h| u8::from_str_radix(h, 16).unwrap())
                .collect();
            if bytes.len() % 2 != 0 {
                // The Rust library takes units, so an odd count of bytes
                // has no form. The package refuses it too.
                println!("bad");
                continue;
            }
            let mut units = Vec::new();
            let mut i = 0;
            while i + 1 < bytes.len() {
                let u = if big {
                    ((bytes[i] as u16) << 8) | bytes[i + 1] as u16
                } else {
                    ((bytes[i + 1] as u16) << 8) | bytes[i] as u16
                };
                units.push(u);
                i += 2;
            }
            match String::from_utf16(&units) {
                Ok(s) => {
                    let out: Vec<String> = s.chars().map(|c| format!("{:04X}", c as u32)).collect();
                    println!("{}", out.join(" "));
                }
                Err(_) => println!("bad"),
            }
        } else {
            let cps: Vec<u32> = body
                .split_whitespace()
                .map(|h| u32::from_str_radix(h, 16).unwrap())
                .collect();
            let units = units_of(&cps);
            let bytes = bytes_of(&units, big);
            println!("{}|{}", hexlist(&bytes), units.len());
        }
    }
}
