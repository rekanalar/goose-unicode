// The lossy UTF-8 decode of the Rust standard library. Each input line
// holds the bytes of one text in hex. The output holds the code points
// of String::from_utf8_lossy, in hex.
use std::io::{self, BufRead};

fn main() {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let bytes: Vec<u8> = line
            .split_whitespace()
            .map(|h| u8::from_str_radix(h, 16).unwrap())
            .collect();
        let text = String::from_utf8_lossy(&bytes);
        let out: Vec<String> = text.chars().map(|c| format!("{:X}", c as u32)).collect();
        println!("{}", out.join(" "));
    }
}
