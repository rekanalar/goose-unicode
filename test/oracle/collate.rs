// The sign of the root collator of the icu_collator crate for each
// input pair. Each line holds two texts in hex code points, separated
// by a bar. The output holds -1, 0 or 1. The und locale is the root
// locale.
use icu_collator::Collator;
use icu_locale::locale;
use std::io::{self, BufRead};

fn text(hex: &str) -> String {
    let mut s = String::new();
    for f in hex.split_whitespace() {
        let cp = u32::from_str_radix(f, 16).unwrap();
        s.push(char::from_u32(cp).unwrap());
    }
    s
}

fn main() {
    let c = Collator::try_new(locale!("und").into(), Default::default()).unwrap();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let (a, b) = line.split_once('|').unwrap();
        let r = c.compare(&text(a), &text(b));
        println!("{}", r as i8);
    }
}
